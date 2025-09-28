import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;

class StandardScaler {
  List<double> mean;
  List<double> scale;

  StandardScaler({required this.mean, required this.scale});

  // Method to load scaler parameters from JSON file
  static Future<StandardScaler> fromJsonFile(String filePath) async {
    // final file = File(filePath);
    final jsonString = await rootBundle.loadString(filePath);
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);

    List<double> mean = List<double>.from(jsonData['mean']);
    List<double> scale = List<double>.from(jsonData['scale']);
    print("Scales Loaded");
    return StandardScaler(mean: mean, scale: scale);
  }

  // Method to transform input data using the scaler parameters
  List<double> transform(List<double> input) {
    if (input.length != mean.length) {
      throw Exception('Input length does not match mean and scale length');
    }

    List<double> transformed = List<double>.generate(input.length, (i) {
      return (input[i] - mean[i]) / scale[i];
    });

    return transformed;
  }
}
