import 'package:flutter/material.dart';

class ImportFileProvider extends ChangeNotifier {
  String? _filePath;

  String? get filePath => _filePath;

  void setFilePath(String path) {
    _filePath = path;
    notifyListeners();
  }

  void clear() {
    _filePath = null;
    notifyListeners();
  }
}
