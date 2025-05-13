import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class DataSaver {
  late File _file;
  bool _initialized = false;

  /// Initialize the file with a JSON patient/session header
  Future<void> init({
    required String filename,
    required var patientInfo,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/$filename');
    print(_file.path);

    if (!await _file.exists()) {
      await _file.create(recursive: true);
    }

    final jsonString = jsonEncode(patientInfo);
    final jsonBytes = utf8.encode(jsonString);
    final lengthBytes = ByteData(4)..setUint32(0, jsonBytes.length, Endian.little);

    await _file.writeAsBytes(lengthBytes.buffer.asUint8List(), mode: FileMode.write);
    await _file.writeAsBytes(jsonBytes, mode: FileMode.append);

    _initialized = true;
  }

  /// Append one sample of [ecg, o2, co2, vol, flow] as float64
  Future<void> append({
    required double ecg,
    required double o2,
    required double co2,
    required double vol,
    required double flow,
  }) async {
    if (!_initialized) {
      throw Exception("DataSaver not initialized. Call init() first.");
    }

    final byteData = ByteData(8 * 5);
    byteData.setFloat64(0, ecg, Endian.little);
    byteData.setFloat64(8, o2, Endian.little);
    byteData.setFloat64(16, co2, Endian.little);
    byteData.setFloat64(24, vol, Endian.little);
    byteData.setFloat64(32, flow, Endian.little);

    await _file.writeAsBytes(byteData.buffer.asUint8List(), mode: FileMode.append);
  }

  /// Optional: Get path to the file
  String get path => _file.path;
}
