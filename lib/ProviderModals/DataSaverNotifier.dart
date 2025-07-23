import 'package:flutter/material.dart';
import 'package:spirobtvo/Services/DataSaver.dart';

class DataSaverNotifier extends ChangeNotifier {
  DataSaver _dataSaver = DataSaver();

  DataSaver get dataSaver => _dataSaver;

  void setDataSaver(DataSaver newSaver) {
    _dataSaver = newSaver;
    notifyListeners();
  }
}
