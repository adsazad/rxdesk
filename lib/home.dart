import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:spirobtvo/Widgets/MyBigGraphScrollable.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

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
  final dataSaver = DataSaver();

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
  @override
  void initState() {
    super.initState();
    initFunc();

    startTestLoop();
    // init();
    // CPETService cpet = CPETService();
    // timer = Timer.periodic(Duration(seconds: 10), (timer) {
    //
    // });
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
      if (!dataSaver.initialized) {
        print("✅ Initializing DataSaver...");
        await dataSaver.init(
          filename: "spirobt-${DateTime.now().microsecondsSinceEpoch}.bin",
          patientInfo: patient,
        );
        _saverInitialized = true; // ✅ Set this *after* init completes
        sampleCounter = 0;
      }
    }

    _buffer.addAll([ecg, o2, co2, vol, flow]);
    sampleCounter++;
    bufSampleCounter++;

    if (bufSampleCounter >= _samplesPerBatch) {
      print("Batch of ${_buffer.length ~/ 5} samples ready to save.");
      await dataSaver.appendBatch(_buffer);
      _buffer.clear();
      bufSampleCounter = 0; // Reset buffer sample counter
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

  onExhalationDetected() {
    print("Exaust Detected");
    try {
      CPETService cpet = CPETService();

      var stats = ecgBPMCalculator.getStats(_inMemoryData);
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

      cp = cpet.init(_inMemoryData, globalSettings);
      print(cp);
      // print(cp);
      setState(() {
        votwo = cp!["lastBreathStat"]["vo2"];
        vco = cp!["lastBreathStat"]["vco2"];
        rer = cp!["lastBreathStat"]["rer"];
        vol = cp!["minuteVentilation"];
        respirationRate = cp!["respirationRate"];
        bpm = stats["bpm"];
        if (patient != null) {
          double weight = double.parse(patient["weight"]);
          votwokg = votwo / weight;
        }
      });
      if (cp != null && cp!['breathStats'] != null) {
        fullCp = Map<String, dynamic>.from(cp!); // stores full cp object
        final updatedBreathStats = List<Map<String, dynamic>>.from(
          cp!['breathStats'],
        );
        breathStatsNotifier.value = updatedBreathStats;
        if (modalSetState != null)
          modalSetState!(() {}); // manually update modal table
      }

      print("update");
    } catch (e) {
      print(e);
    }
  }

  void startTestLoop() async {
    testData = await loadTestData(); // List<double> representing bytes (0-255)
    dataIndex = 0;

    Timer.periodic(Duration(milliseconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Continuously look for header 'B' 'T'
      while (dataIndex + 16 < testData.length) {
        // Interpret values as bytes
        int byte0 = testData[dataIndex].toInt() & 0xFF;
        int byte1 = testData[dataIndex + 1].toInt() & 0xFF;

        // Check header
        if (byte0 == 'B'.codeUnitAt(0) && byte1 == 'T'.codeUnitAt(0)) {
          // Found packet header, extract next 16 bytes
          List<int> data = List.generate(16, (i) {
            return testData[dataIndex + i].toInt() & 0xFF;
          });

          double vol = (data[13] << 8 | data[12]) * 1.0;

          // Update buffer
          recentVolumes.add(vol);
          if (recentVolumes.length > 10) {
            recentVolumes.removeAt(0);
          }

          // Check for exhalation pattern
          int nonZeroCount = recentVolumes.where((v) => v > 50).length;
          bool currentIsZero = vol <= 5;

          if (nonZeroCount >= 5 && currentIsZero && wasExhaling) {
            onExhalationDetected(); // ✅ Call your function here
            wasExhaling = false; // Reset flag
          }

          if (vol > 50) {
            wasExhaling = true;
          }

          // Extract values
          double ecg = (data[3] << 8 | data[2]) * 1.0;
          double o2 = (data[7] << 8 | data[6]) * 1.0;
          double flow = (data[11] << 8 | data[10]) * 1.0;
          // double vol = (data[13] << 8 | data[12]) * 1.0;
          double co2 = (data[15] << 8 | data[14]) * 1.0;

          saver(ecg: ecg, o2: o2, flow: flow, vol: vol, co2: co2);
          // Update your graph
          // ➕ Step 1: Add incoming raw data to buffer
          delayBuffer.add([ecg, o2, co2, vol, flow]);

          // 🧹 Step 2: Prevent memory leak by limiting buffer
          int bufferSizeLimit = ((delaySamples ?? 0) + 1) * 2;
          if (delayBuffer.length > bufferSizeLimit) {
            delayBuffer.removeAt(0);
          }

          // 🛑 Step 3: If delaySamples not available, plot raw data
          if (delaySamples == null || delayBuffer.length <= delaySamples!) {
            // Optional: Plot raw data until delay is known
            List<double>? edt = myBigGraphKey.currentState?.updateEverything([
              ecg,
              o2,
              co2,
              flow,
              vol,
            ]);
            if (edt != null) {
              _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], flow]);
            }
            return;
          }

          // ✅ Step 4: Build delay-corrected values
          var current = delayBuffer[0]; // time t
          var future = delayBuffer[delaySamples!]; // time t + delay

          double correctedECG = current[0]; // live
          double correctedVOL = current[3]; // live
          double correctedFLOW = current[4]; // live
          double correctedO2 = future[1]; // future O2
          double correctedCO2 = future[2]; // future CO2

          // 🧼 Step 5: Remove used sample
          delayBuffer.removeAt(0);

          // ✅ Step 6: Plot delay-corrected values
          List<double>? edt = myBigGraphKey.currentState?.updateEverything([
            correctedECG,
            correctedO2,
            correctedCO2,
            correctedFLOW,
            correctedVOL,
          ]);

          // ✅ Step 7: Store to memory
          if (edt != null) {
            _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], correctedFLOW]);
          }

          dataIndex += 16; // move to next potential packet
          return;
        }

        dataIndex += 1; // shift by one to search for next header
      }

      // Restart if we reached end
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
      config.rts = 1;
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

    // upcommingData.listen((data){
    //   print(data);
    // });

    // 42 54 67 05 00 00 67 05 00 00 14 dc f0 00 00 00 00 00
    // Listen to incoming data
    // reader.stream.listen(
    //   (data) {
    //     final hexString = data
    //         .map((b) => b.toRadixString(16).padLeft(2, '0'))
    //         .join(' ');
    //     if (data[0] == 'B'.codeUnitAt(0) && data[1] == 'T'.codeUnitAt(0)) {
    //       double vol = (data[13] << 8 | data[12]) * 1.0;

    //       // Update buffer
    //       recentVolumes.add(vol);
    //       if (recentVolumes.length > 10) {
    //         recentVolumes.removeAt(0);
    //       }

    //       // Check for exhalation pattern
    //       int nonZeroCount = recentVolumes.where((v) => v > 50).length;
    //       bool currentIsZero = vol <= 5;

    //       if (nonZeroCount >= 5 && currentIsZero && wasExhaling) {
    //         onExhalationDetected(); // ✅ Call your function here
    //         wasExhaling = false; // Reset flag
    //       }

    //       if (vol > 50) {
    //         wasExhaling = true;
    //       }

    //       double ecg =
    //           (data[3] * 256 + data[2]) *
    //           1.0; // ECG: ecg2 (MSB, byte 3) + ecg1 (LSB, byte 2)
    //       double o2 =
    //           (data[7] * 256 + data[6]) *
    //           1.0; // O2:  O2_2 (MSB, byte 7) + O2_1 (LSB, byte 6)
    //       double flow =
    //           (data[11] * 256 + data[10]) *
    //           1.0; // Flow: flow2 (MSB, byte 11) + flow1 (LSB, byte 10)
    //       double co2 =
    //           (data[15] * 256 + data[14]) *
    //           1.0; // CO2: co2_2 (MSB, byte 15) + co2_1 (LSB, byte 14)
    //       // double vol =
    //       //     (data[13] * 256 + data[12]) * 1.0; // Vol: Vol2 (MSB) + Vol1 (LSB)

    //       // flow = 9.82 *1000/ flow;
    //       //
    //       setState(() {
    //         flow = flow;
    //       });

    //       rawDataFull.add(ecg);
    //       // print(flow);
    //       saver(ecg: ecg, o2: o2, flow: flow, vol: vol, co2: co2);

    //       // // updateEverything(scaledEcg, scaledO2, scaledFlow, scaledCo2);
    //       // List<double>? edt =  myBigGraphKey.currentState?.updateEverything([ecg, o2, co2, vol]);
    //       // // Update your graph
    //       // _inMemoryData.add([edt![0], edt![1], edt![2], edt![3], flow]);

    //       // Update your graph
    //       // ➕ Step 1: Add incoming raw data to buffer
    //       delayBuffer.add([ecg, o2, co2, vol, flow]);

    //       // 🧹 Step 2: Prevent memory leak by limiting buffer
    //       int bufferSizeLimit = ((delaySamples ?? 0) + 1) * 2;
    //       if (delayBuffer.length > bufferSizeLimit) {
    //         delayBuffer.removeAt(0);
    //       }

    //       // 🛑 Step 3: If delaySamples not available, plot raw data
    //       if (delaySamples == null || delayBuffer.length <= delaySamples!) {
    //         // Optional: Plot raw data until delay is known
    //         List<double>? edt = myBigGraphKey.currentState?.updateEverything([
    //           ecg,
    //           o2,
    //           co2,
    //           vol,
    //         ]);
    //         if (edt != null) {
    //           _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], flow]);
    //         }
    //         return;
    //       }

    //       // ✅ Step 4: Build delay-corrected values
    //       var current = delayBuffer[0]; // time t
    //       var future = delayBuffer[delaySamples!]; // time t + delay

    //       double correctedECG = current[0]; // live
    //       double correctedVOL = current[3]; // live
    //       double correctedFLOW = current[4]; // live
    //       double correctedO2 = future[1]; // future O2
    //       double correctedCO2 = future[2]; // future CO2

    //       // 🧼 Step 5: Remove used sample
    //       delayBuffer.removeAt(0);

    //       // ✅ Step 6: Plot delay-corrected values
    //       List<double>? edt = myBigGraphKey.currentState?.updateEverything([
    //         correctedECG,
    //         correctedO2,
    //         correctedCO2,
    //         correctedVOL,
    //       ]);

    //       // ✅ Step 7: Store to memory
    //       if (edt != null) {
    //         _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], correctedFLOW]);
    //       }
    //     } else {
    //       print("⚠️ Invalid frame header: ${data[0]}, ${data[1]}");
    //     }
    //   },
    //   onDone: () {
    //     print("Serial Done");
    //   },
    //   onError: (e) {
    //     print("❌ Serial port error: $e");
    //   },
    // );
    reader.stream.listen(
      (data) {
        // final hexString = data
        //     .map((b) => b.toRadixString(16).padLeft(2, '0'))
        //     .join(' ');
        // print("Packet Start");
        // print(hexString);
        // print("Packet End");
        int frameLength = 18;
        for (int i = 0; i <= data.length - frameLength;) {
          // Look for a valid frame header
          if (data[i] == 'B'.codeUnitAt(0) &&
              data[i + 1] == 'T'.codeUnitAt(0)) {
            // Check that we have a full frame ahead
            if (i + frameLength <= data.length) {
              final frame = data.sublist(i, i + frameLength);
              // print("DATACOM HERE");

              // Your existing logic here
              // double vol = (frame[13] << 8 | frame[12]) * 1.0;
              double vol = (frame[13] * 256 + frame[12]) * 1.0;

              recentVolumes.add(vol);
              if (recentVolumes.length > 10) {
                recentVolumes.removeAt(0);
              }

              int nonZeroCount = recentVolumes.where((v) => v > 50).length;
              bool currentIsZero = vol <= 5;

              if (nonZeroCount >= 5 && currentIsZero && wasExhaling) {
                onExhalationDetected();
                wasExhaling = false;
              }

              if (vol > 50) {
                wasExhaling = true;
              }

              double ecg = (frame[3] * 256 + frame[2]) * 1.0;
              double o2 = (frame[7] * 256 + frame[6]) * 1.0;
              double flow = (frame[11] * 256 + frame[10]) * 1.0;
              double co2 = (frame[15] * 256 + frame[14]) * 1.0;

              // flow = 9.82 * 1000 / flow;

              setState(() {
                flow = flow;
              });

              rawDataFull.add(ecg);
              saver(ecg: ecg, o2: o2, flow: flow, vol: vol, co2: co2);

              // delayBuffer.add([ecg, o2, co2, vol, flow]);  // commenting this stop delay correction

              int bufferSizeLimit = ((delaySamples ?? 0) + 1) * 2;
              if (delayBuffer.length > bufferSizeLimit) {
                delayBuffer.removeAt(0);
              }

              if (delaySamples == null || delayBuffer.length <= delaySamples!) {
                // print("DATACOMHERE2");
                List<double>? edt = myBigGraphKey.currentState
                    ?.updateEverything([ecg, o2, co2, flow, vol]);
                if (edt != null) {
                  _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], flow]);
                }
                i += frameLength;
                continue;
              }

              var current = delayBuffer[0];
              var future = delayBuffer[delaySamples!];

              double correctedECG = current[0];
              double correctedVOL = current[3];
              double correctedFLOW = current[4];
              double correctedO2 = future[1];
              double correctedCO2 = future[2];

              delayBuffer.removeAt(0);

              List<double>? edt = myBigGraphKey.currentState?.updateEverything([
                correctedECG,
                correctedO2,
                correctedCO2,
                correctedFLOW,
                correctedVOL,
              ]);

              if (edt != null) {
                _inMemoryData.add([
                  edt[0],
                  edt[1],
                  edt[2],
                  edt[3],
                  correctedFLOW,
                ]);
              }

              i += frameLength; // move to next possible frame
            } else {
              // Not enough bytes for a full frame, break to wait for next chunk
              break;
            }
          } else {
            // Not a valid frame header, move forward by 1 byte and search again
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
    timer.cancel(); // Always cancel timer!
    port.close(); // Close the serial port
    super.dispose();
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

  Future<List<Widget>> buildChartsFromSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('saved_charts');

    if (saved == null) return [Text('No saved chart found.')];

    List<dynamic> charts = jsonDecode(saved);
    if (charts.isEmpty) return [Text('Chart list is empty.')];

    List<Map<String, dynamic>> dataPoints = List<Map<String, dynamic>>.from(
      cp!['breathStats'],
    );

    List<Widget> chartWidgets = [];

    for (Map<String, dynamic> chart in charts) {
      String xKey = chart['xaxis'];
      String yKey = chart['yaxis'];
      String name = chart['name'];

      List<double> xValues = [];
      List<double> yValues = [];

      for (int i = 0; i < dataPoints.length; i++) {
        var point = dataPoints[i];

        // Handle x-axis
        double x;
        if (xKey == 'time_series') {
          x = i.toDouble();
        } else if (point[xKey] != null) {
          x = point[xKey].toDouble();
        } else {
          continue;
        }

        // Handle y-axis
        double y;
        if (yKey == 'time_series') {
          y = i.toDouble();
        } else if (point[yKey] != null) {
          y = point[yKey].toDouble();
        } else {
          continue;
        }

        xValues.add(x);
        yValues.add(y);
      }

      chartWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('$name ($yKey vs $xKey)',
            // style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Container(
              width: 400,
              height: MediaQuery.of(context).size.height / 2,
              child: CustomLineChart(
                xLabel: xKey,
                yLabel: yKey,
                xValues: xValues,
                yValues: yValues,
                lineLabel: '$yKey vs $xKey',
              ),
            ),
          ],
        ),
      );
    }

    return chartWidgets;
  }

  ChartDialog() {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.zero, // makes dialog full screen
            child: Container(
              width: MediaQuery.of(context).size.width / 1.2,
              height: MediaQuery.of(context).size.height / 1.9,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          FutureBuilder<List<Widget>>(
                            future: buildChartsFromSavedPreference(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              } else if (snapshot.hasError) {
                                return Text("Error loading charts.");
                              } else {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children:
                                        snapshot.data!
                                            .map(
                                              (chart) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12.0,
                                                    ),
                                                child: SizedBox(
                                                  width:
                                                      300, // Fixed width for each chart
                                                  child: chart,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  ),
                                );
                              }
                            },
                          ),

                          // Row(
                          //   children: [
                          //     Expanded(
                          //       child: CustomLineChart(
                          //         xValues: volx,
                          //         yValues: volumes,
                          //         lineLabel: 'Volumes',
                          //       ),
                          //     ),
                          //     const SizedBox(width: 12),
                          //     Expanded(
                          //       child: CustomLineChart(
                          //         xValues: vco2YList,
                          //         yValues: volumes,
                          //         lineLabel: 'VCO2',
                          //       ),
                          //     ),
                          //     const SizedBox(width: 12),
                          //
                          //     Expanded(
                          //       child: CustomLineChart(
                          //         xValues: rerX,
                          //         yValues: rerList,
                          //         lineLabel: 'RER',
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          const SizedBox(height: 12),

                          const SizedBox(height: 16),
                          SafeArea(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String getAvailableFilePath(
    String basePath,
    String baseName,
    String extension,
  ) {
    int counter = 1;
    String filePath = '$basePath/$baseName.$extension';

    while (File(filePath).existsSync()) {
      filePath = '$basePath/$baseName($counter).$extension';
      counter++;
    }

    return filePath;
  }

  Future<void> exportBreathStatsToExcel(Map<String, dynamic> cp) async {
    if (cp['breathStats'] == null || !(cp['breathStats'] is List)) return;

    final breathStats = List<Map<String, dynamic>>.from(cp['breathStats']);
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    // ✅ Custom headers
    final customHeaders = [
      'O%',
      'CO2%',
      'HR',
      'VO2%',
      'VCO2%',
      'VE MINTUE',
      'RER',
      'ESTIMATED CO',
    ];

    for (int i = 0; i < customHeaders.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(customHeaders[i]);
    }

    // Fill data according to the custom order
    for (int r = 0; r < breathStats.length; r++) {
      final row = breathStats[r];
      sheet
          .getRangeByIndex(r + 2, 1)
          .setText(row['o2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 2)
          .setText(row['co2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 3)
          .setText(row['hr']?.toStringAsFixed(0) ?? '');
      sheet
          .getRangeByIndex(r + 2, 4)
          .setText(row['vo2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 5)
          .setText(row['vco2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 6)
          .setText(row['minuteVentilation']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 7)
          .setText(row['rer']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 8)
          .setText(row['co']?.toStringAsFixed(2) ?? '');
    }

    final dir = await getDownloadsDirectory();
    final path = getAvailableFilePath(dir!.path, 'CPET_breathstats', 'xlsx');
    final bytes = workbook.saveAsStream();
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    workbook.dispose();

    print("✅ Excel exported to: $path");
  }

  void showBreathStatsTableModal(
    BuildContext context,
    Map<String, dynamic> cp,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Breath Stats Table",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    alignment: Alignment.topRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final liveData = breathStatsNotifier.value;

                        if (liveData != null &&
                            liveData is List<Map<String, dynamic>> &&
                            liveData.isNotEmpty) {
                          await exportBreathStatsToExcel({
                            'breathStats': liveData,
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Excel downloaded successfully!'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('No data to export')),
                          );
                        }
                      },
                      icon: Icon(Icons.download),
                      label: Text("Download Excel"),
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        modalSetState = setState;
                        return AnimatedBuilder(
                          animation: breathStatsNotifier,
                          builder: (context, _) {
                            return breathStatsTable(
                              breathStatsNotifier.value?.reversed.toList() ??
                                  [],
                            );
                          },
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 12),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Close"),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget breathStatsTable(List<Map<String, dynamic>> data) {
    final headers = [
      'O%',
      'CO2%',
      'HR',
      'VO2%',
      'VCO2%',
      'VE MINTUE',
      'RER',
      'ESTIMATED CO',
    ];
    final verticalController = ScrollController();
    final horizontalController = ScrollController();

    return Scrollbar(
      thumbVisibility: true,
      controller: verticalController,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: SingleChildScrollView(
          controller: verticalController,
          scrollDirection: Axis.vertical,

          child: Center(
            child: DataTable(
              columns:
                  headers
                      .map(
                        (h) => DataColumn(
                          label: Text(
                            h,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                      .toList(),
              rows:
                  data.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text((row['o2'] ?? ''))),
                        DataCell(Text((row['co2'] ?? ''))),
                        DataCell(Text((row['hr'] ?? ''))),
                        DataCell(Text((row['vo2'] ?? '').toStringAsFixed(2))),
                        DataCell(Text((row['vco2'] ?? '').toStringAsFixed(2))),
                        DataCell(Text((row['vol'] ?? '').toString())),
                        DataCell(Text((row['rer'] ?? '').toStringAsFixed(2))),
                        DataCell(Text((row['co'] ?? '').toString())),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ),
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
        Text(
          defaultPatient != null
              ? 'Patient: ' + defaultPatient['name']
              : 'No Patient',
          style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),

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

  Widget _iconButtonColumn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.all(14),
              elevation: 3,
            ),
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
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

    print("✅ Imported ${samples.length} samples from $path");
    return {"patient": patientInfo, "samples": samples};
  }

  Future<void> saveRecordingSlice() async {
    if (!_saverInitialized) {
      print("❌ DataSaver not initialized.");
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
    print("Max samples in file: $maxSamples");
    print(recordStartIndex);
    print(recordEndIndex);
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

    // ✅ Build the custom path
    final String recordingsPath = p.join(docsDir.path, 'SpiroBT', 'Records');

    // ✅ Create the folder if it doesn't exist
    final recordingsDir = Directory(recordingsPath);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    // ✅ Ask user where to save using FilePicker
    String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save your recorded file',
      fileName: 'recorded_data.bin',
      initialDirectory: recordingsPath, // May be ignored on some platforms
    );

    if (savePath == null) {
      print("⚠️ User cancelled save dialog.");
      return;
    }

    await File(
      savePath,
    ).writeAsBytes(lengthBytes + headerJsonBytes + selectedBytes);
    print("✅ Saved recording to: $savePath");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Recording saved to file successfully.")),
    );
  }

  void resetAllData() {
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
      isImported = false;
    });
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
                        _iconButtonColumn(
                          icon: isPlaying ? Icons.pause : Icons.play_arrow,
                          label: "Play",
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
                                isPlaying = !isPlaying;
                              });
                            } else {
                              init();
                              setState(() {
                                isPlaying = !isPlaying;
                              });
                            }
                            // Replace with your actual toggle logic
                          },
                        ),
                        _iconButtonColumn(
                          icon:
                              isRecording
                                  ? Icons.stop
                                  : Icons.fiber_manual_record,
                          label: isRecording ? "Stop" : "Record",
                          onPressed: () async {
                            if (!isRecording) {
                              recordStartIndex = sampleCounter;
                              print(
                                "Recording started at index: $recordStartIndex",
                              );
                              setState(() {
                                isRecording = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Recording started")),
                              );
                            } else {
                              // Stop recording
                              port.close();
                              print("Stopping recording...");

                              recordEndIndex = sampleCounter;
                              print(
                                "Recording stopped at index: $recordEndIndex",
                              );
                              setState(() {
                                isRecording = false;
                                isPlaying = false;
                              });
                              await flushRemainingData();
                              await saveRecordingSlice(); // implement next
                              resetAllData();
                            }
                          },
                        ),

                        _iconButtonColumn(
                          icon: Icons.save_alt,
                          label: "Load Data",
                          onPressed: () async {
                            setState(() {
                              isImported = true;
                            });

                            try {
                              // Step 1: Import file
                              final result = await importBinFile();

                              if (result == null ||
                                  !result.containsKey('samples') ||
                                  !result.containsKey('patient')) {
                                print("Invalid file structure");
                                return;
                              }

                              // Step 2: Set patient info
                              // setState(() {
                              //   defaultPatient = result['patient'];
                              // });

                              final samples =
                                  result['samples'] as List<dynamic>;

                              // Step 3: Push all samples to graph and memory
                              for (final sample in samples) {
                                if (sample is List && sample.length >= 5) {
                                  final List<double> numericSample =
                                      sample
                                          .map((e) => (e as num).toDouble())
                                          .toList();

                                  final edt = myBigGraphKey.currentState
                                      ?.updateEverything(numericSample);
                                  if (edt != null && edt.length >= 5) {
                                    _inMemoryData.add([
                                      edt[0],
                                      edt[1],
                                      edt[2],
                                      edt[4],
                                      edt[3],
                                    ]);
                                  }
                                }
                              }

                              print("Imported ${samples.length} samples.");
                              onExhalationDetected();
                            } catch (e) {
                              print("❌ Error while importing: $e");
                            }
                          },
                        ),
                        _iconButtonColumn(
                          icon: Icons.person,
                          label: "Patients",
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => Patients(),
                              ),
                            );
                          },
                        ),
                        _iconButtonColumn(
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
                        _iconButtonColumn(
                          icon: Icons.table_chart,
                          label: "Data Mode",
                          onPressed: () {
                            if (cp != null) {
                              showBreathStatsTableModal(context, cp!);
                            }
                          },
                        ),
                        _iconButtonColumn(
                          icon: Icons.bar_chart,
                          label: "Charts",
                          onPressed: () {
                            ChartDialog();
                          },
                        ),
                        _iconButtonColumn(
                          icon: Icons.auto_graph,
                          label: "Generate",
                          onPressed: () {
                            if (cp != null && cp!['breathStats'] is List) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChartGenerator(cp: cp),
                                ),
                              );
                            }
                          },
                        ),

                        _iconButtonColumn(
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
                        isImported: isImported,
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
                        plot: [
                          {
                            "name": "ECG",
                            "boxValue": 4096 / 12,
                            "unit": "mV",
                            "minDisplay": (-4096 / 12) * 3,
                            "maxDisplay": (4096 / 12) * 3,
                            "scale": 3,
                            "gain": 0.4,
                          },
                          {
                            "name": "O2",
                            "scale": 3,
                            "boxValue": 5,
                            "unit": "%",
                            "minDisplay": 0.0,
                            "maxDisplay": 30.0,
                            "filterConfig": {
                              "filterOn": false,
                              "lpf": 3,
                              "hpf": 5,
                              "notch": 1,
                            },
                            "meter": {
                              "decimal": 1,
                              "unit":
                                  Provider.of<GlobalSettingsModal>(
                                        context,
                                      ).applyConversion
                                      ? " %"
                                      : " mV",
                              // "convert": (double x) => x, // voltage
                              // "convert": (double x) => x * 0.00072105 , // voltage
                              "convert": (double x) {
                                x = x * 0.00072105;
                                // print("VLT: ${x}");
                                globalSettings =
                                    Provider.of<GlobalSettingsModal>(
                                      context,
                                      listen: false,
                                    );

                                if (globalSettings != null &&
                                    globalSettings.applyConversion == true) {
                                  double result = o2Calibrate(x);
                                  return result;
                                }

                                // print("RES: ${result}");
                                return x;
                              }, // voltage
                              // "convert": (double x) => x * 0.013463 - 0.6,
                            },
                          },
                          // {
                          //   "name": "Flow",
                          //   "scale": 3,
                          //   "meter": {
                          //     "unit": "l/s",
                          //     // "convert": (double x) => x * 0.03005 - 4.1006 ,
                          //     // "convert": (double x) => x * (0.001464/4) ,
                          //     // "convert": (double x) => x * 0.00072105 ,
                          //     "convert": (double x) => x,
                          //   },
                          // },
                          {
                            "name": "CO2",
                            "scale": 3,
                            "boxValue": 1 * 100,
                            "boxValueConvert": (double x) => x / 100,
                            "unit": "%",
                            "minDisplay": 100,
                            "maxDisplay": 7 * 100,
                            "filterConfig": {
                              "filterOn": false,
                              "lpf": 3,
                              "hpf": 5,
                              "notch": 1,
                            },
                            "meter": {
                              "decimal": 1,
                              "unit": "%",
                              "convert": (double x) => x / 100,
                            },
                          },
                          {
                            "name": "Flow",
                            "scale": 3,
                            "boxValue": 100,
                            "unit": "l/s",
                            "minDisplay": 0.0,
                            "maxDisplay": 550,

                            "meter": {
                              "decimal": 0,
                              "unit": " ",
                              "convert": (double x) => x,
                            },
                          },
                          {
                            "name": "Tidal Volume",
                            "scale": 3,
                            "boxValue":
                                100, // ✅ Each grid box is 25 units (e.g., ml)
                            "boxStep": 25.0, // 👈 new config

                            "unit": "ml", // ✅ Shown on Y-axis
                            "minDisplay":
                                0.0, // ✅ Lower bound for displayed values
                            "maxDisplay":
                                550.0, // ✅ Upper bound for displayed values
                            "meter": {
                              "decimal": 0,
                              "unit": " ",
                              "convert": (double x) => x,
                            },
                          },
                        ],
                        windowSize: 3000,
                        verticalLineConfigs: [
                          {'seconds': 0.2, 'stroke': 0.5, 'color': Colors.blue},
                          {'seconds': 0.4, 'stroke': 0.5, 'color': Colors.blue},
                          {'seconds': 1.0, 'stroke': 0.8, 'color': Colors.red},
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
