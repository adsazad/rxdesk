import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class DataSaver {
  static final DataSaver _instance = DataSaver._internal();
  factory DataSaver() => _instance;
  DataSaver._internal();

  late File _file;
  bool initialized = false;

  /// Initialize the file with a JSON patient/session header
  Future<void> init({
    required String filename,
    required var patientInfo,
  }) async {
    if (initialized) {
      print("⚠️ DataSaver is already initialized. Skipping re-init.");
      return;
    }
    initialized = true;

    final dir = await getApplicationDocumentsDirectory();
    final tempDirPath = '${dir.path}/SpiroBT/Temp';
    final tempDir = Directory(tempDirPath);
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    _file = File('${tempDir.path}/$filename');
    print('Initializing DataSaver with file: ${_file.path}');

    final jsonString = jsonEncode(patientInfo);
    final jsonBytes = utf8.encode(jsonString);

    final lengthBytes = ByteData(4)
      ..setUint32(0, jsonBytes.length, Endian.little);
    final allBytes =
        lengthBytes.buffer.asUint8List() + Uint8List.fromList(jsonBytes);

    await _file.writeAsBytes(allBytes, mode: FileMode.write); // only once!
  }

  Future<void> appendBatch(List<double> data) async {
    if (!initialized) {
      throw Exception("DataSaver not initialized. Call init() first.");
    }

    final byteData = ByteData(8 * data.length);
    for (int i = 0; i < data.length; i++) {
      byteData.setFloat64(i * 8, data[i], Endian.little);
    }

    await _file.writeAsBytes(
      byteData.buffer.asUint8List(),
      mode: FileMode.append,
    );
    print(
      "📦 Wrote batch: ${data.length ~/ 5} samples (${data.length} values)",
    );
  }

  /// Append one sample of [ecg, o2, co2, vol, flow] as float64
  Future<void> append({
    required double ecg,
    required double o2,
    required double co2,
    required double vol,
    required double flow,
  }) async {
    if (!initialized) {
      throw Exception("DataSaver not initialized. Call init() first.");
    }

    final byteData = ByteData(8 * 5);
    byteData.setFloat64(0, ecg, Endian.little);
    byteData.setFloat64(8, o2, Endian.little);
    byteData.setFloat64(16, co2, Endian.little);
    byteData.setFloat64(24, vol, Endian.little);
    byteData.setFloat64(32, flow, Endian.little);

    await _file.writeAsBytes(
      byteData.buffer.asUint8List(),
      mode: FileMode.append,
    );
  }

  reset() {
    initialized = false;
    _file = File('');
    print("DataSaver reset. Call init() to reinitialize.");
  }

  /// Optional: Get path to the file
  String get path => _file.path;
}
