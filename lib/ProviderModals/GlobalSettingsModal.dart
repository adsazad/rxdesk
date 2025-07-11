import 'dart:convert';

import 'package:flutter/material.dart';

class GlobalSettingsModal with ChangeNotifier {
  bool autoRecordOnOff = true;
  bool filterOnOf = true;

  int highPass = 0;
  int lowPass = 0;
  bool notch = false;
  bool gridLine = true;

  double voltage1 = 0.96;
  double value1 = 20.93;

  double voltage2 = 0.77;
  double value2 = 15.93;
  String? appMode = "personal";
  String? sampleRate = '300';

  String? com = "none";
  bool applyConversion = false;

  double flowCalPlus = 0.0;
  double flowCalMinus = 0.0;

  GlobalSettingsModal({
    required this.com,
    required this.autoRecordOnOff,
    required this.filterOnOf,
    required this.highPass,
    required this.lowPass,
    required this.notch,
    required this.gridLine,
    required voltage1,
    required value1,
    required voltage2,
    required value2,
    this.appMode,
    this.sampleRate,
    required this.applyConversion,
    this.flowCalPlus = 0.0,
    this.flowCalMinus = 0.0,
  });

  void setAutoRecordOnOff(bool value) {
    autoRecordOnOff = value;
    notifyListeners();
  }

  void setFilterOnOf(bool value) {
    filterOnOf = value;
    notifyListeners();
  }

  void setHighPass(int value) {
    highPass = value;
    notifyListeners();
  }

  void setSampleRate(String value) {
    sampleRate = value;
    notifyListeners();
  }

  void setapplyConversion(bool val) {
    if (applyConversion != val) {
      applyConversion = val;
      notifyListeners(); // ✅ this triggers UI refresh wherever Consumer is used
    }
  }

  void setLowPass(int value) {
    lowPass = value;
    notifyListeners();
  }

  void setNotch(bool value) {
    notch = value;
    notifyListeners();
  }

  void setAppMode(String appMode) {
    this.appMode = appMode;
    notifyListeners();
  }

  void setFlowCalPlus(double value) {
    flowCalPlus = value;
    notifyListeners();
  }

  void setFlowCalMinus(double value) {
    flowCalMinus = value;
    notifyListeners();
  }

  void setAll(
    bool autoRecordOnOff,
    bool filterOnOf,
    int highPass,
    int lowPass,
    bool notch,
    recTime,
    bool gridLine,
    String com,
    double? voltage1,
    double value1,
    double voltage2,
    double value2,
    bool applyConversion,
    double flowCalPlus,
    double flowCalMinus,
  ) {
    this.autoRecordOnOff = autoRecordOnOff;
    this.filterOnOf = filterOnOf;
    this.highPass = highPass;
    this.lowPass = lowPass;
    this.notch = notch;
    this.gridLine = gridLine;
    this.com = com;
    this.voltage1 = voltage1!;
    this.value1 = value1;
    this.voltage2 = voltage2;
    this.value2 = value2;
    this.applyConversion = applyConversion;
    this.flowCalPlus = flowCalPlus;
    this.flowCalMinus = flowCalMinus;
    notifyListeners();
  }

  toJson() {
    Map<String, dynamic> json = {
      "autoRecordOnOff": autoRecordOnOff,
      "filterOnOf": filterOnOf,
      "highPass": highPass,
      "lowPass": lowPass,
      "notch": notch,
      "gridLine": gridLine,
      "appMode": appMode,
      "sampleRate": sampleRate,
      "com": com,
      "voltage1": voltage1,
      "value1": value1,
      "voltage2": voltage2,
      "value2": value2,
      "applyConversion": applyConversion,
      "flowCalPlus": flowCalPlus,
      "flowCalMinus": flowCalMinus,
    };
    String jsonString = jsonEncode(json);
    return jsonString;
  }

  fromJson(json) {
    var arr = jsonDecode(json);
    autoRecordOnOff = arr["autoRecordOnOff"];
    filterOnOf = arr["filterOnOf"];
    highPass = arr["highPass"];
    lowPass = arr["lowPass"];
    notch = arr["notch"];
    gridLine = arr["gridLine"];
    appMode = arr["appMode"];
    sampleRate = arr['sampleRate'];
    if (arr["com"] != null) {
      com = arr["com"];
    }
    voltage1 = arr["voltage1"];
    value1 = arr["value1"];
    voltage2 = arr["voltage2"];
    value2 = arr["value2"];
    applyConversion = arr['applyConversion'];
    flowCalPlus = arr["flowCalPlus"] ?? 0.0;
    flowCalMinus = arr["flowCalMinus"] ?? 0.0;

    // if(arr["hrvDuration"]) {
    // }else{
    //   hrvDuration = "300";
    // }
    notifyListeners();
  }
}
