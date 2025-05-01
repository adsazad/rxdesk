import 'dart:convert';

import 'package:flutter/material.dart';

class GlobalSettingsModal with ChangeNotifier {
  bool autoRecordOnOff = true;
  bool filterOnOf = true;

  int highPass = 0;
  int lowPass = 0;
  bool notch = false;
  bool gridLine = true;


  String? appMode = "personal";
  String? sampleRate = '300';

  String? com = "none";

  GlobalSettingsModal({
    required this.com,
    required this.autoRecordOnOff,
    required this.filterOnOf,
    required this.highPass,
    required this.lowPass,
    required this.notch,
    required this.gridLine,
    this.appMode,
    this.sampleRate
  });

  void setAutoRecordOnOff(bool value){
    autoRecordOnOff = value;
    notifyListeners();
  }

  void setFilterOnOf(bool value){
    filterOnOf = value;
    notifyListeners();
  }

  void setHighPass(int value){
    highPass = value;
    notifyListeners();
  }

  void setSampleRate(String value){
    sampleRate = value;
    notifyListeners();
  }

  void setLowPass(int value){
    lowPass = value;
    notifyListeners();
  }

  void setNotch(bool value){
    notch = value;
    notifyListeners();
  }

  void setAppMode(String appMode){
    this.appMode = appMode;
    notifyListeners();
  }

  void setAll(bool autoRecordOnOff,bool filterOnOf, int highPass, int lowPass, bool notch,recTime,bool gridLine,String com){
    this.autoRecordOnOff = autoRecordOnOff;
    this.filterOnOf = filterOnOf;
    this.highPass = highPass;
    this.lowPass = lowPass;
    this.notch = notch;
    this.gridLine = gridLine;
    this.com  = com;
    notifyListeners();
  }

  toJson(){
    Map<String, dynamic> json = {
      "autoRecordOnOff": autoRecordOnOff,
      "filterOnOf": filterOnOf,
      "highPass": highPass,
      "lowPass": lowPass,
      "notch": notch,
      "gridLine": gridLine,
      "appMode": appMode,
      "sampleRate" : sampleRate,
      "com":com
    };
    String jsonString = jsonEncode(json);
    return jsonString;
  }

  fromJson(json){
    var arr = jsonDecode(json);
    autoRecordOnOff = arr["autoRecordOnOff"];
    filterOnOf = arr["filterOnOf"];
    highPass = arr["highPass"];
    lowPass = arr["lowPass"];
    notch = arr["notch"];
    gridLine = arr["gridLine"];
    appMode = arr["appMode"];
    sampleRate = arr['sampleRate'];
    if(arr["com"] != null){
    com = arr["com"];
    }

    // if(arr["hrvDuration"]) {
    // }else{
    //   hrvDuration = "300";
    // }
    notifyListeners();
  }

}