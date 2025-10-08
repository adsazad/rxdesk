import 'dart:convert';

import 'package:flutter/material.dart';

class GlobalSettingsModal with ChangeNotifier {
  String hospitalName = '';
  String hospitalAddress = '';
  String hospitalContact = '';
  String hospitalEmail = '';

  GlobalSettingsModal({
    this.hospitalName = '',
    this.hospitalAddress = '',
    this.hospitalContact = '',
    this.hospitalEmail = '',
  });

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

  String toJson() {
    return jsonEncode({
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'hospitalContact': hospitalContact,
      'hospitalEmail': hospitalEmail,
    });
  }

  factory GlobalSettingsModal.fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return GlobalSettingsModal(
      hospitalName: data['hospitalName'] ?? '',
      hospitalAddress: data['hospitalAddress'] ?? '',
      hospitalContact: data['hospitalContact'] ?? '',
      hospitalEmail: data['hospitalEmail'] ?? '',
    );
  }
}