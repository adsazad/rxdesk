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
  List<dynamic> comOptions = [];
  TextEditingController voltage1Controller = TextEditingController();
  TextEditingController value1Controller = TextEditingController();
  TextEditingController voltage2Controller = TextEditingController();
  TextEditingController value2Controller = TextEditingController();
  TextEditingController flowCalPlusController = TextEditingController();
  TextEditingController flowCalMinusController = TextEditingController();
  TextEditingController tidalMeasuredController = TextEditingController();
  TextEditingController tidalActualController = TextEditingController();
  TextEditingController hospitalNameController = TextEditingController();
  TextEditingController hospitalAddressController = TextEditingController();
  TextEditingController hospitalContactController = TextEditingController();
  TextEditingController hospitalEmailController = TextEditingController();

  var speedValue = 25;

  String recTime = "10s";
  String gridLine = "On";
  bool gridlineV = true;

  String appMode = "personal";
  SharedPreferences? prefs;

  var availablePorts = [];

  String com = "none";
  bool applyConversion = false;

  final List<String> atDetectionOptions = [
    "VO2 max",
    // "VE/VO₂ increases while VE/VCO₂ remains stable or decreases",
    // "Manually mark",
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }

  @override
  void dispose() {
    voltage1Controller.dispose();
    value1Controller.dispose();
    voltage2Controller.dispose();
    value2Controller.dispose();
    tidalMeasuredController.dispose();
    tidalActualController.dispose();
    hospitalNameController.dispose();
    hospitalAddressController.dispose();
    hospitalContactController.dispose();
    hospitalEmailController.dispose();
    super.dispose();
  }

  init() async {
    prefs = await SharedPreferences.getInstance();
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    availablePorts = await SerialPort.availablePorts;
    var seen = <String>{};
    var copts =
        availablePorts
            .where((e) => seen.add(e))
            .map((e) => {"label": e, "value": e})
            .toList();

    // Ensure "none" is present only once at the start
    copts.removeWhere((e) => e["value"] == "none");
    copts.insert(0, {"label": "None", "value": "none"});

    setState(() {
      comOptions = copts;

      // Set com only if it's available in comOptions, otherwise default to first option
      String selectedCom = globalSettings.com?.toString() ?? "none";
      bool found = comOptions.any((e) => e["value"] == selectedCom);
      com = found ? selectedCom : comOptions.first["value"];

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
    voltage1Controller = TextEditingController(
      text: (globalSettings.voltage1 ?? 0.96).toString(),
    );
    value1Controller = TextEditingController(
      text: globalSettings.value1.toString(),
    );
    voltage2Controller = TextEditingController(
      text: globalSettings.voltage2.toString(),
    );
    value2Controller = TextEditingController(
      text: globalSettings.value2.toString(),
    );
    tidalMeasuredController = TextEditingController(
      text: globalSettings.tidalMeasuredReference.toString(),
    );
    tidalActualController = TextEditingController(
      text: globalSettings.tidalActualReference.toString(),
    );
    hospitalNameController.text = globalSettings.hospitalName;
    hospitalAddressController.text = globalSettings.hospitalAddress;
    hospitalContactController.text = globalSettings.hospitalContact;
    hospitalEmailController.text = globalSettings.hospitalEmail;
    applyConversion = globalSettings.applyConversion;
    print("voltage1");
    print(voltage1Controller.text);
  }

  onChange() {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    // Calculate scaling factor automatically
    double measured = double.tryParse(tidalMeasuredController.text) ?? 0.0;
    double actual = double.tryParse(tidalActualController.text) ?? 0.0;
    double scaling = measured != 0 ? actual / measured : 1.0;

    globalSettings.setAll(
      autoRecordOnOff,
      filterOnOff,
      highPassValue,
      lowPassValue,
      notchOnOf,
      recTime,
      gridlineV,
      com,
      double.parse(voltage1Controller.text),
      double.parse(value1Controller.text),
      double.parse(voltage2Controller.text),
      double.parse(value2Controller.text),
      applyConversion,
      measured,
      actual,
      scaling,
    );
    globalSettings.setAppMode(appMode);

    globalSettings.setSampleRate(sampleRate.toString());
    globalSettings.setapplyConversion(applyConversion);
    print(autoRecordOnOff);
    print(globalSettings);
    String settingJson = globalSettings.toJson();
    prefs!.setString("globalSettings", settingJson);
  }

  void saveHospitalInfo() {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    globalSettings.setHospitalName(hospitalNameController.text.trim());
    globalSettings.setHospitalAddress(hospitalAddressController.text.trim());
    globalSettings.setHospitalContact(hospitalContactController.text.trim());
    globalSettings.setHospitalEmail(hospitalEmailController.text.trim());
    prefs?.setString("globalSettings", globalSettings.toJson());
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

  Widget _deviceSettingsTab() {
    final globalSettings = Provider.of<GlobalSettingsModal>(context);
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 10),
          Container(
            margin: EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // Hardware COM Port Dropdown (always enabled)
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Hardware COM Port",
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<dynamic>(
                          value: com,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items:
                              comOptions.map((e) {
                                return DropdownMenuItem<dynamic>(
                                  child: Text(e["label"]),
                                  value: e["value"],
                                );
                              }).toList(),
                          onChanged: (d) {
                            setState(() {
                              com = d;
                            });
                            onChange();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Device Type Dropdown
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Device Type",
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: globalSettings.deviceType,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: "none",
                              child: Text("None"),
                            ),
                            DropdownMenuItem(
                              value: "ergoCycle",
                              child: Text("Ergo Cycle"),
                            ),
                            DropdownMenuItem(
                              value: "treadmill",
                              child: Text("Treadmill"),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              globalSettings.setDeviceType(val!);
                            });
                            onChange();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Machine COM Port Dropdown (enabled only if deviceType != "none")
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "Machine COM Port",
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<dynamic>(
                          value: globalSettings.machineCom,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items:
                              comOptions.map((e) {
                                return DropdownMenuItem<dynamic>(
                                  child: Text(e["label"]),
                                  value: e["value"],
                                );
                              }).toList(),
                          onChanged:
                              globalSettings.deviceType == "none"
                                  ? null
                                  : (d) {
                                    setState(() {
                                      globalSettings.setMachineCom(d);
                                    });
                                    onChange();
                                  },
                          disabledHint: Text("Select Device Type"),
                        ),
                      ),
                    ],
                  ),
                ),
                // Ergo Protocol Dropdown (only if deviceType == "ergoCycle")
                if (globalSettings.deviceType == "ergoCycle")
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Ergo Protocol",
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: globalSettings.ergoProtocol,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: "ramp_protocol",
                                child: Text("Ramp Protocol"),
                              ),
                              DropdownMenuItem(
                                value: "incremental_step_protocol",
                                child: Text("Incremental Step Protocol"),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                globalSettings.setErgoProtocol(val!);
                              });
                              onChange();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                // Treadmill Protocol Dropdown (only if deviceType == "treadmill")
                if (globalSettings.deviceType == "treadmill")
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            "Treadmill Protocol",
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: globalSettings.treadmillProtocol,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: "bruce_protocol",
                                child: Text("Bruce"),
                              ),
                              DropdownMenuItem(
                                value: "modified_bruce_protocol",
                                child: Text("Modified Bruce"),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                globalSettings.setTreadmillProtocol(val!);
                              });
                              onChange();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Settings"),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(
                text: "Device Settings",
                icon: Icon(Icons.settings, color: Colors.white),
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                text: "Others Settings",
                icon: Icon(Icons.settings, color: Colors.white),
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                text: "Hospital Info",
                icon: Icon(Icons.local_hospital, color: Colors.white),
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[400],
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: [
            _deviceSettingsTab(), // Device Settings tab
            // Tab 2: Other Settings (existing content)
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 10),
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
                              Text(
                                "Auto Record",
                                style: TextStyle(fontSize: 20),
                              ),
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
                  SizedBox(height: 10),
                  Container(
                    margin: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Transport Delay O₂ (ms)",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Consumer<GlobalSettingsModal>(
                                builder: (context, globalSettings, child) {
                                  return SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      initialValue:
                                          globalSettings.transportDelayO2Ms
                                              .toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        int value = int.tryParse(val) ?? 0;
                                        globalSettings.setTransportDelayO2Ms(
                                          value,
                                        );
                                        onChange();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Transport Delay CO₂ (ms)",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Consumer<GlobalSettingsModal>(
                                builder: (context, globalSettings, child) {
                                  return SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      initialValue:
                                          globalSettings.transportDelayCO2Ms
                                              .toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        int value = int.tryParse(val) ?? 0;
                                        globalSettings.setTransportDelayCO2Ms(
                                          value,
                                        );
                                        onChange();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    margin: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "AT Point Detection Method",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Consumer<GlobalSettingsModal>(
                            builder: (context, globalSettings, child) {
                              return DropdownButton<String>(
                                value: globalSettings.atDetectionMethod,
                                items:
                                    atDetectionOptions
                                        .map(
                                          (e) => DropdownMenuItem<String>(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    globalSettings.setAtDetectionMethod(val);
                                    setState(() {}); // To update UI if needed
                                    onChange();
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Add this inside the "Other Settings" tab, after the AT Point Detection Method setting:
                ],
              ),
            ),
            // Tab 2: Hospital Info
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Hospital Information",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: hospitalNameController,
                      decoration: InputDecoration(
                        labelText: "Hospital Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: hospitalAddressController,
                      decoration: InputDecoration(
                        labelText: "Address",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: hospitalContactController,
                      decoration: InputDecoration(
                        labelText: "Contact Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: hospitalEmailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        saveHospitalInfo();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Hospital info saved!")),
                        );
                      },
                      child: Text("Save"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
