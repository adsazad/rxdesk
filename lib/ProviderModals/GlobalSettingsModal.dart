import 'dart:convert';

import 'package:flutter/material.dart';

class GlobalSettingsModal with ChangeNotifier {
  String hospitalName = '';
  String hospitalAddress = '';
  String hospitalContact = '';
  String hospitalEmail = '';
  // Prescription print settings
  bool printHeader = true;
  bool printFooter = false;
  String footerText = '';
  double marginTopMm = 15;
  double marginBottomMm = 15;
  double marginLeftMm = 12;
  double marginRightMm = 12;
  // Header logo & positioning
  String logoPath = '';
  String headerLogoAlignment = 'left'; // left, center, right
  // Doctor details & signature
  String doctorName = '';
  String doctorRegistration = '';
  bool showSignatureLine = true;
  // Paper presets
  String paperSize = 'A4'; // A4 or Letter
  String orientation = 'portrait'; // portrait or landscape

  GlobalSettingsModal({
    this.hospitalName = '',
    this.hospitalAddress = '',
    this.hospitalContact = '',
    this.hospitalEmail = '',
    this.printHeader = true,
    this.printFooter = false,
    this.footerText = '',
    this.marginTopMm = 15,
    this.marginBottomMm = 15,
    this.marginLeftMm = 12,
    this.marginRightMm = 12,
    this.logoPath = '',
    this.headerLogoAlignment = 'left',
    this.doctorName = '',
    this.doctorRegistration = '',
    this.showSignatureLine = true,
    this.paperSize = 'A4',
    this.orientation = 'portrait',
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

  // Print settings setters
  void setPrintHeader(bool value) {
    printHeader = value;
    notifyListeners();
  }

  void setLogoPath(String value) {
    logoPath = value;
    notifyListeners();
  }

  void setHeaderLogoAlignment(String value) {
    headerLogoAlignment = value;
    notifyListeners();
  }

  void setDoctorName(String value) {
    doctorName = value;
    notifyListeners();
  }

  void setDoctorRegistration(String value) {
    doctorRegistration = value;
    notifyListeners();
  }

  void setShowSignatureLine(bool value) {
    showSignatureLine = value;
    notifyListeners();
  }

  void setPaperSize(String value) {
    paperSize = value;
    notifyListeners();
  }

  void setOrientation(String value) {
    orientation = value;
    notifyListeners();
  }

  void setPrintFooter(bool value) {
    printFooter = value;
    notifyListeners();
  }

  void setFooterText(String value) {
    footerText = value;
    notifyListeners();
  }

  void setMargins({double? topMm, double? bottomMm, double? leftMm, double? rightMm}) {
    if (topMm != null) marginTopMm = topMm;
    if (bottomMm != null) marginBottomMm = bottomMm;
    if (leftMm != null) marginLeftMm = leftMm;
    if (rightMm != null) marginRightMm = rightMm;
    notifyListeners();
  }

  String toJson() {
    return jsonEncode({
      'hospitalName': hospitalName,
      'hospitalAddress': hospitalAddress,
      'hospitalContact': hospitalContact,
      'hospitalEmail': hospitalEmail,
      'printHeader': printHeader,
      'printFooter': printFooter,
      'footerText': footerText,
      'marginTopMm': marginTopMm,
      'marginBottomMm': marginBottomMm,
      'marginLeftMm': marginLeftMm,
      'marginRightMm': marginRightMm,
      'logoPath': logoPath,
      'headerLogoAlignment': headerLogoAlignment,
      'doctorName': doctorName,
      'doctorRegistration': doctorRegistration,
      'showSignatureLine': showSignatureLine,
      'paperSize': paperSize,
      'orientation': orientation,
    });
  }

  factory GlobalSettingsModal.fromJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return GlobalSettingsModal(
      hospitalName: data['hospitalName'] ?? '',
      hospitalAddress: data['hospitalAddress'] ?? '',
      hospitalContact: data['hospitalContact'] ?? '',
      hospitalEmail: data['hospitalEmail'] ?? '',
      printHeader: data['printHeader'] ?? true,
      printFooter: data['printFooter'] ?? false,
      footerText: data['footerText'] ?? '',
      marginTopMm: (data['marginTopMm'] ?? 15).toDouble(),
      marginBottomMm: (data['marginBottomMm'] ?? 15).toDouble(),
      marginLeftMm: (data['marginLeftMm'] ?? 12).toDouble(),
      marginRightMm: (data['marginRightMm'] ?? 12).toDouble(),
      logoPath: data['logoPath'] ?? '',
      headerLogoAlignment: data['headerLogoAlignment'] ?? 'left',
      doctorName: data['doctorName'] ?? '',
      doctorRegistration: data['doctorRegistration'] ?? '',
      showSignatureLine: data['showSignatureLine'] ?? true,
      paperSize: data['paperSize'] ?? 'A4',
      orientation: data['orientation'] ?? 'portrait',
    );
  }
}
