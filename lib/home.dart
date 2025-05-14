import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libserialport/libserialport.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/Pages/GlobalSettings.dart';
import 'package:spirobtvo/Pages/patient/list.dart';
import 'package:spirobtvo/Pages/patient/patientAdd.dart';
import 'package:spirobtvo/ProviderModals/DefaultPatientModal.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';
import 'package:spirobtvo/Services/CPETService.dart';
import 'package:spirobtvo/Services/DataSaver.dart';
import 'package:spirobtvo/Services/EcgBPMCalculator.dart';
import 'package:spirobtvo/Widgets/MyBigGraph.dart';
import 'package:spirobtvo/Widgets/VitalsBox.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<MyBigGraphState> myBigGraphKey = GlobalKey<MyBigGraphState>();

  double time = 0.0; // 🧠 To move the sine wave over time
  late Timer timer;
  double votwo = 0;
  double votwokg = 0;
  double vco = 0;
  double? rer = 0;
  double? vol = 0;
  double? flow = 0;
  double? bpm = 0;

  List<double> rawDataFull = [];
  SharedPreferences? prefs;

  bool isPlaying = false;
  final dataSaver = DataSaver();

  List<List<double>> _inMemoryData = [];

  EcgBPMCalculator ecgBPMCalculator = EcgBPMCalculator();

  Queue<double> o2Buffer = Queue<double>();
  Queue<double> co2Buffer = Queue<double>();
  int? delaySamples; // Initially null


  @override
  void initState() {
    super.initState();

    loadGlobalSettingsFromPrefs();
    print("INIT");
    startTestLoop();
    // init();
    CPETService cpet = CPETService();
    timer = Timer.periodic(Duration(seconds: 10), (timer) {
      var stats = ecgBPMCalculator.getStats(_inMemoryData);
      // print(stats);
      final patientProvider = Provider.of<DefaultPatientModal>(
        context,
        listen: false,
      );
      final patient = patientProvider.patient;

      print("VOLPEAK");
      var cp = cpet.init(_inMemoryData);
      // print(cp);
      setState(() {
        votwo = cp["lastBreathStat"]["vo2"];
        vco = cp["lastBreathStat"]["vco2"];
        rer = cp["lastBreathStat"]["rer"];
        vol = cp["lastBreathStat"]["vol"];
        bpm = stats["bpm"];
        if(patient != null) {
          double weight = double.parse(patient["weight"]);
          votwokg = votwo / weight;
        }
      });
    });
  }

  bool _saverInitialized = false;

  saver({
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

    // Initialize once
    if (!_saverInitialized) {
      await dataSaver.init(
        filename: "spirobt-${DateTime.now().microsecondsSinceEpoch}.bin",
        patientInfo: patient,
      );
      _saverInitialized = true;
    }

    await dataSaver.append(ecg: ecg, o2: o2, co2: co2, vol: vol, flow: flow);
  }

  loadGlobalSettingsFromPrefs() async {
    prefs = await SharedPreferences.getInstance();
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    if (prefs!.containsKey("globalSettings")) {
      var globalSettingsJson = prefs!.getString("globalSettings");

      globalSettings.fromJson(globalSettingsJson);
    }
  }

  void _sendSineWaveData() {
    time += 0.02; // Simulate time passing every 20ms

    double ecgVal =
        sin(2 * pi * 1 * time) * 500; // 1 Hz sine wave, 500 amplitude
    double o2Val = sin(2 * pi * 0.5 * time) * 300; // 0.5 Hz slower wave
    double flowVal = sin(2 * pi * 2 * time) * 200; // 2 Hz faster wave
    double co2Val = sin(2 * pi * 0.25 * time) * 100; // 0.25 Hz very slow wave
    ecgVal = ecgVal * 6;
    myBigGraphKey.currentState?.updateEverything([
      ecgVal,
      o2Val,
      flowVal,
      co2Val,
    ]);
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

          // Extract values
          double ecg = (data[3] << 8 | data[2]) * 1.0;
          double o2 = (data[7] << 8 | data[6]) * 1.0;
          double flow = (data[11] << 8 | data[10]) * 1.0;
          double vol = (data[13] << 8 | data[12]) * 1.0;
          double co2 = (data[15] << 8 | data[14]) * 1.0;

          saver(ecg: ecg, o2: o2, flow: flow, vol: vol, co2: co2);
          // Update your graph
          List<double>? edt = myBigGraphKey.currentState?.updateEverything([
            ecg,
            o2,
            co2,
            vol,
          ]);

          _inMemoryData.add([edt![0], edt![1], edt![2], edt![3], flow]);
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

    SerialPort port = SerialPort(globalSettings.com.toString());

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
    reader.stream.listen(
      (data) {
        final hexString = data
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ');
        if (data[0] == 'B'.codeUnitAt(0) && data[1] == 'T'.codeUnitAt(0)) {
          double ecg =
              (data[3] * 256 + data[2]) *
              1.0; // ECG: ecg2 (MSB, byte 3) + ecg1 (LSB, byte 2)
          double o2 =
              (data[7] * 256 + data[6]) *
              1.0; // O2:  O2_2 (MSB, byte 7) + O2_1 (LSB, byte 6)
          double flow =
              (data[11] * 256 + data[10]) *
              1.0; // Flow: flow2 (MSB, byte 11) + flow1 (LSB, byte 10)
          double co2 =
              (data[15] * 256 + data[14]) *
              1.0; // CO2: co2_2 (MSB, byte 15) + co2_1 (LSB, byte 14)
          double vol =
              (data[13] * 256 + data[12]) * 1.0; // Vol: Vol2 (MSB) + Vol1 (LSB)

          // flow = 9.82 *1000/ flow;
          //
          setState(() {
            flow = flow;
          });

          rawDataFull.add(ecg);
          // print(flow);
          saver(ecg: ecg, o2: o2, flow: flow, vol: vol, co2: co2);
          // updateEverything(scaledEcg, scaledO2, scaledFlow, scaledCo2);
          List<double>? edt =  myBigGraphKey.currentState?.updateEverything([ecg, o2, co2, vol]);
          // Update your graph
          _inMemoryData.add([edt![0], edt![1], edt![2], edt![3], flow]);
        } else {
          print("⚠️ Invalid frame header: ${data[0]}, ${data[1]}");
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
          SerialPort port = SerialPort(globalSettings.com.toString());
          port.close();
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

  _vitals({defaultPatient = null}) {
    return (Column(
      children: [
        Text(
          defaultPatient != null
              ? 'Patient: ' + defaultPatient['name']
              : 'No Patient',
          style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Card(
          elevation: 6,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [playPause(), SizedBox(width: 16)]),
                    ElevatedButton(
                      onPressed: () {},
                      // icon: Icon(Icons.record),
                      child: Text("Record"),
                      // label: Text("Record"),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      new MaterialPageRoute(builder: (context) => Patients()),
                    );
                  },
                  icon: Icon(Icons.person_add),
                  label: Text("Patient"),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
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
              label: "Volume",
              value: vol!.toStringAsFixed(2),
              unit: "ml/L",
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
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DefaultPatientModal>(
      builder: (context, defaultProvider, child) {
        final defaultPatient = defaultProvider.patient;
        return Scaffold(
          appBar: AppBar(
            title: Text("SprioBT VO2"),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => GlobalSettings()),
                  );
                },
                icon: Icon(Icons.settings),
              ),
              // IconButton(
              //   onPressed: () {
              //     init();
              //   },
              //   icon: Icon(Icons.refresh),
              // ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // bar
                Container(
                  alignment: Alignment.center,
                  color: Colors.blue,
                  height: 20,
                  width: double.infinity,
                ),
                SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: MyBigGraph(
                        key: myBigGraphKey,
                        onCycleComplete: (){
                          if(delaySamples == null) {
                            CPETService cpet = CPETService();
                            delaySamples = cpet.detectO2Co2DelayFromVolumePeaks(
                                _inMemoryData);
                            print("DELAY REQ");
                            print(delaySamples);
                          }
                        },
                        streamConfig: [
                          {
                            "vo2": {
                              "fun": (e) {
                                if (e.length > 2 &&
                                    e[1] != null &&
                                    e[3] != null) {
                                  double o2Percent = e[1] * 0.013463 - 0.6;
                                  double flow = e[3];
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
                                    e[3] != null &&
                                    e[3] != null) {
                                  double co2Fraction = e[2] / 100; // CO₂ %
                                  double flow = e[3]; // Flow in L/min
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
                          {"name": "ECG", "scale": 3, "gain": 0.4},
                          {
                            "name": "O2",
                            "scale": 3,
                            "meter": {
                              "unit": "%",
                              // "convert": (double x) => x * 0.03005 - 4.1006 ,
                              // "convert": (double x) => x * (0.001464/4) ,
                              // "convert": (double x) => x * 0.00072105 ,
                              "convert": (double x) => x * 0.013463 - 0.6,
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
                            "meter": {
                              "unit": "%",
                              "convert": (double x) => x / 100,
                            },
                          },
                          {
                            "name": "Volume",
                            "scale": 3,
                            "meter": {"unit": ".", "convert": (double x) => x},
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
