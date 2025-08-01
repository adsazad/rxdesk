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

  double tidalMeasuredReference = 0.0;
  double tidalActualReference = 0.0;
  double tidalScalingFactor = 1.0;

  String hospitalName = '';
  String hospitalAddress = '';
  String hospitalContact = '';
  String hospitalEmail = '';

  String deviceType = "none"; // "none", "ergoCycle", "treadmill"
  String machineCom = "none";
  String ergoProtocol = "Ramp Protocol"; // "Ramp Protocol", "Incremental Step Protocol"
  String treadmillProtocol = "Bruce"; // "Bruce", "Modified Bruce"

  String atDetectionMethod = "VO2 max"; // "VO2 max", "VE/VO₂ increases while VE/VCO₂ remains stable or decreases", "Manually mark"

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
    this.tidalMeasuredReference = 0.0,
    this.tidalActualReference = 0.0,
    this.tidalScalingFactor = 1.0,
    this.hospitalName = '',
    this.hospitalAddress = '',
    this.hospitalContact = '',
    this.hospitalEmail = '',
    this.deviceType = "none",
    this.machineCom = "none",
    this.ergoProtocol = "Ramp Protocol",
    this.treadmillProtocol = "Bruce",
    this.atDetectionMethod = "VO2 max",
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

  void setTidalMeasuredReference(double value) {
    tidalMeasuredReference = value;
    notifyListeners();
  }

  void setTidalActualReference(double value) {
    tidalActualReference = value;
    notifyListeners();
  }

  void setTidalScalingFactor(double value) {
    tidalScalingFactor = value;
    notifyListeners();
  }

  void setHospitalName(String value) {
    hospitalName = value;
    notifyListeners();
  }

  void setHospitalAddress(String value) {
    hospitalAddress = value;
    notifyListeners();
  }

  void setHospitalContact(String value) {
    hospitalContact = value;
    notifyListeners();
  }

  void setHospitalEmail(String value) {
    hospitalEmail = value;
    notifyListeners();
  }

  void setDeviceType(String value) {
    deviceType = value;
    notifyListeners();
  }

  void setMachineCom(String value) {
    machineCom = value;
    notifyListeners();
  }

  void setErgoProtocol(String value) {
    ergoProtocol = value;
    notifyListeners();
  }

  void setTreadmillProtocol(String value) {
    treadmillProtocol = value;
    notifyListeners();
  }

  void setAtDetectionMethod(String value) {
    atDetectionMethod = value;
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
    double tidalMeasuredReference,
    double tidalActualReference,
    double tidalScalingFactor,
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
    this.tidalMeasuredReference = tidalMeasuredReference;
    this.tidalActualReference = tidalActualReference;
    this.tidalScalingFactor = tidalScalingFactor;
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
      "tidalMeasuredReference": tidalMeasuredReference,
      "tidalActualReference": tidalActualReference,
      "tidalScalingFactor": tidalScalingFactor,
      "hospitalName": hospitalName,
      "hospitalAddress": hospitalAddress,
      "hospitalContact": hospitalContact,
      "hospitalEmail": hospitalEmail,
      "deviceType": deviceType,
      "machineCom": machineCom,
      "ergoProtocol": ergoProtocol,
      "treadmillProtocol": treadmillProtocol,
      "atDetectionMethod": atDetectionMethod,
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
    tidalMeasuredReference = arr["tidalMeasuredReference"] ?? 0.0;
    tidalActualReference = arr["tidalActualReference"] ?? 0.0;
    tidalScalingFactor = arr["tidalScalingFactor"] ?? 1.0;
    hospitalName = arr["hospitalName"] ?? '';
    hospitalAddress = arr["hospitalAddress"] ?? '';
    hospitalContact = arr["hospitalContact"] ?? '';
    hospitalEmail = arr["hospitalEmail"] ?? '';
    deviceType = arr["deviceType"] ?? "none";
    machineCom = arr["machineCom"] ?? "none";
    ergoProtocol = arr["ergoProtocol"] ?? "Ramp Protocol";
    treadmillProtocol = arr["treadmillProtocol"] ?? "Bruce";
    atDetectionMethod = arr["atDetectionMethod"] ?? "VO2 max";

    notifyListeners();
  }
}
