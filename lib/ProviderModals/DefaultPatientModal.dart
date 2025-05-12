import 'dart:convert';
import 'package:flutter/material.dart';

class DefaultPatientModal with ChangeNotifier {
  Map<String, dynamic>? _patient;

  Map<String, dynamic>? get patient => _patient;

  bool get hasDefault => _patient != null;

  void setDefault(Map<String, dynamic> patient) {
    _patient = patient;
    notifyListeners();
  }

  void clear() {
    _patient = null;
    notifyListeners();
  }

  String toJson() {
    return jsonEncode(_patient ?? {});
  }

  void fromJson(String jsonString) {
    final decoded = jsonDecode(jsonString);
    _patient = Map<String, dynamic>.from(decoded);
    notifyListeners();
  }
}
