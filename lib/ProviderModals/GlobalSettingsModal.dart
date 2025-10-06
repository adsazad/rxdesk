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
  String ergoProtocol =
      "Ramp Protocol"; // "Ramp Protocol", "Incremental Step Protocol"
  String treadmillProtocol = "Bruce"; // "Bruce", "Modified Bruce"

  String atDetectionMethod =
      "VO2 max"; // "VO2 max", "VE/VO₂ increases while VE/VCO₂ remains stable or decreases", "Manually mark"

  int transportDelayMs = 0; // Transport delay in milliseconds
  int transportDelayO2Ms = 0; // Transport delay for O2 in milliseconds
  int transportDelayCO2Ms = 0; // Transport delay for CO2 in milliseconds

  bool breathCalibrationMarker = false;

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
    this.transportDelayMs = 0,
    this.transportDelayO2Ms = 0,
    this.transportDelayCO2Ms = 0,
    this.breathCalibrationMarker = false,
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

  void setTransportDelayMs(int value) {
    transportDelayMs = value;
    notifyListeners();
  }

  void setTransportDelayO2Ms(int value) {
    transportDelayO2Ms = value;
    notifyListeners();
  }

  void setTransportDelayCO2Ms(int value) {
    transportDelayCO2Ms = value;
    notifyListeners();
  }

  void setBreathCalibrationMarker(bool value) {
    breathCalibrationMarker = value;
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
      "transportDelayMs": transportDelayMs,
      "transportDelayO2Ms": transportDelayO2Ms,
      "transportDelayCO2Ms": transportDelayCO2Ms,
      "breathCalibrationMarker": breathCalibrationMarker,
    };
    String jsonString = jsonEncode(json);
    return jsonString;
  }

  fromJson(json) {
    final dynamic parsed = (json is String) ? jsonDecode(json) : json;
    if (parsed is! Map) {
      notifyListeners();
      return;
    }
    final Map<String, dynamic> arr = Map<String, dynamic>.from(parsed);

    autoRecordOnOff = _toBool(arr["autoRecordOnOff"], autoRecordOnOff);
    filterOnOf = _toBool(arr["filterOnOf"], filterOnOf);
    highPass = _toInt(arr["highPass"], highPass);
    lowPass = _toInt(arr["lowPass"], lowPass);
    notch = _toBool(arr["notch"], notch);
    gridLine = _toBool(arr["gridLine"], gridLine);
    appMode = arr["appMode"]?.toString() ?? appMode;
    sampleRate = arr['sampleRate']?.toString() ?? sampleRate;
    if (arr["com"] != null) {
      com = arr["com"];
    }
    voltage1 = _toDouble(arr["voltage1"], voltage1);
    value1 = _toDouble(arr["value1"], value1);
    voltage2 = _toDouble(arr["voltage2"], voltage2);
    value2 = _toDouble(arr["value2"], value2);
    applyConversion = _toBool(arr['applyConversion'], applyConversion);
    tidalMeasuredReference = _toDouble(
      arr["tidalMeasuredReference"],
      tidalMeasuredReference,
    );
    tidalActualReference = _toDouble(
      arr["tidalActualReference"],
      tidalActualReference,
    );
    tidalScalingFactor = _toDouble(
      arr["tidalScalingFactor"],
      tidalScalingFactor,
    );
    hospitalName = arr["hospitalName"]?.toString() ?? hospitalName;
    hospitalAddress = arr["hospitalAddress"]?.toString() ?? hospitalAddress;
    hospitalContact = arr["hospitalContact"]?.toString() ?? hospitalContact;
    hospitalEmail = arr["hospitalEmail"]?.toString() ?? hospitalEmail;
    deviceType = arr["deviceType"]?.toString() ?? deviceType;
    machineCom = arr["machineCom"]?.toString() ?? machineCom;
    ergoProtocol = arr["ergoProtocol"]?.toString() ?? ergoProtocol;
    treadmillProtocol =
        arr["treadmillProtocol"]?.toString() ?? treadmillProtocol;
    atDetectionMethod =
        arr["atDetectionMethod"]?.toString() ?? atDetectionMethod;
    transportDelayMs = _toInt(arr["transportDelayMs"], transportDelayMs);
    transportDelayO2Ms = _toInt(arr["transportDelayO2Ms"], transportDelayO2Ms);
    transportDelayCO2Ms = _toInt(
      arr["transportDelayCO2Ms"],
      transportDelayCO2Ms,
    );
    breathCalibrationMarker = _toBool(
      arr["breathCalibrationMarker"],
      breathCalibrationMarker,
    );

    notifyListeners();
  }

  // --- Safe converters ----------------------------------------------------
  bool _toBool(dynamic v, bool fallback) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  int _toInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _toDouble(dynamic v, double fallback) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }
}
