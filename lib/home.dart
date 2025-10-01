import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:holtersync/Services/HolterReportGenerator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:holtersync/Pages/RecordingsListPage.dart';
import 'package:holtersync/ProtocolManifests/ProtocolManifest.dart';
import 'package:holtersync/ProviderModals/ImportFileProvider.dart';
// import 'package:holtersync/Services/MachineControllers/LodeErgometerController.dart';
import 'package:holtersync/Services/TreadmillSerialController.dart';
// import 'package:holtersync/Services/Utility.dart';
// import 'package:holtersync/Widgets/BreathStatsTableModal.dart';
import 'package:holtersync/Widgets/MyBigGraphScrollable.dart';
// import 'package:holtersync/Widgets/current_co2_display.dart';
// import 'package:holtersync/Widgets/current_o2_display.dart';
import 'package:holtersync/data/local/database.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libserialport/libserialport.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:holtersync/Pages/ChartGenerator.dart';
import 'package:holtersync/Pages/GlobalSettings.dart';
import 'package:holtersync/Pages/patient/list.dart';
import 'package:holtersync/Pages/patient/patientAdd.dart';
import 'package:holtersync/ProviderModals/DefaultPatientModal.dart';
import 'package:holtersync/ProviderModals/GlobalSettingsModal.dart';
// import 'package:holtersync/Services/CPETService.dart';
import 'package:holtersync/Services/CalibrationFunction.dart';
import 'package:holtersync/Services/DataSaver.dart';
import 'package:holtersync/Services/EcgBPMCalculator.dart';
// import 'package:holtersync/Widgets/CustomLineChart.dart';
// import 'package:holtersync/Widgets/MyBigGraph.dart';
// import 'package:holtersync/Widgets/VitalsBox.dart';
// import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
// duplicate removed
import 'package:path/path.dart' as p;
import 'package:holtersync/ReportPreviewPage.dart'; // <-- Import your preview page
import 'package:holtersync/SavedChartsDialogContent.dart';
import 'package:holtersync/Widgets/IconButtonColumn.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<MyBigGraphV2State> myBigGraphKey =
      GlobalKey<MyBigGraphV2State>();
  final ValueNotifier<List<Map<String, dynamic>>> breathStatsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  Map<String, dynamic>? fullCp;

  double time = 0.0; // 🧠 To move the sine wave over time
  late Timer timer;
  double votwo = 0;
  double votwokg = 0;
  double vco = 0;
  double? rer = 0;
  double? vol = 0;
  double? flow = 0;
  double? bpm = 0;
  double? respirationRate = 0;

  List<double> rawDataFull = [];
  SharedPreferences? prefs;

  bool isPlaying = false;
  DataSaver dataSaver = DataSaver();

  List<List<double>> _inMemoryData = [];

  EcgBPMCalculator ecgBPMCalculator = EcgBPMCalculator();

  Queue<double> o2Buffer = Queue<double>();
  Queue<double> co2Buffer = Queue<double>();
  int? delaySamples = 174; // Initially null
  List<List<double>> delayBuffer = []; // holds [ecg, o2, co2, vol, flow]
  void Function(void Function())? modalSetState;
  late GlobalSettingsModal globalSettings;

  bool isImported = false;

  var o2Calibrate;
  late SerialPort port;

  // Recorder
  int sampleCounter = 0;
  int? recordStartIndex;
  int? recordEndIndex;
  bool isRecording = false;

  Map<String, dynamic>? cp;
  Map<String, dynamic>? completeCp;
  late List<Map<String, dynamic>> plotConfig; // <-- Move plot config here

  StreamSubscription<Uint8List>? mainDataSubscription;

  double co2 = 0;
  late ValueNotifier<double> co2Notifier = ValueNotifier<double>(0.0);
  late ValueNotifier<double> o2Notifier = ValueNotifier<double>(0.0);
  late ValueNotifier<double> tidalVolumeNotifier = ValueNotifier<double>(0.0);

  DateTime? recordingStartTime;
  Duration recordingDuration = Duration.zero;
  Timer? recordingTimer;

  List<Map<String, dynamic>> markers =
      []; // [{name: "Phase", length: 123}, ...]

  late ValueNotifier<List<int>> breathPeakIndicesNotifier =
      ValueNotifier<List<int>>([]);

  late ValueNotifier<List<int>> breathPeakIndicesNotifierEmpty =
      ValueNotifier<List<int>>([]);
  TreadmillSerialController? treadmillController;

  @override
  void initState() {
    super.initState();
    co2Notifier = ValueNotifier<double>(0.0);
    o2Notifier = ValueNotifier<double>(0.0);
    tidalVolumeNotifier = ValueNotifier<double>(0.0);
    breathPeakIndicesNotifier = ValueNotifier<List<int>>([]);

    initFunc();

    // Initialize plotConfig in state

    plotConfig = [
      {
        "name": "ECG",
        "boxValue": 4096 / 12,
        "unit": "mV",
        "minDisplay": (-4096 / 12) * 3,
        "maxDisplay": (4096 / 12) * 3,
        "scale": 3,
        "gain": 0.4,
        "filterConfig": {
          "filterOn": true,
          "gain": 4,
          "lpf": 3,
          "hpf": 5,
          "notch": 1,
        },
      },
      {
        "name": "O2",
        "scale": 3,
        "boxValue": 5,
        "valueConverter": (double x) {
          // x = x * 0.00072105;
          // 0.0009
          x = x * 0.000917;

          globalSettings = Provider.of<GlobalSettingsModal>(
            context,
            listen: false,
          );
          if (globalSettings.applyConversion == true) {
            o2Calibrate = generateCalibrationFunction(
              voltage1: globalSettings.voltage1,
              value1: globalSettings.value1,
              voltage2: globalSettings.voltage2,
              value2: globalSettings.value2,
            );
            double result = o2Calibrate(x);
            return result;
          }
          return x;
        },
        "unit": "%",
        "flipDisplay": true,
        "minDisplay": -25.0, // <-- Set to -25
        "maxDisplay": 0.0, // <-- Set to 0
        "scalePresets": [
          {
            "minDisplay": -25.0,
            "maxDisplay": -20.0,
            "boxValue": 1.0,
          }, // (-20 - -25)/5 = 1.0
          {
            "minDisplay": -25.0,
            "maxDisplay": -15.0,
            "boxValue": 2.0,
          }, // (-15 - -25)/5 = 2.0
          {
            "minDisplay": -25.0,
            "maxDisplay": -10.0,
            "boxValue": 3.0,
          }, // (-10 - -25)/5 = 3.0
          {
            "minDisplay": -25.0,
            "maxDisplay": -5.0,
            "boxValue": 4.0,
          }, // (-5 - -25)/5 = 4.0
          {
            "minDisplay": -25.0,
            "maxDisplay": 0.0,
            "boxValue": 5.0,
          }, // (0 - -25)/5 = 5.0
        ],
        "scalePresetIndex": 4,
        "filterConfig": {"filterOn": true, "lpf": 3, "hpf": 0, "notch": 0},
        "meter": {
          "decimal": 1,
          "unit":
              Provider.of<GlobalSettingsModal>(
                    context,
                    listen: false,
                  ).applyConversion
                  ? " %"
                  : " mV",
          "convert": (double x, int index) {
            // x = _inMemoryData[index][1];
            // x = x * 0.000917;
            // globalSettings = Provider.of<GlobalSettingsModal>(
            //   context,
            //   listen: false,
            // );
            // if (globalSettings != null &&
            //     globalSettings.applyConversion == true) {

            //   double result = o2Calibrate(x);
            //   return result;
            // }
            // return x;
          },
        },
      },
      {
        "name": "CO2",
        "scale": 3,
        "boxValue": 30 / 6,
        "labelDecimal": 0,
        "valueConverter": (double x) => x / 100,
        "unit": "%",
        "minDisplay": 0,
        "maxDisplay": 30,
        "autoScale": false,
        "scalePresets": [
          {
            "minDisplay": 0.0,
            "maxDisplay": 0.5,
            "boxValue": 0.1,
            "rangeTrigger": 0,
          }, // default
          {
            "minDisplay": 0.0,
            "maxDisplay": 5.0,
            "boxValue": 1.0,
            "rangeTrigger": 3, // was 2, increased for smoother transition
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 10.0,
            "boxValue": 2.0,
            "rangeTrigger": 7, // was 4, increased for smoother transition
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 20.0,
            "boxValue": 4.0,
            "rangeTrigger": 14, // was 9, increased for smoother transition
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 30.0,
            "boxValue": 6.0,
            "rangeTrigger": 24, // was 18, increased for smoother transition
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 40.0,
            "boxValue": 8.0,
            "rangeTrigger": 36, // was 28, increased for smoother transition
          },
        ],
        "scalePresetIndex": 3,
        "filterConfig": {"filterOn": false, "lpf": 3, "hpf": 5, "notch": 1},
        "meter": {
          "decimal": 1,
          "unit": "%",
          "convert": (double x) {
            // print("CO@METER");
            // print(x);
            return x;
          },
        },
      },
      {
        "name": "Flow",
        "scale": 3,
        "scalePresets": [
          {"minDisplay": 0.0, "maxDisplay": 125.0, "boxValue": 25.0},
          {"minDisplay": 0.0, "maxDisplay": 240.0, "boxValue": 50.0},
          {"minDisplay": 0.0, "maxDisplay": 500.0, "boxValue": 100.0},
          {"minDisplay": 0.0, "maxDisplay": 1000.0, "boxValue": 200.0},
          {"minDisplay": 0.0, "maxDisplay": 2000.0, "boxValue": 400.0},
          {"minDisplay": 0.0, "maxDisplay": 4000.0, "boxValue": 800.0},
          {"minDisplay": 0.0, "maxDisplay": 8000.0, "boxValue": 1600.0},
        ],
        "scalePresetIndex": 4,
        "boxValue": 400.0,
        "boxStep": 25.0,
        "unit": "ml/s",
        "minDisplay": 0.0,
        "maxDisplay": 2000.0,
        "meter": {"decimal": 0, "unit": " ", "convert": (double x) => x},
        "yAxisLabelConvert": (double x) => x < 1000 ? x : x / 1000,
        "yAxisLabelUnit": (double x) => x < 1000 ? "ml/s" : "L/s",
        // moving average
        "movingAverage": {"enabled": true, "window": 10},
        "filterConfig": {
          "filterOn": true,
          "lpf": 2,
          "hpf": 7,
          "notch": 1,
          "additionalGainCal": 3.14,
        },
      },
      {
        "name": "Tidal Volume",
        "scale": 3,
        "autoScale": false,
        "scalePresets": [
          {
            "minDisplay": 0.0,
            "maxDisplay": 125.0,
            "boxValue": 25.0,
            "rangeTrigger": 0,
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 240.0,
            "boxValue": 50.0,
            "rangeTrigger": 150,
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 500.0,
            "boxValue": 100.0,
            "rangeTrigger": 300,
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 1000.0,
            "boxValue": 200.0,
            "rangeTrigger": 700,
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 2000.0,
            "boxValue": 400.0,
            "rangeTrigger": 1500,
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 4000.0,
            "boxValue": 800.0,
            "rangeTrigger": 3000,
          },
          {
            "minDisplay": 0.0,
            "maxDisplay": 8000.0,
            "boxValue": 1600.0,
            "rangeTrigger": 6000,
          },
        ],
        "scalePresetIndex": 4,
        "boxValue": 400.0,
        "boxStep": 25.0,
        "unit": "ml",
        "minDisplay": 0.0,
        "maxDisplay": 2000.0,
        "meter": {"decimal": 0, "unit": " ", "convert": (double x) => x},
        "yAxisLabelConvert": (double x) => x < 1000 ? x : x / 1000,
        "yAxisLabelUnit": (double x) => x < 1000 ? "ml" : "L",
      },
    ];

    // startTestLoop(); // Start  the test loop
  }

  initFunc() async {
    globalSettings = Provider.of<GlobalSettingsModal>(context, listen: false);
    print('here');
    print(globalSettings.applyConversion);
    o2Calibrate = generateCalibrationFunction(
      voltage1: globalSettings.voltage1,
      value1: globalSettings.value1,
      voltage2: globalSettings.voltage2,
      value2: globalSettings.value2,
    );
    // await loadGlobalSettingsFromPrefs();
    print("INIT");
  }

  bool _saverInitialized = false;
  List<double> _buffer = []; // Store [ecg, o2, co2, vol, flow, ecg, o2, ...]
  final int _samplesPerBatch = 300 * 5; // 5 seconds worth of data
  int bufSampleCounter = 0; // Reset this to 0 when starting a new batch
  bool _isAppendingBatch = false;
  Future? _initFuture; // Add this to your class

  Future<void> saver({
    required double ecg,
    required double o2,
    required double co2,
    required double vol,
    required double flow,
  }) async {
    final patientProvider = Provider.of<DefaultPatientModal>(
      context,
      listen: false,
    );
    final patient = patientProvider.patient;
    if (patient == null) return;

    // 🛠 Make sure init is awaited before marking initialized
    if (!_saverInitialized) {
      _initFuture ??= () async {
        if (!dataSaver.initialized) {
          print("✅ Initializing DataSaver...");
          await dataSaver.init(
            filename: "holtersync-${DateTime.now().microsecondsSinceEpoch}.bin",
            patientInfo: patient,
          );
          _saverInitialized = true;
          sampleCounter = 0;
        }
      }();
      await _initFuture;
    }

    _buffer.addAll([ecg, o2, co2, vol, flow]);
    sampleCounter++;
    bufSampleCounter++;

    if (bufSampleCounter >= _samplesPerBatch && !_isAppendingBatch) {
      _isAppendingBatch = true;
      print("Batch of ${_buffer.length ~/ 5} samples ready to save.");
      await dataSaver.appendBatch(_buffer);
      _buffer.clear();
      bufSampleCounter = 0; // Reset buffer sample counter
      _isAppendingBatch = false; // Reset appending state
    }
  }

  Future<void> flushRemainingData() async {
    if (_buffer.isNotEmpty) {
      await dataSaver.appendBatch(_buffer);
      print("✅ Flushed ${_buffer.length ~/ 5} samples.");
      _buffer.clear();
    }
  }

  loadGlobalSettingsFromPrefs() async {
    prefs = await SharedPreferences.getInstance();
    if (prefs!.containsKey("globalSettings")) {
      var globalSettingsJson = prefs!.getString("globalSettings");
      globalSettings.fromJson(globalSettingsJson); // ✅ using global
    }
  }

  Future<List<double>> loadTestData() async {
    final byteData = await rootBundle.load('assets/capturen.txt');
    final rawBytes = byteData.buffer.asUint8List();
    String rawData = String.fromCharCodes(rawBytes);

    // Remove non-hex characters
    String hexOnly = rawData.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    List<double> byteValues = [];

    for (int i = 0; i <= hexOnly.length - 2; i += 2) {
      String hexByte = hexOnly.substring(i, i + 2);
      int value = int.parse(hexByte, radix: 16);
      byteValues.add(
        value.toDouble(),
      ); // Store as double to match expected type
    }

    return byteValues;
  }

  List<double> testData = [];
  int dataIndex = 0;

  init() {
    Provider.of<GlobalSettingsModal>(context, listen: false);

    port = SerialPort(globalSettings.com.toString());

    try {
      if (port.isOpen) {
        print("ℹ️ Port is already open.");
      } else {
        if (!port.openReadWrite()) {
          print("❌ Failed to open port.");
          print("Last error: ${SerialPort.lastError}");
        } else {
          print("✅ Port opened successfully.");
        }
      }
    } catch (e) {
      print("❌ Exception while opening port: $e");
    }

    try {
      final config = port.config;
      config.baudRate = 230400;
      port.config = config;
      config.bits = 8;
      config.stopBits = 1;
      config.stopBits = 1;
      config.xonXoff = 0;
      config.rts = 0;
      config.cts = 0;
      config.dsr = 0;
      config.dtr = 1;
      port.config = config;

      port.write(Uint8List.fromList([0x0D]));
    } catch (error) {
      print(error);
      // ignoring error
    } finally {
      // widget.port.dispose();
    }
    // await Future.delayed(Duration(milliseconds: 300));
    // print('✅ Serial port opened! Flushing...');

    // Create a reader
    // SerialPortReader reader = SerialPortReader(port);
  }

  int lastNotifierUpdate = DateTime.now().millisecondsSinceEpoch;

  @override
  void dispose() {
    recordingTimer?.cancel();
    timer.cancel();
    port.close();
    super.dispose();
  }

  void startRecordingTimer() {
    recordingTimer?.cancel();
    recordingDuration = Duration.zero;

    // Use sampleCounter and samplingRate to calculate duration
    recordingTimer = Timer.periodic(Duration(milliseconds: 200), (_) {
      setState(() {
        // Replace 300 with your actual sampling rate if needed
        recordingDuration = Duration(seconds: (sampleCounter / 300).floor());
      });
    });
  }

  void stopRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = null;
    recordingStartTime = null;
    recordingDuration = Duration.zero;
  }

  // Import state for "Load New Holter"
  bool _isImportingHolter = false;
  double _holterImportProgress = 0.0;

  /// Opens a file picker for a raw Holter file, converts it to our .bin format,
  /// stores it under HolterSync/Records, and inserts a row into local DB.
  Future<void> _importNewHolterFile() async {
    setState(() {
      _isImportingHolter = true;
      _holterImportProgress = 0.0;
    });

    try {
      // 1) Pick source file
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Holter file to import',
        type: FileType.any,
      );
      if (res == null || res.files.single.path == null) {
        setState(() {
          _isImportingHolter = false;
        });
        return;
      }
      final srcPath = res.files.single.path!;
      final srcFile = File(srcPath);
      final Uint8List raw = await srcFile.readAsBytes();

      // 2) Convert raw bytes to Float64 ECG values (based on provided logic)
      // We scan for 0x55 0xAA frame marker, then take 25 samples per frame
      // using bytes at offsets +2 and +3 with stride 8.
      final List<double> ecg = <double>[];
      int i = 0;
      final int total = raw.length;
      while (i < total - 1) {
        if (raw[i] == 85 && raw[i + 1] == 170) {
          // 0x55, 0xAA
          int f2 = i + 2;
          int f3 = i + 3;
          for (int j = 0; j < 25; j++) {
            if (f2 < total && f3 < total) {
              int val = raw[f3] * 255 + raw[f2];
              ecg.add(val.toDouble());
              f2 += 8;
              f3 += 8;
            } else {
              break;
            }
          }
          i = f3 - 1; // jump to end of frame block
        } else {
          i += 1;
        }
        if (total > 0) {
          _holterImportProgress = i / total;
          if (mounted) setState(() {});
        }
      }

      if (ecg.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No ECG samples decoded from the file.')),
        );
        setState(() {
          _isImportingHolter = false;
        });
        return;
      }

      // 3) Build our .bin file with JSON header + 5-channel Float64 samples
      // Prepare header JSON: include current default patient, minimal metadata
      final defaultPatient =
          Provider.of<DefaultPatientModal>(context, listen: false).patient;
      final Map<String, dynamic> headerJson = {
        'patient': defaultPatient ?? {},
        'format': 'holtersync-bin-v1',
        'samplingRate': 300,
        'channels': ['ECG', 'O2', 'CO2', 'Vol', 'Flow'],
        'createdAt': DateTime.now().toIso8601String(),
      };
      final headerBytes = utf8.encode(jsonEncode(headerJson));
      final headerLenBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, headerBytes.length, Endian.little);

      // Prepare samples buffer: write [ecg, 0, 0, 0, 0] per sample
      final int sampleCount = ecg.length;
      const int bytesPerSample = 5 * 8; // 5 Float64
      final Uint8List samplesBytes = Uint8List(sampleCount * bytesPerSample);
      final ByteData bd = ByteData.view(samplesBytes.buffer);
      for (int s = 0; s < sampleCount; s++) {
        final double e = ecg[s].isFinite ? ecg[s] : 0.0;
        final int base = s * bytesPerSample;
        bd.setFloat64(base + 0, e, Endian.little); // ECG
        bd.setFloat64(base + 8, 0.0, Endian.little); // O2
        bd.setFloat64(base + 16, 0.0, Endian.little); // CO2
        bd.setFloat64(base + 24, 0.0, Endian.little); // Vol
        bd.setFloat64(base + 32, 0.0, Endian.little); // Flow
      }

      // 4) Save to HolterSync/Records
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final String recordsDirPath = p.join(
        docsDir.path,
        'HolterSync',
        'Records',
      );
      final Directory recordsDir = Directory(recordsDirPath);
      if (!await recordsDir.exists()) {
        await recordsDir.create(recursive: true);
      }
      final String fileName = 'recording_${Uuid().v4()}.bin';
      final String savePath = p.join(recordsDirPath, fileName);
      await File(
        savePath,
      ).writeAsBytes(headerLenBytes + headerBytes + samplesBytes);

      // 5) Insert DB row
      final db = Provider.of<AppDatabase>(context, listen: false);
      final patient = defaultPatient;
      if (patient != null && patient['id'] != null) {
        await db
            .into(db.recordings)
            .insert(
              RecordingsCompanion(
                patientId: drift.Value(patient['id'] as int),
                filePath: drift.Value(savePath),
                createdAt: drift.Value(DateTime.now()),
                recordedAt: drift.Value(DateTime.now()),
              ),
            );
        print('✅ New holter saved in DB: $savePath');
      } else {
        print('⚠️ No default patient selected; saving file only.');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Holter imported and saved.')));

      setState(() {
        _isImportingHolter = false;
        _holterImportProgress = 1.0;
      });
    } catch (e, st) {
      print('❌ Import holter failed: $e');
      print(st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import holter: $e')));
        setState(() {
          _isImportingHolter = false;
        });
      }
    }
  }

  playPause() {
    if (isPlaying) {
      return IconButton(
        onPressed: () {
          // use provider to ensure context linking but value is read later
          Provider.of<GlobalSettingsModal>(context, listen: false);
          // SerialPort port = SerialPort(globalSettings.com.toString());
          port.close();
          resetAllData();
          setState(() {
            isPlaying = false;
          });
        },
        icon: Icon(Icons.pause_circle, size: 40, color: Colors.black),
        tooltip: "Stop Monitoring",
      );
    }
    if (!isPlaying) {
      return IconButton(
        onPressed: () {
          init();
          setState(() {
            isPlaying = true;
          });
        },
        icon: Icon(Icons.play_circle_fill, size: 40, color: Colors.green),
        tooltip: "Start Monitoring",
      );
    }
  }

  ChartDialog() {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.zero,
            child: SavedChartsDialogContent(cp: completeCp),
          ),
    );
  }

  Future<Map<String, dynamic>?> importBinFile() async {
    // Step 1: Let user pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select .bin file to import',
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result == null || result.files.single.path == null) {
      print("⚠️ User cancelled or no file selected.");
      return null;
    }

    final path = result.files.single.path!;
    final file = File(path);
    final bytes = await file.readAsBytes();

    if (bytes.length < 4) {
      print("❌ File too short to contain header.");
      return null;
    }

    // Step 2: Read header length
    final headerLen = ByteData.sublistView(
      bytes,
      0,
      4,
    ).getUint32(0, Endian.little);
    if (headerLen <= 0 || headerLen > 8192) {
      print("❌ Invalid header length: $headerLen");
      return null;
    }

    if (bytes.length < 4 + headerLen) {
      print("❌ File doesn't contain full header.");
      return null;
    }

    // Step 3: Decode patient JSON
    final jsonBytes = bytes.sublist(4, 4 + headerLen);
    final String jsonText = utf8.decode(jsonBytes);
    final Map<String, dynamic> patientInfo = jsonDecode(jsonText);

    // Step 4: Read samples
    const bytesPerSample = 5 * 8;
    final sampleData = bytes.sublist(4 + headerLen);
    final int sampleCount = sampleData.length ~/ bytesPerSample;

    List<List<double>> samples = [];

    for (int i = 0; i < sampleCount; i++) {
      final start = i * bytesPerSample;
      final chunk = sampleData.sublist(start, start + bytesPerSample);
      final bd = ByteData.sublistView(chunk);

      samples.add([
        bd.getFloat64(0, Endian.little), // ECG
        bd.getFloat64(8, Endian.little), // O2
        bd.getFloat64(16, Endian.little), // CO2
        bd.getFloat64(24, Endian.little), // Vol
        bd.getFloat64(32, Endian.little), // Flow
      ]);
    }

    // Touch first element (if any) so analyzer treats the variable as used
    if (samples.isNotEmpty) {
      final _firstSample = samples.first;
      if (_firstSample.length == 5) {
        // no-op, just to reference content
      }
    }
    print("✅ Imported ${samples.length} samples from $path");
    return {"patient": patientInfo, "samples": samples};
  }

  double importProgressPercent = 0.0;
  double currentImportDisplayIndex = 0;
  File? importedFile;
  Map<String, dynamic>? importedProtocol;
  List<Map<String, dynamic>> importedMarkers = [];

  Future<void> importBinFileFromPath(String path) async {
    print("Importing file from path: $path");
    setState(() {
      importProgressPercent = 0.0;
    });

    try {
      // Step 1: Import file
      final file = File(path);
      importedFile = file;
      final bytes = await file.readAsBytes();

      if (bytes.length < 4) {
        print("❌ File too short to contain header.");
        return;
      }

      final headerLen = ByteData.sublistView(
        bytes,
        0,
        4,
      ).getUint32(0, Endian.little);
      if (headerLen <= 0 || headerLen > 8192) {
        print("❌ Invalid header length: $headerLen");
        return;
      }

      if (bytes.length < 4 + headerLen) {
        print("❌ File doesn't contain full header.");
        return;
      }

      final jsonBytes = bytes.sublist(4, 4 + headerLen);
      final String jsonText = utf8.decode(jsonBytes);
      final Map<String, dynamic> patient = jsonDecode(jsonText);

      const bytesPerSample = 5 * 8;
      final sampleData = bytes.sublist(4 + headerLen);
      final int sampleCount = sampleData.length ~/ bytesPerSample;
      print(patient);

      // Step 2: Set patient info
      final defaultProvider = Provider.of<DefaultPatientModal>(
        context,
        listen: false,
      );
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('default_patient', jsonEncode(patient));
      defaultProvider.setDefault(patient);
      // Step 2.5: Store imported protocol and markers for later use

      if (patient.containsKey('protocolDetails')) {
        importedProtocol = patient['protocolDetails'];
      }
      if (patient.containsKey('markers')) {
        final markersRaw = patient['markers'];
        if (markersRaw is List) {
          importedMarkers =
              markersRaw
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        }
      }
      // Step 3: Push all samples to graph and memory (combined loop)
      _inMemoryData.clear();
      for (int i = 0; i < sampleCount; i++) {
        final start = i * bytesPerSample;
        final chunk = sampleData.sublist(start, start + bytesPerSample);
        final bd = ByteData.sublistView(chunk);

        final List<double> numericSample = [
          bd.getFloat64(0, Endian.little), // ECG
          bd.getFloat64(8, Endian.little), // O2
          bd.getFloat64(16, Endian.little), // CO2
          bd.getFloat64(24, Endian.little), // Vol
          bd.getFloat64(32, Endian.little), // Flow
        ];

        // Flip the last two values
        final temp = numericSample[3];
        numericSample[3] = numericSample[4];
        numericSample[4] = temp;

        final edt = myBigGraphKey.currentState?.updateEverythingWithoutGraph(
          numericSample,
        );
        if (edt != null && edt.length >= 5) {
          _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], edt[4]]);
        }
      }

      // Pad data so it's always a multiple of 20 seconds (6000 samples)
      // int windowSize = 20 * 300; // 20 seconds × 300Hz
      // int remainder = _inMemoryData.length % windowSize;
      // if (remainder != 0 && _inMemoryData.isNotEmpty) {
      //   int padCount = windowSize - remainder;
      //   List<double> lastSample = _inMemoryData.last;
      //   for (int i = 0; i < padCount; i++) {
      //     _inMemoryData.add(List<double>.from(lastSample));
      //   }
      //   print(
      //     "Padded $_inMemoryData with $padCount samples for window compatibility.",
      //   );
      // }

      print("Imported $sampleCount samples.");
      setState(() {
        importProgressPercent = 1.0;
        isImported = true;
      });
      // onExhalationDetected(isComplete: true);
    } catch (e) {
      print("❌ Error while importing: $e");
      setState(() {
        importProgressPercent = 0.0;
      });
    }
    getSamplesFromFile(currentImportDisplayIndex.toInt());
    print("✅ Import completed.");
  }

  getSamplesFromFile(
    int index, {
    int seconds = 20,
    int samplingRate = 300,
  }) async {
    // Each sample is 5 float64 values (8 bytes each)
    const bytesPerSample = 5 * 8;
    final file = importedFile!;
    final bytes = await file.readAsBytes();

    if (bytes.length < 4) return [];

    // Read header length
    final headerLen = ByteData.sublistView(
      bytes,
      0,
      4,
    ).getUint32(0, Endian.little);
    if (headerLen <= 0 || headerLen > 8192) return [];

    final sampleData = bytes.sublist(4 + headerLen);
    final int sampleCount = sampleData.length ~/ bytesPerSample;

    // Calculate start and end indices
    int startIndex = index;
    int count = seconds * samplingRate;
    int endIndex = (startIndex + count).clamp(0, sampleCount);

    // List<List<double>> samples = [];
    List<List<double>> chunkData = [];
    for (int i = startIndex; i < endIndex; i++) {
      final start = i * bytesPerSample;
      final chunk = sampleData.sublist(start, start + bytesPerSample);
      final bd = ByteData.sublistView(chunk);

      final List<double> numericSample = [
        bd.getFloat64(0, Endian.little), // ECG
        bd.getFloat64(8, Endian.little), // O2
        bd.getFloat64(16, Endian.little), // CO2
        bd.getFloat64(24, Endian.little), // Vol
        bd.getFloat64(32, Endian.little), // Flow
      ];

      // Flip the last two values
      final temp = numericSample[3];
      numericSample[3] = numericSample[4];
      numericSample[4] = temp;

      // // Add to graph (without drawing)
      // myBigGraphKey.currentState?.clean();
      // wait
      // await Future.delayed(Duration(milliseconds: 100));

      final edt = myBigGraphKey.currentState?.updateEverything(numericSample);
      if (edt != null && edt.length >= 5) {
        chunkData.add([edt[0], edt[1], edt[2], edt[3], edt[4]]);
      }
      // if (edt != null && edt.length >= 5) {
      //   _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], edt[4]]);
      // }

      // samples.add(numericSample);
    }
    if (chunkData.length < count && chunkData.isNotEmpty) {
      final lastSample = chunkData.last;
      final padCount = count - chunkData.length;
      for (int i = 0; i < padCount; i++) {
        // final edt = myBigGraphKey.currentState?.updateEverything(numericSample);
        chunkData.add(List<double>.from(lastSample));
        // graph
        myBigGraphKey.currentState?.updateEverything(lastSample);
      }
    }
    // onExhalationDetected(data: chunkData);
    // return samples;
  }

  // _nextPreviousButtons() removed (unused)

  void showImportingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 18),
                  Text(
                    "Importing file...",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _runHolterFromRecordingId(int recordingId) async {
    try {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final holter = HolterReportGenerator();
      await holter.initWithRecordingId(db, recordingId);

      var dt = await holter.getSlice200(15); // first 20 seconds for preview
      print(dt);
      print("Holter analysis done for recording ID: $recordingId");
      print("Avg BPM: ${holter.avrBpm.toStringAsFixed(1)}");
      print("Min BPM: ${holter.minBpm.toStringAsFixed(1)}");
      print("Max BPM: ${holter.maxBpm.toStringAsFixed(1)}");

      final conditions =
          holter.conditions is List ? (holter.conditions as List) : const [];
      if (conditions.isEmpty) {
        print("No conditions detected.");
      } else {
        for (final c in conditions) {
          final name = c['name']?.toString() ?? 'Unknown';
          final count = (c['index'] is List) ? (c['index'] as List).length : 0;
          print("Condition: $name — $count events");
        }
      }
    } catch (e, st) {
      print("Holter analysis failed: $e");
      print(st);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final importProvider = Provider.of<ImportFileProvider>(context);
    print("ImportFileProvider recordingId:");
    print(importProvider.recordingId);
    // New flow: recordingId from the "Load Data" page
    if (importProvider.recordingId != null) {
      final int recId = importProvider.recordingId!;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        print("Importing recording ID: $recId");
        await _runHolterFromRecordingId(recId);
        importProvider.clear(); // ensure it won’t re-trigger
      });
      return;
    }
  }

  Future<void> saveRecordingSlice() async {
    if (!_saverInitialized) {
      print("❌ DataSaver not initialized. SRS");
      return;
    }

    final file = File(dataSaver.path);
    if (!file.existsSync()) {
      print("❌ File does not exist.");
      return;
    }

    final fullBytes = await file.readAsBytes();

    if (fullBytes.length < 4) {
      print("❌ File too small to contain header.");
      return;
    }

    final headerLen = ByteData.sublistView(
      fullBytes,
      0,
      4,
    ).getUint32(0, Endian.little);
    if (headerLen <= 0 || headerLen > 8192) {
      print("❌ Invalid JSON header length: $headerLen");
      return;
    }

    final headerEnd = 4 + headerLen;
    if (headerEnd >= fullBytes.length) {
      print("❌ File doesn't contain enough bytes for header + samples.");
      return;
    }

    final sampleBytes = fullBytes.sublist(headerEnd);
    const bytesPerSample = 5 * 8; // 5 float64 values

    final maxSamples = sampleBytes.length ~/ bytesPerSample;
    final clampedEndIndex = min(recordEndIndex ?? 0, maxSamples);
    final clampedStartIndex = min(recordStartIndex ?? 0, clampedEndIndex);

    final startByte = clampedStartIndex * bytesPerSample;
    final endByte = clampedEndIndex * bytesPerSample;

    if (startByte >= endByte || endByte > sampleBytes.length) {
      print("❌ Invalid byte range. Start: $startByte, End: $endByte");
      return;
    }

    final selectedBytes = sampleBytes.sublist(startByte, endByte);
    final headerJsonBytes = fullBytes.sublist(4, headerEnd);
    // final lengthBytes = fullBytes.sublist(0, 4);

    // ✅ Get documents directory
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final String recordingsPath = p.join(docsDir.path, 'HolterSync', 'Records');
    final recordingsDir = Directory(recordingsPath);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    // ✅ Generate a random filename
    final uuid = Uuid();
    final randomName = 'recording_${uuid.v4()}.bin';
    final savePath = p.join(recordingsPath, randomName);

    // --- Add protocol details to header JSON ---
    Map<String, dynamic> headerJson = {};
    try {
      headerJson = jsonDecode(utf8.decode(headerJsonBytes));
    } catch (e) {
      print("❌ Failed to decode header JSON: $e");
    }

    // Get protocol details
    dynamic protocolDetails;
    try {
      final globalSettings = Provider.of<GlobalSettingsModal>(
        context,
        listen: false,
      );
      protocolDetails = ProtocolManifest().getSelectedProtocol(globalSettings);
    } catch (e) {
      protocolDetails = {"error": e.toString()};
    }
    headerJson['protocolDetails'] = protocolDetails;

    // also add markers
    headerJson['markers'] = markers;
    // Encode new header JSON and recalculate length
    final newHeaderJsonBytes = utf8.encode(jsonEncode(headerJson));
    final newHeaderLenBytes = Uint8List(4)
      ..buffer.asByteData().setUint32(
        0,
        newHeaderJsonBytes.length,
        Endian.little,
      );

    // Save file with updated header
    await File(
      savePath,
    ).writeAsBytes(newHeaderLenBytes + newHeaderJsonBytes + selectedBytes);
    print("✅ Saved recording to: $savePath");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Recording saved to file successfully.")),
    );

    // ✅ Store file path and patient id in database
    final db = Provider.of<AppDatabase>(context, listen: false);
    final patientProvider = Provider.of<DefaultPatientModal>(
      context,
      listen: false,
    );
    final patient = patientProvider.patient;
    if (patient != null && patient['id'] != null) {
      await db
          .into(db.recordings)
          .insert(
            RecordingsCompanion(
              patientId: drift.Value(patient['id'] as int),
              filePath: drift.Value(savePath),
              createdAt: drift.Value(DateTime.now()),
              recordedAt: drift.Value(DateTime.now()),
            ),
          );
      print("✅ Recording info saved in database.");
    } else {
      print("❌ No patient selected, cannot save recording info in database.");
    }
  }

  void resetAllData({bool import = false}) {
    setState(() {
      // Reset live metrics
      votwo = 0;
      votwokg = 0;
      vco = 0;
      rer = 0;
      vol = 0;
      flow = 0;
      bpm = 0;
      respirationRate = 0;

      // Reset counters and flags
      sampleCounter = 0;
      bufSampleCounter = 0;
      _saverInitialized = false;
      _initFuture = null;
      if (dataSaver.initialized) {
        dataSaver.reset();
      }
      recordStartIndex = null;
      recordEndIndex = null;
      isRecording = false;
      cp = null;
      fullCp = null;

      // Clear buffers and data
      _buffer.clear();
      delayBuffer.clear();
      rawDataFull.clear();
      _inMemoryData.clear();
      breathStatsNotifier.value = [];

      // Reset graph widget
      myBigGraphKey.currentState?.reset();

      // Reset flags
      isImported = import;

      importProgressPercent = 0.0;
      currentImportDisplayIndex = 0;
    });
  }

  _stopRecording() async {
    // comment for simulatedrecordings
    if (treadmillController?.isOpen == true) {
      treadmillController!.sendCommand([0xA2]);
    }
    port.close();
    treadmillController?.close();

    print("Stopping recording...");

    recordEndIndex = sampleCounter;
    print("Recording stopped at index: $recordEndIndex");
    setState(() {
      isRecording = false;
      isPlaying = false;
    });
    stopRecordingTimer(); // Stop timer
    await flushRemainingData();
    await saveRecordingSlice(); // implement next
    resetAllData();
  }

  Widget recordingIndicator() {
    if (!isRecording) return SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100.withOpacity(0.2),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text(
            "${recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DefaultPatientModal>(
      builder: (context, defaultProvider, child) {
        // final defaultPatient = defaultProvider.patient;
        return Scaffold(
          // appBar: AppBar(
          //   title: Text("SprioBT VO2"),
          //   actions: [
          //     IconButton(
          //       onPressed: () {
          //         Navigator.of(context).push(
          //           MaterialPageRoute(builder: (context) => GlobalSettings()),
          //         );
          //       },
          //       icon: Icon(Icons.settings),
          //     ),
          //     // IconButton(
          //     //   onPressed: () {
          //     //     init();
          //     //   },
          //     //   icon: Icon(Icons.refresh),
          //     // ),
          //   ],
          // ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // bar
                Container(
                  alignment: Alignment.center,
                  color: Colors.blue.shade700,
                  height: 70,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButtonColumn(
                          icon: isPlaying ? Icons.pause : Icons.play_arrow,
                          label: isPlaying ? "Pause" : "Play",
                          onPressed: () {
                            if (isPlaying) {
                              // final globalSettings =
                              Provider.of<GlobalSettingsModal>(
                                context,
                                listen: false,
                              );
                              port.close();
                              resetAllData();
                              setState(() {
                                isPlaying = false;
                              });
                            } else {
                              init();
                              setState(() {
                                isPlaying = true;
                              });
                            }
                          },
                        ),
                        IconButtonColumn(
                          icon:
                              isRecording
                                  ? Icons.stop
                                  : Icons.fiber_manual_record,
                          label: isRecording ? "Stop" : "Record",
                          onPressed: () async {
                            if (!isRecording) {
                              resetAllData(); // Reset all data before starting
                              // reset graph
                              myBigGraphKey.currentState?.resetXAxisTimer();
                              recordStartIndex = sampleCounter;
                              print(
                                "Recording started at index: $recordStartIndex",
                              );

                              final globalSettings =
                                  Provider.of<GlobalSettingsModal>(
                                    context,
                                    listen: false,
                                  );
                              if (globalSettings.deviceType == "treadmill") {
                                treadmillController ??=
                                    TreadmillSerialController();
                                treadmillController!.open(
                                  globalSettings.machineCom,
                                );

                                // --- SEND START BELT COMMAND ---
                                treadmillController!.sendCommand([0xA0]);
                                await Future.delayed(
                                  Duration(milliseconds: 1000),
                                );
                                // --- SEND SET SPEED COMMAND ---
                                treadmillController!.sendCommand([0xA1]);
                              }

                              setState(() {
                                isRecording = true;
                              });
                              startRecordingTimer(); // Start timer
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Recording started")),
                              );
                            } else {
                              // Stop recording
                              _stopRecording();
                            }
                          },
                        ),
                        IconButtonColumn(
                          icon: Icons.save_alt,
                          label: "Load Data",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => RecordingsListPage(),
                              ),
                            );
                          },
                        ),

                        // New: Load New Holter (raw holter -> convert -> save -> DB)
                        IconButtonColumn(
                          icon: Icons.upload_file,
                          label:
                              _isImportingHolter
                                  ? "Importing ${(100 * _holterImportProgress).toStringAsFixed(0)}%"
                                  : "Load New Holter",
                          onPressed: () {
                            if (_isImportingHolter) return;
                            _importNewHolterFile();
                          },
                        ),

                        IconButtonColumn(
                          icon: Icons.person,
                          label: "Patients",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PatientsList(),
                              ),
                            );
                          },
                        ),
                        IconButtonColumn(
                          icon: Icons.person_add,
                          label: "Add Patient",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PatientAdd(),
                              ),
                            );
                          },
                        ),
                        IconButtonColumn(
                          icon: Icons.bar_chart,
                          label: "Charts",
                          onPressed: () {
                            ChartDialog();
                          },
                        ),
                        // IconButtonColumn(
                        //   icon: Icons.auto_graph,
                        //   label: "Generate",
                        //   onPressed: () {
                        //     if (cp != null && cp!['breathStats'] is List) {
                        //       Navigator.of(context).push(
                        //         MaterialPageRoute(
                        //           builder: (context) => ChartGenerator(cp: cp),
                        //         ),
                        //       );
                        //     }
                        //   },
                        // ),
                        IconButtonColumn(
                          icon: Icons.settings,
                          label: 'Settings',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GlobalSettings(),
                              ),
                            );
                          },
                        ),
                        IconButtonColumn(
                          icon: Icons.picture_as_pdf,
                          label: "Print PDF",
                          onPressed: () async {
                            print("Print PDF button pressed");
                            print("isImported: $isImported");
                            print("cp: $cp");
                            if (isImported &&
                                cp != null &&
                                cp!['breathStats'] is List) {
                              // Optionally, generate chart images as base64 and pass as graphBase64List
                              List<String>? graphBase64List;
                              // graphBase64List = await generateYourGraphBase64List(); // implement if needed

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ReportPreviewPage(
                                        patient:
                                            Provider.of<DefaultPatientModal>(
                                              context,
                                              listen: false,
                                            ).patient ??
                                            {},
                                        breathStats: completeCp!["breathStats"],
                                        markers: importedMarkers,
                                        protocolDetails: importedProtocol,
                                        graphBase64List: graphBase64List,
                                        inMemoryData: List<List<double>>.from(
                                          _inMemoryData,
                                        ), // <-- Add this line
                                      ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Import data first to print PDF.",
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        //
                        IconButtonColumn(
                          icon: Icons.exit_to_app,
                          label: "Exit",
                          onPressed: () {
                            if (Platform.isWindows) {
                              exit(0);
                            } else {
                              SystemNavigator.pop();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: MyBigGraphV2(
                        key: myBigGraphKey,
                        markerIndices:
                            globalSettings.breathCalibrationMarker
                                ? breathPeakIndicesNotifier
                                : breathPeakIndicesNotifierEmpty, // <-- NEW
                        // if(delaySamples == null) {
                        isImported: false,
                        onCycleComplete: () {
                          // if(delaySamples == null) {
                          //   CPETService cpet = CPETService();
                          //   delaySamples = cpet.detectO2Co2DelayFromVolumePeaks(
                          //       _inMemoryData);
                          //   print("DELAY REQ");
                          //   print(delaySamples);
                          // }
                        },
                        streamConfig: [
                          {
                            "vo2": {
                              "fun": (e) {
                                if (e.length > 2 &&
                                    e[1] != null &&
                                    e[4] != null) {
                                  double o2Percent = e[1] * 0.013463 - 0.6;
                                  double flow = e[4];
                                  return flow * (20.93 - o2Percent);
                                } else {
                                  return null;
                                }
                              },
                            },
                          },
                          {
                            "vco2": {
                              "fun": (e) {
                                if (e.length > 3 &&
                                    e[4] != null &&
                                    e[4] != null) {
                                  double co2Fraction = e[2] / 100; // CO₂ %
                                  double flow = e[4]; // Flow in L/min
                                  return flow * co2Fraction;
                                } else {
                                  return null;
                                }
                              },
                            },
                          },
                        ],

                        onStreamResult: (resultMap) {
                          setState(() {
                            // votwo = resultMap["vo2"];
                            // vco = resultMap["vco2"];
                            // if (defaultPatient != null) {
                            //   double weight = double.parse(
                            //     defaultPatient["weight"],
                            //   );
                            //   votwokg = resultMap["vo2"] / weight;
                            // }
                            // if (votwo != null && votwo != null && votwo != 0) {
                            //   rer = vco / votwo;
                            // } else {
                            //   rer = 0; // Or 0.0 or "--"
                            // }
                          });
                        },
                        plot: plotConfig, // <-- Use state variable here
                        windowSize: 6000,
                        verticalLineConfigs: [
                          {
                            'seconds': 0.5,
                            'stroke': 0.5,
                            'color': Colors.blue.shade100,
                          },
                          {
                            'seconds': 1.0,
                            'stroke': 0.8,
                            'color': Colors.red.shade100,
                          },
                        ],
                        horizontalInterval: 4096 / 12,
                        verticalInterval: 8,
                        samplingRate: 300,
                        minY: -(4096 / 12) * 5,
                        maxY: (4096 / 12) * 25,
                      ),
                    ),

                    // Text("Ss")
                    // _vitals(defaultPatient: defaultPatient),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
