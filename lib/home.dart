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

  var o2Calibrate;

  Map<String, dynamic>? cp;
  @override
  void initState() {
    super.initState();
    initFunc();

    // startTestLoop();
    // init();
    // CPETService cpet = CPETService();
    // timer = Timer.periodic(Duration(seconds: 10), (timer) {
    //
    // });
  }
  initFunc()async{
    final globalSettings = await Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    o2Calibrate = generateCalibrationFunction(
      voltage1: globalSettings.voltage1,
      value1: globalSettings.value1,
      voltage2: globalSettings.voltage2,
      value2: globalSettings.value2,
    );
    loadGlobalSettingsFromPrefs();
    print("INIT");
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

  onExhalationDetected(){
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
      final globalSettings = Provider.of<GlobalSettingsModal>(context, listen: false);

       cp = cpet.init(_inMemoryData,globalSettings);
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
    }catch(e){
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
              vol,
            ]);
            if (edt != null) {
              _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], flow]);
            }
            return;
          }

// ✅ Step 4: Build delay-corrected values
          var current = delayBuffer[0];                       // time t
          var future = delayBuffer[delaySamples!];            // time t + delay

          double correctedECG = current[0];  // live
          double correctedVOL = current[3]; // live
          double correctedFLOW = current[4]; // live
          double correctedO2 = future[1];   // future O2
          double correctedCO2 = future[2];  // future CO2

// 🧼 Step 5: Remove used sample
          delayBuffer.removeAt(0);

// ✅ Step 6: Plot delay-corrected values
          List<double>? edt = myBigGraphKey.currentState?.updateEverything([
            correctedECG,
            correctedO2,
            correctedCO2,
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
          // double vol =
          //     (data[13] * 256 + data[12]) * 1.0; // Vol: Vol2 (MSB) + Vol1 (LSB)

          // flow = 9.82 *1000/ flow;
          //
          setState(() {
            flow = flow;
          });

          rawDataFull.add(ecg);
          // print(flow);
          saver(ecg: ecg, o2: o2, flow: flow, vol: vol, co2: co2);


          // // updateEverything(scaledEcg, scaledO2, scaledFlow, scaledCo2);
          // List<double>? edt =  myBigGraphKey.currentState?.updateEverything([ecg, o2, co2, vol]);
          // // Update your graph
          // _inMemoryData.add([edt![0], edt![1], edt![2], edt![3], flow]);

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
              vol,
            ]);
            if (edt != null) {
              _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], flow]);
            }
            return;
          }

// ✅ Step 4: Build delay-corrected values
          var current = delayBuffer[0];                       // time t
          var future = delayBuffer[delaySamples!];            // time t + delay

          double correctedECG = current[0];  // live
          double correctedVOL = current[3]; // live
          double correctedFLOW = current[4]; // live
          double correctedO2 = future[1];   // future O2
          double correctedCO2 = future[2];  // future CO2

// 🧼 Step 5: Remove used sample
          delayBuffer.removeAt(0);

// ✅ Step 6: Plot delay-corrected values
          List<double>? edt = myBigGraphKey.currentState?.updateEverything([
            correctedECG,
            correctedO2,
            correctedCO2,
            correctedVOL,
          ]);

// ✅ Step 7: Store to memory
          if (edt != null) {
            _inMemoryData.add([edt[0], edt[1], edt[2], edt[3], correctedFLOW]);
          }




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
  Future<List<Widget>> buildChartsFromSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('saved_charts');

    if (saved == null) return [Text('No saved chart found.')];

    List<dynamic> charts = jsonDecode(saved);
    if (charts.isEmpty) return [Text('Chart list is empty.')];

    List<Map<String, dynamic>> dataPoints =
    List<Map<String, dynamic>>.from(cp!['breathStats']);

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
              height: MediaQuery.of(context).size.height/2,
              child: CustomLineChart(
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
  ChartDialog(){
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(

        insetPadding: EdgeInsets.zero, // makes dialog full screen
        child: Container(
          width: MediaQuery.of(context).size.width/1.2,
          height: MediaQuery.of(context).size.height / 1.9 ,
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
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Text("Error loading charts.");
                          } else {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: snapshot.data!
                                    .map((chart) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: SizedBox(
                                    width: 300, // Fixed width for each chart
                                    child: chart,
                                  ),
                                ))
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

  _vitals({defaultPatient = null}) {

    List<double> volumes = [];
    List<double> vo2List = [];

    List<double> volx = [];
    // vco2
    List<double> vco2YList = [];

    List<double> rerList = [];
    List<double> rerX = [];
    if (cp != null && cp!['breathStats'] is List) {
      volumes = (cp!['breathStats'] as List)
          .map((e) => (e['vol'] as num?)?.toDouble() ?? 0.0)
          .toList();
      // print("volumes");
       volx = List.generate(volumes.length, (index) => index.toDouble());

    //    vo2
      vo2List = (cp!['breathStats'] as List)
          .map((e) => (e['vo2'] as num?)?.toDouble() ?? 0.0)
          .toList();


      //vco2

      vco2YList = (cp!['breathStats'] as List)
          .map((e) => (e['vco2'] as num?)?.toDouble() ?? 0.0)
          .toList();

      // rer
      rerList = (cp!['breathStats'] as List)
          .map((e) => (e['rer'] as num?)?.toDouble() ?? 0.0)
          .toList();
      rerX = List.generate(rerList.length, (index)=> index.toDouble());

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
        ElevatedButton(onPressed: (){

          ChartDialog();



        }, child: Text("Charts")),
        SizedBox(
          height:10
        ),
        ElevatedButton(onPressed: (){
    if (cp != null && cp!['breathStats'] is List) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context)=> ChartGenerator(
          cp : cp
      )));
    }

        }, child: Text('Generate Chart')),
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
              value: respirationRate != null ? respirationRate!.toStringAsFixed(0) : "0",
              unit: "/Min",
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

                              "decimal": 1,
                              "unit": "%",
                              // "convert": (double x) => x, // voltage
                              // "convert": (double x) => x * 0.00072105 , // voltage
                              "convert": (double x) {
                                x = x * 0.00072105;
                                // print("VLT: ${x}");
                                double result = o2Calibrate(x);
                                // print("RES: ${result}");
                                return result;
                              } , // voltage
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
                            "meter": {
                              "decimal": 1,
                              "unit": "%",
                              "convert": (double x) => x / 100,
                            },
                          },
                          {
                            "name": "Tidal Volume",
                            "scale": 3,
                            "meter": {
                              "decimal": 0,
                              "unit": " ", "convert": (double x) => x},
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
