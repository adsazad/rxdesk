import 'package:flutter/material.dart';

class ImportFileProvider extends ChangeNotifier {
  String? _filePath;
  int? _recordingId;

  String? get filePath => _filePath;
  int? get recordingId => _recordingId;

  void setFilePath(String path) {
    _filePath = path;
    notifyListeners();
  }

  void setRecordingId(int id) {
    _recordingId = id;
    notifyListeners();
  }

  void clear() {
    _filePath = null;
    _recordingId = null;
    notifyListeners();
  }
}
