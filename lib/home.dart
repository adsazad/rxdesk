import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:spirobtvo/Pages/RecordingsListPage.dart';
import 'package:spirobtvo/ProtocolManifests/ProtocolManifest.dart';
import 'package:spirobtvo/ProviderModals/ImportFileProvider.dart';
import 'package:spirobtvo/Services/MachineControllers/LodeErgometerController.dart';
import 'package:spirobtvo/Services/TreadmillSerialController.dart';
import 'package:spirobtvo/Services/Utility.dart';
import 'package:spirobtvo/Widgets/BreathStatsTableModal.dart';
import 'package:spirobtvo/Widgets/MyBigGraphScrollable.dart';
import 'package:spirobtvo/Widgets/current_co2_display.dart';
import 'package:spirobtvo/Widgets/current_o2_display.dart';
import 'package:spirobtvo/data/local/database.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libserialport/libserialport.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/Pages/ChartGenerator.dart';
import 'package:spirobtvo/Pages/GlobalSettings.dart';
import 'package:spirobtvo/Pages/patient/list.dart';
import 'package:spirobtvo/Pages/patient/patientAdd.dart';
import 'package:spirobtvo/ProviderModals/DefaultPatientModal.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';
import 'package:spirobtvo/Services/CPETService.dart';
import 'package:spirobtvo/Services/CalibrationFunction.dart';
import 'package:spirobtvo/Services/DataSaver.dart';
import 'package:spirobtvo/Services/EcgBPMCalculator.dart';
import 'package:spirobtvo/Widgets/CustomLineChart.dart';
import 'package:spirobtvo/Widgets/MyBigGraph.dart';
import 'package:spirobtvo/Widgets/VitalsBox.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:spirobtvo/ReportPreviewPage.dart'; // <-- Import your preview page
import 'package:spirobtvo/SavedChartsDialogContent.dart';
import 'package:spirobtvo/Widgets/IconButtonColumn.dart';
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
          if (globalSettings != null &&
              globalSettings.applyConversion == true) {
            double result = o2Calibrate(x);
            return result;
          }
          return x;
        },
        "unit": "%",
        "flipDisplay": true,
        "minDisplay": -30.0, // <-- Set to -30
        "maxDisplay": 0.0, // <-- Set to 0
        "scalePresets": [
          {"minDisplay": -5.0, "maxDisplay": 0.0, "boxValue": 1.0},
          {"minDisplay": -10.0, "maxDisplay": 0.0, "boxValue": 2.0},
          {"minDisplay": -20.0, "maxDisplay": 0.0, "boxValue": 4.0},
          {"minDisplay": -30.0, "maxDisplay": 0.0, "boxValue": 6.0},
          {"minDisplay": -40.0, "maxDisplay": 0.0, "boxValue": 8.0},
          {"minDisplay": -50.0, "maxDisplay": 0.0, "boxValue": 10.0},
        ],
        "scalePresetIndex": 3,
        "filterConfig": {"filterOn": true, "lpf": 3, "hpf": 0, "notch": 0},
        "meter": {
          "decimal": 3,
          "unit":
              Provider.of<GlobalSettingsModal>(
                    context,
                    listen: false,
                  ).applyConversion
                  ? " %"
                  : " mV",
          "convert": (double x, int index) {
            x = _inMemoryData[index][1];
            x = x * 0.000917;
            globalSettings = Provider.of<GlobalSettingsModal>(
              context,
              listen: false,
            );
            if (globalSettings != null &&
                globalSettings.applyConversion == true) {
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

  Future<void> sendSerialCommandSequence({
    required SerialPort port,
    required void Function(String) updateResponse,
    required void Function() onComplete,
  }) async {
    // stop main stream
    if (mainDataSubscription != null) {
      await mainDataSubscription!.cancel();
      mainDataSubscription = null;
    }

    if (!port.isOpen) {
      print("❌ Port not open.");
      return;
    }

    port.flush(); // clear junk before starting

    final buffer = <int>[];
    final stopwatch = Stopwatch()..start();
    bool commandOneWritten = false;
    String firstResponse = "";

    // Begin read loop first for first command
    while (stopwatch.elapsedMilliseconds < 1500) {
      final chunk = port.read(64, timeout: 5);
      // go ahead if only the chunk dont contain BT
      if (chunk.isNotEmpty && !String.fromCharCodes(chunk).contains("BT")) {
        buffer.addAll(chunk);
        print("[READ] ${chunk.map((b) => b).join(', ')}");
        firstResponse += String.fromCharCodes(chunk);

        // Exit if response ends in \n (10)
        if (buffer.contains(10)) break;
      }

      final fullCommand = 'K 2\r\n';
      final commandBytes = Uint8List.fromList(fullCommand.codeUnits);

      print("[INFO] Preparing to send: $fullCommand");

      if (!commandOneWritten && stopwatch.elapsedMilliseconds >= 100) {
        port.write(commandBytes);
        print("[INFO] Sent: $fullCommand");
        commandOneWritten = true;
      }
    }

    print("[FINAL RESPONSE] ${buffer.map((b) => b).join(', ')}");
    updateResponse("Received: ${String.fromCharCodes(buffer)}");
    print("[ASCII] ${String.fromCharCodes(buffer)}");
    print("HERE");
    firstResponse = String.fromCharCodes(buffer);
    print("[FIRST RESPONSE] $firstResponse");
    // Check if first response matches any of the patterns
    final validPatterns = [
      RegExp(r"K\s*0002\r\n"),
      RegExp(r"K\s*2\r\n"),
      RegExp(r"\s*K\s*2\r\n"),
      RegExp(r"K\s*0002\n\r"),
      RegExp(r"K\s*0*2\s*[\r\n]+"),
      RegExp(r"\s*K\s*0*2\s*[\r\n]+"),
      RegExp(
        r"K\s*0*2\s*[\r\n]+",
      ), // Matches "K 2\r\n", "K0002\r\n", "K2\r\n", etc.
      RegExp(r"\s*K\s*0*2\s*[\r\n]+"),
      // also with only a K
      RegExp(r"K\s*[\r\n]+"),
      // work only with 2
      RegExp(r"K\s*2\s*[\r\n]+"),
      // 00002 or any number with 2
      RegExp(r"K\s*0*2\s*[\r\n]+"),
      RegExp(r"K\s*\d*\s*[\r\n]+"),
      RegExp(r"^\s*K\s*\d*\s*[\r\n]+$"),
      RegExp(r"^\s*\d+\s*([\r\n]+)?$"),
      RegExp(r"^\s*K\s*$"),
    ];
    print("HERE2");
    bool isValid = validPatterns.any((p) => p.hasMatch(firstResponse));
    print("[CHECK] First response valid: $isValid");

    // Only send second command if valid
    if (isValid) {
      final secondCommand = 'G\r\n';
      final secondCommandBytes = Uint8List.fromList(secondCommand.codeUnits);
      print("[INFO] Preparing to send: $secondCommand");
      port.write(secondCommandBytes);
      print("[INFO] Sent: $secondCommand");

      buffer.clear();
      stopwatch.reset();

      // Flip: start read loop after writing
      while (stopwatch.elapsedMilliseconds < 1500) {
        final chunk = port.read(64, timeout: 5);
        if (chunk.isNotEmpty && !String.fromCharCodes(chunk).contains("BT")) {
          buffer.addAll(chunk);
          print("[READ] ${chunk.map((b) => b).join(', ')}");
          if (buffer.contains(10)) break;
        }
      }
      print("[SECOND RESPONSE] ${buffer.map((b) => b).join(', ')}");
      updateResponse("Second Received: ${String.fromCharCodes(buffer)}");
      print("[ASCII] ${String.fromCharCodes(buffer)}");
      String secondResponse = String.fromCharCodes(
        buffer,
      ); // Capture second response
    } else {
      print("[ERROR] First response did not match expected patterns.");
      updateResponse("First response invalid, not sending second command.");
    }

    // third command
    // check second response of G\r\n
    final secondValidPatterns = [
      RegExp(r"G\s*[\r\n]+"),
      RegExp(r"G\s*0001\r\n"),
      RegExp(r"G\s*1\r\n"),
      RegExp(r"\s*G\s*1\s*[\r\n]+"),
      RegExp(r"G\s*0*1\s*[\r\n]+"),
      // the number in between could be anything
      RegExp(r"G\s*\d+\s*[\r\n]+"),
      RegExp(r"G\s*[\r\n]+"), // Matches "G\r\n", "G 1\r\n", "G 0001\r\n", etc.
      // make only for G also
      RegExp(r"G\s*[\r\n]+"),
      RegExp(r"G\s*[\r\n]+"), // Matches "G\r\n", "G 1\r\n", "G 0001\r\n", etc.
      // make one for only \r\n or \n or \r  any one of these
      RegExp(r"[\r\n]+"),
      RegExp(r"\s*[\r\n]+"), // Matches any whitespace followed by \r\n
      RegExp(r"^\s*[Gg]?\s*$"),
    ];
    bool isSecondValid = secondValidPatterns.any(
      (p) => p.hasMatch(String.fromCharCodes(buffer)),
    );
    print("[CHECK] Second response valid: $isSecondValid");

    if (isSecondValid) {
      final thirdCommand = 'K 1\r\n';
      final thirdCommandBytes = Uint8List.fromList(thirdCommand.codeUnits);
      print("[INFO] Preparing to send: $thirdCommand");
      port.write(thirdCommandBytes);
      print("[INFO] Sent: $thirdCommand");
      print("COMPLETE");
      onComplete(); // Call onComplete here to signal readiness

      // buffer.clear();
      // stopwatch.reset();

      // // Flip: start read loop after writing
      // while (stopwatch.elapsedMilliseconds < 1500) {
      //   final chunk = port.read(64, timeout: 5);
      //   if (chunk.isNotEmpty && !String.fromCharCodes(chunk).contains("BT")) {
      //     buffer.addAll(chunk);
      //     print("[READ] ${chunk.map((b) => b).join(', ')}");
      //     if (buffer.contains(10)) break;
      //   }
      //   // await Future.delayed(Duration(milliseconds: 5));
      // }
      // print("[THIRD RESPONSE] ${buffer.map((b) => b).join(', ')}");
      // updateResponse("Third Received: ${String.fromCharCodes(buffer)}");
      // print("[ASCII] ${String.fromCharCodes(buffer)}");
    } else {
      print("[ERROR] Second response did not match expected patterns.");
      updateResponse("Second response invalid, not sending third command.");
    }

    // // check third response with regex
    // final thirdValidPatterns = [
    //   RegExp(r"K\s*0001\r\n"),
    //   RegExp(r"K\s*1\r\n"),
    //   RegExp(r"\s*K\s*1\s*[\r\n]+"),
    //   RegExp(r"K\s*0*1\s*[\r\n]+"),
    //   // also with only a K
    //   RegExp(r"K\s*[\r\n]+"),
    //   // work only with 1
    //   RegExp(r"K\s*1\s*[\r\n]+"),
    //   // 00001 or any number with 1
    //   RegExp(r"K\s*0*1\s*[\r\n]+"),
    //   RegExp(r"K\s*\d*\s*[\r\n]+"),
    // ];
    // bool isThirdValid = thirdValidPatterns.any(
    //   (p) => p.hasMatch(String.fromCharCodes(buffer)),
    // );
    // print("[CHECK] Third response valid: $isThirdValid");
    // if (isThirdValid) {
    //   print("[INFO] Calibration sequence completed successfully.");
    //   updateResponse("Calibration sequence complete!");
    //   onComplete();
    // } else {
    //   print("[ERROR] Third response did not match expected patterns.");
    //   updateResponse("Third response invalid, calibration failed.");
    // }
  }

  Future<void> sendSerialCommand({
    required SerialPort port,
    required String command,
    required void Function(String) updateResponse,
  }) async {
    if (!port.isOpen) {
      print("❌ Port not open.");
      return;
    }

    port.flush(); // clear junk before starting

    final fullCommand = '$command\r\n';
    final commandBytes = Uint8List.fromList(fullCommand.codeUnits);

    final buffer = <int>[];
    final stopwatch = Stopwatch()..start();
    bool commandWritten = false;

    print("[INFO] Preparing to send: $fullCommand");

    // Begin read loop first
    while (stopwatch.elapsedMilliseconds < 1500) {
      final chunk = port.read(64, timeout: 5); // 50ms blocking read
      // print("[DEBUG] Read chunk: ${chunk}");
      if (chunk.isNotEmpty) {
        buffer.addAll(chunk);
        print("[READ] ${chunk.map((b) => b).join(', ')}");

        // Exit if response ends in \n (10)
        if (buffer.contains(10)) break;
      }

      // Send command after ~100ms or so, once reader is running
      if (!commandWritten && stopwatch.elapsedMilliseconds >= 100) {
        port.write(commandBytes);
        print("[INFO] Sent: $fullCommand");
        commandWritten = true;
      }

      // await Future.delayed(Duration(milliseconds: 10));
    }

    print("[FINAL RESPONSE] ${buffer.map((b) => b).join(', ')}");
    updateResponse("Received: ${String.fromCharCodes(buffer)}");
    print("[ASCII] ${String.fromCharCodes(buffer)}");
  }

  Future<void> sendCalibrationSequence(
    SerialPort port,
    BuildContext context, {
    void Function(String response)? onResponse,
  }) async {
    final commands = [
      Uint8List.fromList([0x4B, 0x20, 0x32, 0x0D, 0x0A]), // K 2\r\n
      Uint8List.fromList([0x47, 0x0D, 0x0A]), // G\r\n
      Uint8List.fromList([0x4B, 0x20, 0x31, 0x0D, 0x0A]), // K 1\r\n
    ];

    int step = 0;
    SerialPortReader reader = SerialPortReader(port);
    StreamSubscription? subscription;

    void sendNextCommand() {
      if (step < commands.length) {
        port.write(commands[step]);
        onResponse?.call("Sent: ${String.fromCharCodes(commands[step])}");
      } else {
        subscription?.cancel();
        port.close();
        onResponse?.call("Calibration sequence complete!");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Calibration sequence complete!")),
        );
      }
    }

    subscription = reader.stream.listen(
      (data) {
        final response = String.fromCharCodes(data);
        // while the response is not caontaining BT
        if (!response.contains("BT")) {
          onResponse?.call("Received: $response");
          if (step == 0 && RegExp(r"\s*K\s*00002\r\n").hasMatch(response)) {
            step++;
            sendNextCommand();
          } else if (step == 1 &&
              RegExp(r"\s*G\s*\d+\r\n").hasMatch(response)) {
            step++;
            sendNextCommand();
          } else if (step == 2 &&
              RegExp(r"\s*K\s*00001\r\n").hasMatch(response)) {
            step++;
            sendNextCommand();
          }
        }
      },
      onError: (e) {
        onResponse?.call("Serial error: $e");
        subscription?.cancel();
        port.close();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Calibration failed: $e")));
      },
      onDone: () {
        onResponse?.call("Serial stream done.");
        port.close();
      },
    );

    sendNextCommand();
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
            filename: "spirobt-${DateTime.now().microsecondsSinceEpoch}.bin",
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

  List<double> recentVolumes = [];
  bool wasExhaling = false;

  onExhalationDetected({data = null, isComplete = false}) {
    print("Exaust Detected");
    try {
      CPETService cpet = CPETService();
      var stats = {};
      // if (data != null) {
      //   stats = ecgBPMCalculator.getStats(data);
      // } else {
      //   stats = ecgBPMCalculator.getStats(_inMemoryData);
      // }
      // print(stats);
      final patientProvider = Provider.of<DefaultPatientModal>(
        context,
        listen: false,
      );
      final patient = patientProvider.patient;

      print("VOLPEAK");
      final globalSettings = Provider.of<GlobalSettingsModal>(
        context,
        listen: false,
      );

      if (data != null) {
        cp = cpet.init(data, globalSettings);
      } else {
        cp = cpet.init(_inMemoryData, globalSettings);
      }
      if (isComplete == true) {
        completeCp = cp;
      }
      print(cp);

      // markerlines
      if (cp != null && cp!['breathStats'] is List) {
        final peaks =
            (cp!['breathStats'] as List)
                .whereType<Map>()
                .expand<int>((e) sync* {
                  if (e['start'] is num) yield (e['start'] as num).toInt();
                  if (e['end'] is num) yield (e['end'] as num).toInt();
                })
                .toSet() // ensure uniqueness
                .toList()
              ..sort();
        breathPeakIndicesNotifier.value = peaks;
      }
      // print(cp);
      // Safely extract values with null checks
      final lastBreathStat = cp != null ? cp!["averageStats"] : null;
      setState(() {
        final respirationPerMin =
            (lastBreathStat != null &&
                    lastBreathStat["respirationRate"] != null)
                ? (lastBreathStat["respirationRate"] as num).toDouble()
                : (cp != null && cp!["respirationRate"] != null)
                ? (cp!["respirationRate"] as num).toDouble()
                : 0.0;

        // VO2 per minute (prefer precomputed field if present)
        double vo2PerBreath =
            (lastBreathStat != null && lastBreathStat["vo2"] != null)
                ? (lastBreathStat["vo2"] as num).toDouble()
                : 0.0;
        double vo2MinuteStat =
            (lastBreathStat != null && lastBreathStat["vo2Minute"] != null)
                ? (lastBreathStat["vo2Minute"] as num).toDouble()
                : (respirationPerMin > 0
                    ? vo2PerBreath * respirationPerMin
                    : 0.0);

        double vco2PerBreath =
            (lastBreathStat != null && lastBreathStat["vco2"] != null)
                ? (lastBreathStat["vco2"] as num).toDouble()
                : 0.0;
        double vco2MinuteStat =
            (lastBreathStat != null && lastBreathStat["vco2Minute"] != null)
                ? (lastBreathStat["vco2Minute"] as num).toDouble()
                : (respirationPerMin > 0
                    ? vco2PerBreath * respirationPerMin
                    : 0.0);

        votwo = vo2MinuteStat; // store as L/min
        vco = vco2MinuteStat; // NOW VCO2 per minute (L/min)

        rer =
            (lastBreathStat != null && lastBreathStat["rer"] != null)
                ? lastBreathStat["rer"]
                : 0.0;
        vol =
            (cp != null && cp!["minuteVentilation"] != null)
                ? cp!["minuteVentilation"]
                : 0.0;
        respirationRate =
            (cp != null && cp!["respirationRate"] != null)
                ? cp!["respirationRate"]
                : 0.0;
        bpm = (stats != null && stats["bpm"] != null) ? stats["bpm"] : 0.0;
        final defaultProvider = Provider.of<DefaultPatientModal>(
          context,
          listen: false,
        );
        final patient = defaultProvider.patient;
        if (patient != null && patient["weight"] != null && votwo != null) {
          double? weight = double.tryParse(patient["weight"].toString());
          if (weight != null && weight > 0) {
            votwokg = (votwo * 1000) / weight;
          } else {
            votwokg = 0.0;
          }
        } else {
          votwokg = 0.0;
        }
      });
      if (cp != null && cp!['breathStats'] != null) {
        fullCp = Map<String, dynamic>.from(cp!); // stores full cp object
        final updatedBreathStats = List<Map<String, dynamic>>.from(
          cp!['breathStats'],
        );
        breathStatsNotifier.value = updatedBreathStats;
        if (modalSetState != null) {
          modalSetState!(() {}); // manually update modal table
        }
      }

      print("update");
    } catch (e) {
      print(e);
    }
  }

  void startTestLoop() async {
    testData = await loadTestData();
    dataIndex = 0;

    final o2DelayMs = globalSettings.transportDelayO2Ms;
    final co2DelayMs = globalSettings.transportDelayCO2Ms;
    final o2DelaySamples = (o2DelayMs * 300 / 1000).round();
    final co2DelaySamples = (co2DelayMs * 300 / 1000).round();

    List<List<double>> delayBuffer = [];
    recentVolumes.clear();
    bool wasExhaling = false;

    Timer.periodic(Duration(milliseconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      while (dataIndex + 16 < testData.length) {
        int byte0 = testData[dataIndex].toInt() & 0xFF;
        int byte1 = testData[dataIndex + 1].toInt() & 0xFF;

        if (byte0 == 'B'.codeUnitAt(0) && byte1 == 'T'.codeUnitAt(0)) {
          List<int> data = List.generate(16, (i) {
            return testData[dataIndex + i].toInt() & 0xFF;
          });

          double ecg = (data[3] << 8 | data[2]) * 1.0;
          double o2 = (data[7] << 8 | data[6]) * 1.0;
          double co2 = (data[15] << 8 | data[14]) * 1.0;
          double flow = (data[11] << 8 | data[10]) * 1.0;
          double vol = (data[13] << 8 | data[12]) * 1.0;
          vol = (vol * globalSettings.tidalScalingFactor);

          recentVolumes.add(vol);
          if (recentVolumes.length > 10) recentVolumes.removeAt(0);

          int nonZeroCount = recentVolumes.where((v) => v > 50).length;
          bool currentIsZero = vol <= 5;

          if (nonZeroCount >= 5 && currentIsZero && wasExhaling) {
            onExhalationDetected();
            wasExhaling = false;
          }
          if (vol > 50) wasExhaling = true;

          delayBuffer.add([ecg, o2, co2, flow, vol]);
          if (delayBuffer.length > max(o2DelaySamples, co2DelaySamples)) {
            final current = delayBuffer[0];
            final delayedO2 =
                delayBuffer.length > o2DelaySamples
                    ? delayBuffer[o2DelaySamples][1]
                    : current[1];
            final delayedCO2 =
                delayBuffer.length > co2DelaySamples
                    ? delayBuffer[co2DelaySamples][2]
                    : current[2];

            final correctedSample = [
              current[0], // ECG
              delayedO2, // O2 (delayed)
              delayedCO2, // CO2 (delayed)
              current[3], // Flow
              current[4], // Vol
            ];

            saver(
              ecg: correctedSample[0],
              o2: correctedSample[1],
              flow: correctedSample[3],
              vol: correctedSample[4],
              co2: correctedSample[2],
            );

            List<double>? edt = myBigGraphKey.currentState?.updateEverything(
              correctedSample,
            );
            if (edt != null) {
              _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], edt[4]]);
            }

            delayBuffer.removeAt(0);
          }

          dataIndex += 16;
          return;
        }
        dataIndex += 1;
      }
      dataIndex = 0;
    });
  }

  init() {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );

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
    SerialPortReader reader = SerialPortReader(port);
    // Variables you should declare globally at top of your class:
    double ecgMax = -double.infinity;
    double ecgMin = double.infinity;
    double o2Max = -double.infinity;
    double o2Min = double.infinity;
    double flowMax = -double.infinity;
    double flowMin = double.infinity;
    double co2Max = -double.infinity;
    double co2Min = double.infinity;

    startMainDataStream(port); // Start the main data stream
  }

  int lastNotifierUpdate = DateTime.now().millisecondsSinceEpoch;

  void startMainDataStream(SerialPort port) {
    if (mainDataSubscription != null) {
      mainDataSubscription?.cancel();
    }

    final o2DelayMs = globalSettings.transportDelayO2Ms;
    final co2DelayMs = globalSettings.transportDelayCO2Ms;
    final o2DelaySamples = (o2DelayMs * 300 / 1000).round();
    final co2DelaySamples = (co2DelayMs * 300 / 1000).round();

    List<List<double>> delayBuffer = [];
    recentVolumes.clear();
    bool wasExhaling = false;

    SerialPortReader reader = SerialPortReader(port);
    mainDataSubscription = reader.stream.listen(
      (data) {
        int frameLength = 18;
        for (int i = 0; i <= data.length - frameLength;) {
          if (data[i] == 'B'.codeUnitAt(0) &&
              data[i + 1] == 'T'.codeUnitAt(0)) {
            if (i + frameLength <= data.length) {
              final frame = data.sublist(i, i + frameLength);

              double ecg = (frame[3] * 256 + frame[2]) * 1.0;
              double o2 = (frame[7] * 256 + frame[6]) * 1.0;
              double co2 = (frame[15] * 256 + frame[14]) * 1.0;
              double flow = (frame[11] * 256 + frame[10]) * 1.0;
              double vol = (frame[13] * 256 + frame[12]) * 1.0;
              vol = (vol * globalSettings.tidalScalingFactor);

              recentVolumes.add(vol);
              if (recentVolumes.length > 10) recentVolumes.removeAt(0);

              int nonZeroCount = recentVolumes.where((v) => v > 50).length;
              bool currentIsZero = vol <= 5;

              if (nonZeroCount >= 5 && currentIsZero && wasExhaling) {
                onExhalationDetected();
                wasExhaling = false;
              }
              if (vol > 50) wasExhaling = true;

              delayBuffer.add([ecg, o2, co2, flow, vol]);
              if (delayBuffer.length > max(o2DelaySamples, co2DelaySamples)) {
                final current = delayBuffer[0];
                var delayedO2 =
                    delayBuffer.length > o2DelaySamples
                        ? delayBuffer[o2DelaySamples][1]
                        : current[1];
                var delayedCO2 =
                    delayBuffer.length > co2DelaySamples
                        ? delayBuffer[co2DelaySamples][2]
                        : current[2];

                // if (vol == 0) {
                //   delayedO2 = 1212; // ambient O2 %
                //   delayedCO2 = 30; // ambient CO2 %
                // }

                var correctedSample = [
                  current[0], // ECG
                  delayedO2, // O2 (delayed)
                  delayedCO2, // CO2 (delayed)
                  current[3], // Flow
                  current[4], // Vol
                ];

                saver(
                  ecg: correctedSample[0],
                  o2: correctedSample[1],
                  flow: correctedSample[3],
                  vol: correctedSample[4],
                  co2: correctedSample[2],
                );

                List<double>? edt = myBigGraphKey.currentState
                    ?.updateEverything(correctedSample);
                if (edt != null) {
                  _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], edt[4]]);
                  setState(() {
                    co2Notifier.value = edt[2];
                    o2Notifier.value = edt[1];
                    tidalVolumeNotifier.value = edt[4];
                  });
                }

                delayBuffer.removeAt(0);
              }
              i += frameLength;
              continue;
            } else {
              break;
            }
          } else {
            i++;
          }
        }
      },
      onDone: () {
        print("Serial Done");
      },
      onError: (e) {
        print("❌ Serial port error: $e");
      },
    );
  }

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

  playPause() {
    if (isPlaying) {
      return IconButton(
        onPressed: () {
          final globalSettings = Provider.of<GlobalSettingsModal>(
            context,
            listen: false,
          );
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

  void showBreathStatsTableModal(
    BuildContext context,
    Map<String, dynamic> cp,
  ) {
    final liveData = breathStatsNotifier.value?.reversed.toList() ?? [];
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => BreathStatsTableModal(
            breathStats: liveData,
            onDownload: () async {
              if (liveData.isNotEmpty) {
                await Utility().exportBreathStatsToExcel({
                  'breathStats': liveData,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Excel downloaded successfully!')),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('No data to export')));
              }
            },
            onClose: () => Navigator.pop(context),
          ),
    );
  }

  _vitals({defaultPatient = null}) {
    List<double> volumes = [];
    List<double> vo2List = [];

    List<double> volx = [];
    // vco2
    List<double> vco2YList = [];

    List<double> rerList = [];
    List<double> rerX = [];
    if (cp != null && cp!['breathStats'] is List) {
      volumes =
          (cp!['breathStats'] as List)
              .map((e) => (e['vol'] as num?)?.toDouble() ?? 0.0)
              .toList();
      // print("volumes");
      volx = List.generate(volumes.length, (index) => index.toDouble());

      //    vo2
      vo2List =
          (cp!['breathStats'] as List)
              .map((e) => (e['vo2'] as num?)?.toDouble() ?? 0.0)
              .toList();

      //vco2

      vco2YList =
          (cp!['breathStats'] as List)
              .map((e) => (e['vco2'] as num?)?.toDouble() ?? 0.0)
              .toList();

      // rer
      rerList =
          (cp!['breathStats'] as List)
              .map((e) => (e['rer'] as num?)?.toDouble() ?? 0.0)
              .toList();
      rerX = List.generate(rerList.length, (index) => index.toDouble());
    }

    //
    // List<double> list = [yAxisValue ?? 0.0];

    return (Column(
      children: [
        // if (importProgressPercent > 0)
        //   LinearProgressIndicator(
        //     value: importProgressPercent,
        //     backgroundColor: Colors.grey[300],
        //     color: Colors.blue,
        //   ),
        Text(
          defaultPatient != null
              ? 'Patient: ' + defaultPatient['name']
              : 'No Patient',
          style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold),
        ),
        if (isImported == true) _nextPreviousButtons(),

        recordingIndicator(),

        if (isImported == false) protocolDisplay(),

        Row(
          children: [
            VitalsBox(
              label: "VO2",
              value: votwo.toStringAsFixed(2),
              unit: "L/min",
              color: Colors.blue,
            ),
            VitalsBox(
              label: "VCO2",
              value: vco.toStringAsFixed(2),
              unit: "L/min",
              color: Colors.red,
            ),
          ],
        ),
        Row(
          children: [
            VitalsBox(
              label: "RER",
              value: rer!.toStringAsFixed(2),
              unit: " ",
              color: Colors.blue,
            ),
            VitalsBox(
              label: "VE",
              value: vol != null ? vol!.toStringAsFixed(2) : "0.00",
              unit: "L/Min",
              color: Colors.blue,
            ),
          ],
        ),
        Row(
          children: [
            VitalsBox(
              label: "VO2/KG",
              value: votwokg!.toStringAsFixed(2),
              unit: "ml/min/kg",
              color: Colors.blue,
            ),
            VitalsBox(
              label: "HR",
              value: bpm!.toStringAsFixed(0),
              unit: " ",
              color: Colors.blue,
            ),
          ],
        ),
        Row(
          children: [
            VitalsBox(
              label: "RR",
              value:
                  respirationRate != null
                      ? respirationRate!.toStringAsFixed(0)
                      : "0",
              unit: "/Min",
              color: Colors.blue,
            ),
          ],
        ),
      ],
    ));
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
      onExhalationDetected(isComplete: true);
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

    List<List<double>> samples = [];
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
    onExhalationDetected(data: chunkData);
    // return samples;
  }

  _nextPreviousButtons() {
    print("isImported");
    print(isImported);
    if (isImported == true) {
      print("__inMemoryDataLLL");
      print(_inMemoryData.length);
      // Show next/previous buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              // Handle previous button (move back by one 20s window)
              setState(() {
                currentImportDisplayIndex = (currentImportDisplayIndex - 6000)
                    .clamp(0, double.infinity);
              });
              await getSamplesFromFile(currentImportDisplayIndex.toInt());
              myBigGraphKey.currentState?.cycleMinus();
              myBigGraphKey.currentState?.cycleMinus();
            },
          ),
          // show the point where we are in time
          Text(
            "${((currentImportDisplayIndex ~/ 6000) ~/ 3).toString().padLeft(2, '0')}:${((currentImportDisplayIndex ~/ 6000) * 20 % 60).toString().padLeft(2, '0')} / "
            "${_inMemoryData.isNotEmpty ? (() {
                  final totalWindows = (_inMemoryData.length / 6000).ceil();
                  final totalSeconds = totalWindows * 20;
                  final min = (totalSeconds ~/ 60).toString().padLeft(2, '0');
                  final sec = (totalSeconds % 60).toString().padLeft(2, '0');
                  return "$min:$sec";
                })() : "00:00"}",
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(width: 20),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: () {
              setState(() {
                // Clamp to not go above the available data length
                final maxIndex = ((_inMemoryData.length - 1) ~/ 6000) * 6000;
                currentImportDisplayIndex =
                    ((currentImportDisplayIndex + 6000).clamp(
                      0,
                      maxIndex,
                    )).toDouble();
              });
              print("Current Import Display Index: $currentImportDisplayIndex");
              getSamplesFromFile(currentImportDisplayIndex.toInt());
              // Handle next button press
            },
          ),
        ],
      );
    }
    return Container();
  }

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final importProvider = Provider.of<ImportFileProvider>(context);
    if (importProvider.filePath != null) {
      resetAllData(import: true); // Reset data on every dependency change
      importBinFileFromPath(importProvider.filePath!);
      // Schedule clear after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        importProvider.clear();
      });
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
    final lengthBytes = fullBytes.sublist(0, 4);

    // ✅ Get documents directory
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final String recordingsPath = p.join(docsDir.path, 'SpiroBT', 'Records');
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
      recentVolumes.clear();
      rawDataFull.clear();
      _inMemoryData.clear();
      breathStatsNotifier.value = [];

      // Reset graph widget
      myBigGraphKey.currentState?.reset();

      // Reset flags
      wasExhaling = false;
      isImported = import;

      importProgressPercent = 0.0;
      currentImportDisplayIndex = 0;
    });
  }

  calibratorModel() {
    final context = myBigGraphKey.currentContext ?? this.context;

    showDialog(
      context: context,
      builder: (context) {
        String responseText = "";
        bool isSending = false;
        String status = "p";

        return DefaultTabController(
          length: 3,
          child: AlertDialog(
            title: TabBar(
              tabs: [
                Tab(text: "CO2 Calibration"),
                Tab(text: "O2 Calibration"),
                Tab(text: "Tidal Volume Calibration"),
              ],
              labelColor: Colors.black,
            ),
            content: SizedBox(
              width: 200,
              child: TabBarView(
                children: [
                  // Tab 1: CO2 Calibration (your existing logic)
                  _co2CalibratorTab(), // <-- replaced inline CO2 tab
                  // Tab 2: O2 Calibration (placeholder)
                  _o2CalibratorTab(),
                  // Tab 3: Tidal Flow Calibration (placeholder)
                  tidalFlowCalibrationWidget(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _co2CalibratorTab() {
    final transportDelayCO2Controller = TextEditingController();

    return Consumer<GlobalSettingsModal>(
      builder: (context, globalSettings, child) {
        transportDelayCO2Controller.text =
            globalSettings.transportDelayCO2Ms.toString();

        String status = "p";
        bool isSending = false;
        String responseText = "";

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _saveDelay() async {
              final parsed = int.tryParse(transportDelayCO2Controller.text);
              if (parsed != null && parsed >= 0) {
                globalSettings.setTransportDelayCO2Ms(parsed);
                globalSettings.notifyListeners();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                  "globalSettings",
                  globalSettings.toJson(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("CO₂ transport delay saved"),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Invalid delay value"),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }

            Future<void> _runCalibration() async {
              setState(() {
                status = "running";
                isSending = true;
              });
              await sendSerialCommandSequence(
                port: port,
                updateResponse: (resp) {
                  setState(() {
                    responseText += resp + "\n";
                  });
                },
                onComplete: () {
                  setState(() {
                    isSending = false;
                    status = "completed";
                  });
                  startMainDataStream(port);
                },
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Text(
                  "CO2 Calibration",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (status == "running") const LinearProgressIndicator(),
                if (status == "completed")
                  const Icon(Icons.check, color: Colors.green),

                // Smoothed current CO₂ display
                CurrentCo2Display(
                  notifier: co2Notifier,
                  windowSize: 20,
                  divisor: 100, // raw /100 => %
                ),

                const SizedBox(height: 8),
                const Text(
                  "Please keep the gas pipe in ambient air for calibration.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // CO₂ Transport Delay Input
                Row(
                  children: [
                    const SizedBox(
                      width: 140,
                      child: Text(
                        "CO₂ Transport Delay (ms)",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: transportDelayCO2Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        // Only edit local text; saving happens via button
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row with independent buttons
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _saveDelay,
                      child: const Text("Save Delay"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSending ? null : _runCalibration,
                      child: const Text("Calibrate Sensor"),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Exit"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // (Optional) response log (hidden if empty)
                if (responseText.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        responseText,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget tidalFlowCalibrationWidget(BuildContext context) {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );

    // Use controllers that persist across rebuilds
    final measuredController = TextEditingController(
      text: globalSettings.tidalMeasuredReference.toString(),
    );
    final actualController = TextEditingController(
      text: globalSettings.tidalActualReference.toString(),
    );

    double localMeasured = globalSettings.tidalMeasuredReference;
    double localActual = globalSettings.tidalActualReference;
    double localScaling =
        localMeasured != 0 ? localActual / localMeasured : 1.0;

    return StatefulBuilder(
      builder: (context, setState) {
        void recalculateScaling() {
          final measured = double.tryParse(measuredController.text) ?? 0.0;
          final actual = double.tryParse(actualController.text) ?? 0.0;
          setState(() {
            localMeasured = measured;
            localActual = actual;
            localScaling = measured != 0 ? actual / measured : 1.0;
          });
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            Text(
              "Tidal Volume Calibration",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ValueListenableBuilder<double>(
              valueListenable: tidalVolumeNotifier,
              builder: (context, value, child) {
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade700, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade100.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: Colors.green.shade700,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Current Tidal Volume",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            "${value.toStringAsFixed(2)} ml",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 8),
            TextField(
              controller: measuredController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Measured volume",
                hintText: "Enter measured value",
              ),
              onChanged: (val) => recalculateScaling(),
            ),
            SizedBox(height: 12),
            TextField(
              controller: actualController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Known Volume",
                hintText: "Enter actual value (Eg: 3000)",
              ),
              onChanged: (val) => recalculateScaling(),
            ),
            SizedBox(height: 12),
            Text(
              "Error Factor: ${localScaling.toStringAsFixed(4)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Save and close
                    globalSettings.setTidalMeasuredReference(localMeasured);
                    globalSettings.setTidalActualReference(localActual);
                    globalSettings.setTidalScalingFactor(localScaling);
                    Navigator.of(context).pop();
                  },
                  child: Text("Submit"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Exit"),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  _o2CalibratorTab() {
    final voltage1Controller = TextEditingController();
    final value1Controller = TextEditingController();
    final voltage2Controller = TextEditingController();
    final value2Controller = TextEditingController();
    final transportDelayO2Controller = TextEditingController(); // NEW

    return Consumer<GlobalSettingsModal>(
      builder: (context, globalSettings, child) {
        // Prefill controllers from settings
        voltage1Controller.text = globalSettings.voltage1.toString();
        value1Controller.text = globalSettings.value1.toString();
        voltage2Controller.text = globalSettings.voltage2.toString();
        value2Controller.text = globalSettings.value2.toString();
        if (transportDelayO2Controller.text.isEmpty) {
          transportDelayO2Controller.text =
              globalSettings.transportDelayO2Ms.toString();
        } // NEW

        double localVoltage1 = globalSettings.voltage1;
        double localValue1 = globalSettings.value1;
        double localVoltage2 = globalSettings.voltage2;
        double localValue2 = globalSettings.value2;
        bool localApplyConversion = globalSettings.applyConversion;
        int localTransportDelay = globalSettings.transportDelayO2Ms; // NEW

        return StatefulBuilder(
          builder: (context, setState) {
            Widget fieldRow({
              required String label,
              required TextEditingController controller,
              required VoidCallback? onPick,
            }) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(label, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onChanged: (val) {
                          double? v = double.tryParse(val);
                          if (v != null) {
                            setState(() {
                              if (label == 'Voltage 1') localVoltage1 = v;
                              if (label == 'Value 1') localValue1 = v;
                              if (label == 'Voltage 2') localVoltage2 = v;
                              if (label == 'Value 2') localValue2 = v;
                            });
                          }
                        },
                      ),
                    ),
                    if (onPick != null)
                      IconButton(
                        icon: const Icon(Icons.input, color: Colors.blue),
                        tooltip: "Pick current O₂",
                        onPressed: onPick,
                      ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "O2 Sensor Calibration",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CurrentO2Display(
                      notifier: o2Notifier,
                      windowSize: 20,
                      calibrate: o2Calibrate,
                      applyConversionOverride: globalSettings.applyConversion,
                    ),
                    const SizedBox(height: 12),

                    // NEW: Transport Delay Input
                    Row(
                      children: [
                        const SizedBox(
                          width: 90,
                          child: Text(
                            "O₂ Transport Delay(ms)",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: transportDelayO2Controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            onChanged: (val) {
                              int value = int.tryParse(val) ?? 0;
                              globalSettings.setTransportDelayO2Ms(value);
                              setState(() {
                                localTransportDelay = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    fieldRow(
                      label: 'Voltage 1',
                      controller: voltage1Controller,
                      onPick: () {
                        double currentO2Volts = o2Notifier.value * 0.000917;
                        voltage1Controller.text = currentO2Volts
                            .toStringAsFixed(4);
                        setState(() {
                          localVoltage1 = currentO2Volts;
                        });
                      },
                    ),
                    fieldRow(
                      label: 'Value 1',
                      controller: value1Controller,
                      onPick: null,
                    ),
                    fieldRow(
                      label: 'Voltage 2',
                      controller: voltage2Controller,
                      onPick: () {
                        double currentO2Volts = o2Notifier.value * 0.000917;
                        voltage2Controller.text = currentO2Volts
                            .toStringAsFixed(4);
                        setState(() {
                          localVoltage2 = currentO2Volts;
                        });
                      },
                    ),
                    fieldRow(
                      label: 'Value 2',
                      controller: value2Controller,
                      onPick: null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Text(
                          "Apply Conversion",
                          style: TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: localApplyConversion,
                          onChanged: (val) {
                            setState(() {
                              localApplyConversion = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            globalSettings.voltage1 = localVoltage1;
                            globalSettings.value1 = localValue1;
                            globalSettings.voltage2 = localVoltage2;
                            globalSettings.value2 = localValue2;
                            globalSettings.setapplyConversion(
                              localApplyConversion,
                            );
                            // Ensure transport delay persisted (in case user didn't trigger onChanged)
                            globalSettings.setTransportDelayO2Ms(
                              localTransportDelay,
                            );
                            globalSettings.notifyListeners();

                            o2Calibrate = generateCalibrationFunction(
                              voltage1: globalSettings.voltage1,
                              value1: globalSettings.value1,
                              voltage2: globalSettings.voltage2,
                              value2: globalSettings.value2,
                            );

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              "globalSettings",
                              globalSettings.toJson(),
                            );
                          },
                          child: const Text("Submit"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text("Exit"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  int? lastPhaseIndex;
  String? lastPhaseName;

  Widget protocolDisplay() {
    return Consumer<GlobalSettingsModal>(
      builder: (context, globalSettings, child) {
        final protocol = ProtocolManifest().getSelectedProtocol(globalSettings);
        if (protocol == null) {
          return Text("No protocol selected");
        }

        // Calculate current phase based on recordingDuration
        String phaseName = "Unknown";
        int phaseIndex = -1;
        Duration elapsed = recordingDuration;

        // For display
        String? loadOrSpeedLabel;
        String? loadOrSpeedValue;

        // Track phase markers: [{name, length}]
        if (protocol['phases'] is List) {
          int secondsPassed = elapsed.inSeconds;
          int cumulative = 0;
          for (int i = 0; i < protocol['phases'].length; i++) {
            final phase = protocol['phases'][i];
            int phaseDuration = (phase['duration'] ?? 0) as int;
            if (secondsPassed < cumulative + phaseDuration) {
              phaseName = phase['name'] ?? "Phase ${i + 1}";
              phaseIndex = i;

              // --- NEW: Display load or speed ---
              if (protocol['type'] == "ergoCycle") {
                if (phase.containsKey('load')) {
                  if (phase['load'] is String && phase['load'] == "ramp") {
                    loadOrSpeedLabel = "Load";
                    loadOrSpeedValue = "Ramp";
                    // Optionally, calculate ramp value here if you have logic
                    if (phase.containsKey('rampStart') &&
                        phase.containsKey('rampEnd') &&
                        phase.containsKey('duration')) {
                      int rampStart = phase['rampStart'] ?? 0;
                      int rampEnd = phase['rampEnd'] ?? 0;
                      int rampDuration = phase['duration'] ?? 1;
                      int secondsIntoPhase = secondsPassed - cumulative;
                      double rampValue =
                          rampStart +
                          ((rampEnd - rampStart) *
                              (secondsIntoPhase / rampDuration));
                      loadOrSpeedValue =
                          "Ramp: ${rampValue.toStringAsFixed(1)} W";
                    }
                  } else {
                    loadOrSpeedLabel = "Load";
                    loadOrSpeedValue = "${phase['load']} W";
                  }
                }
              } else if (protocol['type'] == "treadmill") {
                if (phase.containsKey('speed')) {
                  loadOrSpeedLabel = "Speed";
                  loadOrSpeedValue = "${phase['speed']} km/h";
                }
                // Optionally, also show incline
                if (phase.containsKey('incline')) {
                  loadOrSpeedValue =
                      "${phase['speed']} km/h, Incline: ${phase['incline']}%";
                }
              }

              // If phase changed, update the previous marker's length
              if (lastPhaseIndex != null && lastPhaseIndex != phaseIndex) {
                final lastIndex = markers.lastIndexWhere(
                  (m) =>
                      m["type"] == "protocol_phase" &&
                      m["name"] == lastPhaseName,
                );
                if (lastIndex != -1) {
                  markers[lastIndex]["length"] = sampleCounter;
                }
              }

              // If this phase marker doesn't exist, add it
              final markerIndex = markers.lastIndexWhere(
                (m) =>
                    m["type"] == "protocol_phase" && m["name"] == phase["id"],
              );
              if (markerIndex == -1) {
                markers.add({
                  "name": phase["id"],
                  "length": 0, // Will be updated when phase ends
                  "type": "protocol_phase",
                });

                // --- SEND TREADMILL COMMAND ON PHASE START ---
                if (protocol['type'] == "treadmill" &&
                    protocol.containsKey('commands') &&
                    treadmillController?.isOpen == true) {
                  final cmdBytes = protocol['commands'][phase["id"]];
                  if (cmdBytes != null) {
                    treadmillController!.sendCommand(List<int>.from(cmdBytes));
                  }
                }
              }

              lastPhaseIndex = phaseIndex;
              lastPhaseName = phase["id"];
              break;
            }
            cumulative += phaseDuration;
          }
          if (phaseIndex == -1 && protocol['phases'].isNotEmpty) {
            phaseName = "Completed";
            // Update the last marker's length to the final sampleCounter
            if (lastPhaseIndex != null) {
              final lastIndex = markers.lastIndexWhere(
                (m) =>
                    m["type"] == "protocol_phase" && m["name"] == lastPhaseName,
              );
              if (lastIndex != -1) {
                markers[lastIndex]["length"] = sampleCounter;
              }
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isRecording) _stopRecording();
            });
          }
        }

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 8),
                        Text(
                          "${protocol['name']}",
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Phase: $phaseName",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (loadOrSpeedLabel != null &&
                            loadOrSpeedValue != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "$loadOrSpeedLabel: $loadOrSpeedValue",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
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
        final defaultPatient = defaultProvider.patient;
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
                              final globalSettings =
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
                          icon: Icons.table_chart,
                          label: "Data Mode",
                          onPressed: () {
                            if (cp != null) {
                              showBreathStatsTableModal(context, cp!);
                            }
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
                        // clabirations
                        IconButtonColumn(
                          icon: Icons.compass_calibration_outlined,
                          label: "Calibrate",
                          onPressed: () {
                            calibratorModel();
                            // Navigator.of(context).push(
                            //   MaterialPageRoute(
                            //     builder: (context) => CalibrationPage(),
                            //   ),
                            // );
                          },
                        ),
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
                            // Close the app
                            SystemNavigator.pop();
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
                        // markerIndices: breathPeakIndicesNotifier, // <-- NEW
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
                    _vitals(defaultPatient: defaultPatient),
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
