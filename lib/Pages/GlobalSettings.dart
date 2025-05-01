import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:libserialport/libserialport.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';

class GlobalSettings extends StatefulWidget {
  const GlobalSettings({super.key});

  @override
  State<GlobalSettings> createState() => _GlobalSettingsState();
}

class _GlobalSettingsState extends State<GlobalSettings> {
  bool filterOnOff = true;
  bool autoRecordOnOff = true;

  String? sampleRate = '300';

  // mHPFVal[0] = 0; mHPFVal[1] = 0.05; mHPFVal[2] = 0.1; mHPFVal[3] = 0.2;
  // mHPFVal[4] = 0.3; mHPFVal[5] = 0.6; mHPFVal[6] = 0.81;
  // mHPFVal[7] = 1;
  List<dynamic> highPassOptions = [
    {"label": "Disable", "value": 0},
    {"label": "0.05hz", "value": 1},
    {"label": "0.1hz", "value": 2},
    {"label": "0.2hz", "value": 3},
    {"label": "0.3hz", "value": 4},
    {"label": "0.6hz", "value": 5},
    {"label": "0.81hz", "value": 6},
    {"label": "1hz", "value": 7},
    {"label": "5hz", "value": 8},
  ];
  var highPassValue = 1;

  // mLPFVal[0] = 10; mLPFVal[1] = 15; mLPFVal[2] = 20;
  // mLPFVal[3] = 35; mLPFVal[4] = 70; mLPFVal[5] = 100;
  // mLPFVal[6] = 150; mLPFVal[7] = 5; mLPFVal[8] = 2; mLPFVal[9] = 1;
  List<dynamic> lowPassOptions = [
    {"label": "10hz", "value": 0},
    {"label": "15hz", "value": 1},
    {"label": "20hz", "value": 2},
    {"label": "35hz", "value": 3},
    {"label": "40hz", "value": 11},
    {"label": "70hz", "value": 4},
    {"label": "100hz", "value": 5},
    {"label": "150hz", "value": 6},
    {"label": "5hz", "value": 7},
    {"label": "2hz", "value": 8},
    {"label": "1hz", "value": 9},
  ];

  // List<dynamic> lowPassOptions = [
  //   {"label": "Disable", "value": 0.00},
  //   {"label": "25hz", "value": 25.00},
  //   {"label": "35hz", "value": 35.00},
  //   {"label": "50hz", "value": 50.00},
  //   {"label": "70hz", "value": 70.00},
  //   {"label": "100hz", "value": 100.00},
  //   {"label": "150hz", "value": 150.00},
  // ];
  int lowPassValue = 5;

  bool notchOnOf = false;

  List<dynamic> speedOptions = [
    {"label": "25mm/s", "value": 25},
    // {"label":"50mm/s", "value": 50},
    // {"label":"100mm/s", "value": 100},
  ];
  List<dynamic> comOptions = [
  ];

  var speedValue = 25;

  String recTime = "10s";
  String gridLine = "On";
  bool gridlineV = true;

  String appMode = "personal";
  SharedPreferences? prefs;

  var availablePorts = [];

  String com = "none";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }

  init() async {
    prefs = await SharedPreferences.getInstance();
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    // var res = await jsonDecode(prefs!.getString("user").toString());
    availablePorts = await SerialPort.availablePorts;
    print(availablePorts);
    var seen = <String>{}; // Set to track unique values
    var copts = availablePorts.where((e) => seen.add(e)).map((e) => {
      "label": e,
      "value": e
    }).toList();
    setState(() {

      comOptions = copts;
      print(comOptions);
      com = globalSettings.com.toString();
      if (com == null || com == "none") {
        com = comOptions.first["value"];
      }
      filterOnOff = globalSettings.filterOnOf;
      highPassValue = globalSettings.highPass;
      lowPassValue = globalSettings.lowPass;
      notchOnOf = globalSettings.notch;
      gridlineV = globalSettings.gridLine;
      appMode = globalSettings.appMode.toString();
      sampleRate =
          globalSettings.sampleRate != null
              ? globalSettings.sampleRate.toString()
              : '300';
      print("HRV S");
      globalSettings.setAppMode(appMode);
      if (globalSettings.gridLine == true) {
        gridLine = "On";
      } else {
        gridLine = "Off";
      }
    });
  }

  onChange() {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    globalSettings.setAll(
      autoRecordOnOff,
      filterOnOff,
      highPassValue,
      lowPassValue,
      notchOnOf,
      recTime,
      gridlineV,
      com,
    );
    globalSettings.setAppMode(appMode);

    globalSettings.setSampleRate(sampleRate.toString());
    print(autoRecordOnOff);
    print(globalSettings);
    String settingJson = globalSettings.toJson();
    prefs!.setString("globalSettings", settingJson);
    // widget.onChange({
    //   "filterOn": filterOnOff,
    //   "highPass": highPassValue,
    //   "lowPass": lowPassValue,
    //   "notch": notchOnOf,
    //   "speed": speedValue,
    // });
  }

  _filterOn() {
    if (filterOnOff == true) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Low Pass", style: TextStyle(fontSize: 20)),
              // SizedBox(width: 50,),
              DropdownButton<dynamic>(
                value: lowPassValue,
                items:
                    lowPassOptions.map((e) {
                      return DropdownMenuItem<dynamic>(
                        child: Text(e["label"]),
                        value: e["value"],
                      );
                    }).toList(),
                onChanged: (d) {
                  // print(d);
                  setState(() {
                    lowPassValue = d;
                  });
                  onChange();
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("High Pass", style: TextStyle(fontSize: 20)),
              // SizedBox(width: 50,),
              DropdownButton<dynamic>(
                value: highPassValue,
                items:
                    highPassOptions.map((e) {
                      return DropdownMenuItem<dynamic>(
                        child: Text(e["label"]),
                        value: e["value"],
                      );
                    }).toList(),
                onChanged: (d) {
                  // print(d);
                  setState(() {
                    highPassValue = d;
                  });
                  onChange();
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Notch", style: TextStyle(fontSize: 20)),
              // SizedBox(width: 50,),
              Switch(
                value: notchOnOf,
                onChanged: (d) {
                  setState(() {
                    notchOnOf = d;
                  });
                  onChange();
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Speed", style: TextStyle(fontSize: 20)),
              // SizedBox(width: 50,),
              DropdownButton<dynamic>(
                value: speedValue,
                items:
                    speedOptions.map((e) {
                      return DropdownMenuItem<dynamic>(
                        child: Text(e["label"]),
                        value: e["value"],
                      );
                    }).toList(),
                onChanged: (d) {
                  print(d);
                  setState(() {
                    speedValue = d;
                  });
                  onChange();
                },
              ),
            ],
          ),
        ],
      );
    }
    return Container();
  }

  _recordingTimeRadio() {
    return Container(
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // RadioListTile(
                //     title: Text("10 Seconds"),
                //     value: "10s",
                //     groupValue: recTime,
                //     onChanged: (v) {
                //       setState(() {
                //         recTime = v.toString();
                //       });
                //       onChange();
                //     }),
                RadioListTile(
                  title: Text("30 Seconds"),
                  value: "30s",
                  groupValue: recTime,
                  onChanged: (v) {
                    setState(() {
                      recTime = v.toString();
                    });
                    onChange();
                  },
                ),
                // RadioListTile(
                //     title: Text("20 Seconds"),
                //     value: "20s",
                //     groupValue: recTime,
                //     onChanged: (v) {
                //       setState(() {
                //         recTime = v.toString();
                //       });
                //       onChange();
                //     }),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                RadioListTile(
                  title: Text("5 Minute"),
                  value: "5m",
                  groupValue: recTime,
                  onChanged: (v) {
                    setState(() {
                      recTime = v.toString();
                    });
                    onChange();
                  },
                ),
                RadioListTile(
                  title: Text("1 Hour"),
                  value: "1h",
                  groupValue: recTime,
                  onChanged: (v) {
                    setState(() {
                      recTime = v.toString();
                    });
                    onChange();
                  },
                ),
                RadioListTile(
                  title: Text("24 Hours"),
                  value: "24h",
                  groupValue: recTime,
                  onChanged: (v) {
                    //snack bar notification

                    // setState(() {
                    //   recTime = v.toString();
                    // });
                    // onChange();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  gridLineRadio() {
    return Container(
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                RadioListTile(
                  title: Text("Off"),
                  value: "Off",
                  groupValue: gridLine,
                  onChanged: (v) {
                    setState(() {
                      gridlineV = false;
                      gridLine = v.toString();
                    });
                    onChange();
                  },
                ),
                RadioListTile(
                  title: Text("On"),
                  value: "On",
                  groupValue: gridLine,
                  onChanged: (v) {
                    setState(() {
                      gridlineV = true;
                      gridLine = v.toString();
                    });
                    onChange();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // selectMode(mode) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   ApiRoute apiRoute = ApiRoute();
  //   var req = await apiRoute
  //       .postResponseFromRoute("mobile_user_api_select_mode", body: {
  //     "appMode": mode,
  //   });
  //   var res = await jsonDecode(req.body);
  //   String usrStr = jsonEncode(res["data"]);
  //   prefs.setString("user", usrStr);
  // }

  _version() {
    return Container(
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("Version", style: TextStyle(fontSize: 20)),
                // SizedBox(width: 50,),
                // Text(Package),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _sampleRateWidget() {
    return Container(
      margin: EdgeInsets.only(top: 10, bottom: 10, left: 10, right: 10),

      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Column(
            children: [
              Column(
                children: [
                  Column(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  "Sample Rate",
                                  style: TextStyle(fontSize: 15),
                                ),
                                // Text(sampleRate),
                                DropdownButton<String>(
                                  value: sampleRate,
                                  hint: Text('Select an Option'),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: '300',
                                      child: Text('300'),
                                    ),
                                    DropdownMenuItem<String>(
                                      value: '1000',
                                      child: Text('1000'),
                                    ),
                                  ],
                                  onChanged:
                                      (value) => {
                                        this.setState(() {
                                          sampleRate = value.toString();
                                        }),
                                        onChange(),
                                      },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings"), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // _version(),
            // SizedBox(
            //   height: 10,
            // ),
            SizedBox(height: 10),
            // Text(
            //   "Auto Record",
            //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            // ),
            Container(
              margin: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text("Auto Record", style: TextStyle(fontSize: 20)),
                        // SizedBox(width: 50,),
                        Switch(
                          value: autoRecordOnOff,
                          onChanged: (d) {
                            setState(() {
                              autoRecordOnOff = d;
                            });
                            onChange();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Container(
                  //   child: Row(
                  //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  //     children: [
                  //       Text(
                  //         "Auto Play (Not operational)",
                  //         style: TextStyle(fontSize: 20),
                  //       ),
                  //       // SizedBox(width: 50,),
                  //       Switch(
                  //           value: false,
                  //           onChanged: (d) {
                  //             setState(() {
                  //               // autoRecordOnOff = d;
                  //             });
                  //             onChange();
                  //           }),
                  //     ],
                  //   ),
                  // ),
                  // _filterOn(),
                ],
              ),
            ),
            Text(
              "Filters",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            ),
            Container(
              margin: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text("Filter", style: TextStyle(fontSize: 20)),
                        // SizedBox(width: 50,),
                        Switch(
                          value: filterOnOff,
                          onChanged: (d) {
                            setState(() {
                              filterOnOff = d;
                            });
                            onChange();
                          },
                        ),
                      ],
                    ),
                  ),
                  _filterOn(),
                ],
              ),
            ),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  "COM Port",
                  style: TextStyle(fontSize: 20),
                ),
                // SizedBox(width: 50,),
                DropdownButton<dynamic>(
                    value: com,
                    items: comOptions.map((e) {
                      return DropdownMenuItem<dynamic>(
                        child: Text(e["label"]),
                        value: e["value"],
                      );
                    }).toList(),
                    onChanged: (d) {
                      // print(d);
                      setState(() {
                        com = d;
                      });
                      onChange();
                    }),
              ],
            ),
            Divider(),
            SizedBox(height: 10),
            // Text(
            //   "Sample Rate",
            //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            // ),
            // _sampleRateWidget()
            // Text(
            //   "Grid Lines",
            //   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
            // ),
            // gridLineRadio(),
          ],
        ),
      ),
    );
  }
}
