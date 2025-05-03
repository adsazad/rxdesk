import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libserialport/libserialport.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/Pages/GlobalSettings.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';
import 'package:spirobtvo/Widgets/MyBigGraph.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<MyBigGraphState> myBigGraphKey = GlobalKey<MyBigGraphState>();

  double time = 0.0; // 🧠 To move the sine wave over time
  late Timer timer;

  List<double> rawDataFull = [];
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();

    loadGlobalSettingsFromPrefs();
    print("INIT");
    // startTestLoop();
    // init();
    // timer = Timer.periodic(Duration(milliseconds: 20), (timer) {
    //   _sendSineWaveData();
    // });
  }
  loadGlobalSettingsFromPrefs() async {
    prefs = await SharedPreferences.getInstance();
    final globalSettings = Provider.of<GlobalSettingsModal>(context, listen: false);
    if(prefs!.containsKey("globalSettings")) {
      var globalSettingsJson = prefs!.getString("globalSettings");

      globalSettings.fromJson(globalSettingsJson);
    }
  }

  void _sendSineWaveData() {
    time += 0.02; // Simulate time passing every 20ms

    double ecgVal = sin(2 * pi * 1 * time) * 500;   // 1 Hz sine wave, 500 amplitude
    double o2Val = sin(2 * pi * 0.5 * time) * 300;  // 0.5 Hz slower wave
    double flowVal = sin(2 * pi * 2 * time) * 200;  // 2 Hz faster wave
    double co2Val = sin(2 * pi * 0.25 * time) * 100; // 0.25 Hz very slow wave
    ecgVal  = ecgVal *6;
    myBigGraphKey.currentState?.updateEverything([
      ecgVal,
      o2Val,
      flowVal,
      co2Val,
    ]);
  }

  Future<List<double>> loadTestData() async {
    final byteData = await rootBundle.load('assets/capture.txt');
    final rawBytes = byteData.buffer.asUint8List();
    String rawData = String.fromCharCodes(rawBytes);

    // Remove non-hex characters (keep only 0-9, A-F, a-f)
    String hexOnly = rawData.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    List<double> values = [];
    for (int i = 0; i <= hexOnly.length - 4; i += 4) {
      String hex = hexOnly.substring(i, i + 4);
      int value = int.parse(hex, radix: 16);
      if (value > 0x7FFF) value -= 0x10000; // Handle 16-bit signed
      values.add(value.toDouble());
    }

    return values;
  }

  List<double> testData = [];
  int dataIndex = 0;

  void startTestLoop() async {
    testData = await loadTestData();

    Timer.periodic(Duration(milliseconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Simulate 3-channel data (split the single stream into 3)
      List<double> values = List.generate(3, (i) {
        int index = (dataIndex + i) % testData.length;
        return testData[index];
      });

      dataIndex = (dataIndex + 3) % testData.length;

      // Update your graph
      myBigGraphKey.currentState?.updateEverything(values);
    });
  }



  init(){
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
    }catch (error) {
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
    reader.stream.listen((data) {
      final hexString = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      if (data[0] == 'B'.codeUnitAt(0) && data[1] == 'T'.codeUnitAt(0)) {
        double ecg  = (data[3] * 256 + data[2]) * 1.0;          // ECG: ecg2 (MSB, byte 3) + ecg1 (LSB, byte 2)
        double o2   = (data[7] * 256 + data[6]) * 1.0;          // O2:  O2_2 (MSB, byte 7) + O2_1 (LSB, byte 6)
        double flow = (data[11] * 256 + data[10]) * 1.0;        // Flow: flow2 (MSB, byte 11) + flow1 (LSB, byte 10)
        double co2  = (data[15] * 256 + data[14]) * 1.0;        // CO2: co2_2 (MSB, byte 15) + co2_1 (LSB, byte 14)
        double vol = (data[13] * 256 + data[12]) * 1.0;         // Vol: Vol2 (MSB) + Vol1 (LSB)

        // flow = 9.82 *1000/ flow;
        //

        rawDataFull.add(ecg);
        // print(flow);

        // updateEverything(scaledEcg, scaledO2, scaledFlow, scaledCo2);
        myBigGraphKey.currentState?.updateEverything([ecg, o2, flow, co2,vol]);
      } else {
        print("⚠️ Invalid frame header: ${data[0]}, ${data[1]}");
      }
    },onDone: (){
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("SprioBT VO2"),
        actions: [
          IconButton(onPressed: (){
            Navigator.of(context).push(MaterialPageRoute(builder: (context)=>GlobalSettings()));
          }, icon: Icon(Icons.settings)),
          IconButton(onPressed: (){
            init();
          }, icon: Icon(Icons.refresh)),
        ],
      ),
      body: SingleChildScrollView(
        child: MyBigGraph(
          key: myBigGraphKey,
          plot: [
            {"name": "ECG", "scale": 3, "gain": 0.4},
            {"name": "O2", "scale": 3,"meter": {
              "unit": "%",
              // "convert": (double x) => x * 0.03005 - 4.1006 ,
              // "convert": (double x) => x * (0.001464/4) ,
              // "convert": (double x) => x * 0.00072105 ,
              "convert": (double x) => x * 0.013463 - 0.6 ,
            },
            },
            {"name": "Flow", "scale": 3,"meter": {
              "unit": "l/s",
              // "convert": (double x) => x * 0.03005 - 4.1006 ,
              // "convert": (double x) => x * (0.001464/4) ,
              // "convert": (double x) => x * 0.00072105 ,
              "convert": (double x) => x ,
            }},
            {"name": "CO2", "scale": 3,"meter": {
              "unit": "%",
              "convert": (double x) => x / 100,
            },
            },
            {"name": "Volume", "scale": 3,"meter": {
              "unit": ".",
              "convert": (double x) => x,
            },
            }
          ],
          windowSize: 900,
          verticalLineConfigs: [
            { 'seconds': 0.2, 'stroke': 0.5, 'color': Colors.blue },
            { 'seconds': 0.4, 'stroke': 0.5, 'color': Colors.blue },
            { 'seconds': 1.0, 'stroke': 0.8, 'color': Colors.red },
          ],
          horizontalInterval: 4096 / 12,
          verticalInterval: 8,
          samplingRate: 300,
          minY: -(4096 / 12) * 5,
          maxY: (4096 / 12) * 25,
        ),
      ),
    );
  }
}
