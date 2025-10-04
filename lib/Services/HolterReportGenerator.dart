import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:holtersync/Pages/AI/ECGClassV1.dart';
import 'package:holtersync/Services/EcgBPMCalculator.dart';
import 'package:holtersync/Services/FilterClass.dart';
import 'package:holtersync/Services/PanThomkins.dart';
import 'package:holtersync/Services/StandardScaler.dart';
import 'package:holtersync/data/local/database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class HolterReportGenerator {
  String? guid;
  String? fileName;
  SharedPreferences? prefs;
  int rawDataFullLength = 0;
  List<double> filterBuff = [];
  List<double> baselineFilterBuff = [];
  double GainFact = 1 / 1.5;
  double sum = 0;
  double baselineSum = 0;
  int FILT_BUF_SIZE = 3 * 6 + 7;
  int Pos = 0;
  FilterClass? filterClass;
  FilterClass? baselineFilterClass;
  int sampleRate = 300;
  int currentIndex = 0;
  int windowSize = 768;
  int rStart = 0;
  int lastIndex = 0;
  List<double> windowEcgData = [];
  Float64List? floatData;

  HolterReportGenerator();

  List<int> allRrIndexes = [];
  List<double> allRrIntervals = [];
  List<int> ecgStats = [];
  ECGClassv1? aiClasser;
  List aiReport = [];
  var conditions;

  double avrBpm = 0.0;
  double minBpm = 0.0;
  double maxBpm = 0.0;
  double processedIndex = 0.0;
  ValueNotifier<String> progress = ValueNotifier<String>("0.00%");
  var appDocumentDir;

  Map<String, dynamic> toJson() {
    return {
      'avgBpm': this.avrBpm,
      'minBpm': this.minBpm,
      'maxBpm': this.maxBpm,
      'processedIndex': this.processedIndex,
      'sampleRate': this.sampleRate,
      'currentIndex': this.currentIndex,
      'windowSize': this.windowSize,
      'rStart': this.rStart,
      'lastIndex': this.lastIndex,
    };
  }

  factory HolterReportGenerator.fromJson(Map<String, dynamic> json) {
    return HolterReportGenerator()
      ..avrBpm = (json['avgBpm'] ?? 0.0).toDouble()
      ..minBpm = (json['minBpm'] ?? 0.0).toDouble()
      ..maxBpm = (json['maxBpm'] ?? 0.0).toDouble()
      ..processedIndex = (json['processedIndex'] ?? 0.0).toDouble()
      ..sampleRate = json['sampleRate'] ?? 300
      ..currentIndex = json['currentIndex'] ?? 0
      ..windowSize = json['windowSize'] ?? 768
      ..rStart = json['rStart'] ?? 0
      ..lastIndex = json['lastIndex'] ?? 0;
  }

  init(String guid) async {
    this.guid = guid;
    appDocumentDir = await getApplicationDocumentsDirectory();
    print("HOLINIT");
    prefs = await SharedPreferences.getInstance();
    filterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    baselineFilterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    print("HOLBUFSET");
    // ecg-rec-${guid.toString()}
    String rec = prefs!.getString("ecg-rec-${guid.toString()}").toString();
    if (prefs!.getString("ecg-rec-${guid.toString()}") == null) {
      await serverSync(guid);
      rec = prefs!.getString("ecg-rec-${guid.toString()}").toString();
    }
    if (!rec.startsWith("holFil:")) {
      return Exception("Not Holter Data");
    }
    fileName = rec.split("holFil:")[1];
    print('HOLFILENAME');
    print(fileName);
    // ch file exist
    File file = File(fileName.toString());
    if (await file.exists() == false ||
        fileName == "null" ||
        fileName == null) {
      await serverSync(guid);
      rec = prefs!.getString("ecg-rec-${guid.toString()}").toString();
    }

    print("HOLFIL: ${fileName}");
    filterClass = FilterClass();
    baselineFilterClass = FilterClass();
    filterClass!.init(sampleRate, 3, 5, 1, 2, 0, 0.65, 5, 2, 6);
    baselineFilterClass!.init(sampleRate, 12, 7, 1, 2, 0, 0.65, 5, 2, 6);
    // file = File(fileName.toString());
    //
    // await readFileInChunks(file);
    final fileLength = await file.length();
    final partSize = (fileLength / 3).ceil();

    Future<List<double>> part1 = readFileInChunks(file, 0, partSize);
    Future<List<double>> part2 = readFileInChunks(file, partSize, partSize * 2);
    Future<List<double>> part3 = readFileInChunks(
      file,
      partSize * 2,
      fileLength,
    );

    // Wait for all parts to complete
    List<List<double>> results = await Future.wait([part1, part2, part3]);
    // print("PRESULTS");
    // print(results);
    // Process each part's results to extract RR intervals
    for (var result in results) {
      processWindowData(result);
    }
    allRrIntervals = EcgBPMCalculator().convertRRIndexesToInterval(
      allRrIndexes,
    );

    // Stitch the RR intervals together
    // allRrIntervals = stitchIntervals();

    // Process remaining data if the final chunk didn't trigger the condition
    if (windowEcgData.isNotEmpty) {
      // processWindowData();
    }

    avrBpm = EcgBPMCalculator().getAverageBPM(allRrIntervals);
    maxBpm = EcgBPMCalculator().getMaxBPM(allRrIntervals);
    minBpm = EcgBPMCalculator().getMinBPM(allRrIntervals);
    conditions = detectConditions(allRrIntervals, allRrIndexes);

    print("RAWDATALEN: ${rawDataFullLength}");
  }

  serverSync(guid) async {
    // print('HOLFILSERVSYNC');
    // fileName = await downloadFileWithRandomAccess(guid.toString());
    // print("SYNFILNAME");
    // print(fileName);
    // if (fileName != null) {
    //   await prefs!.setString(
    //     "ecg-rec-${guid.toString()}",
    //     "holFil:${fileName}",
    //   );
    // }
  }

  aiReporter() async {
    print("running ai reporter");
    aiClasser = await ECGClassv1.create();
    Interpreter interpreter = aiClasser!.interpreter;
    StandardScaler scalerTwo = aiClasser!.scalerTwo;
    processedIndex = 0;
    print("allRrIndexes length: ${allRrIndexes.length}");
    for (int i = 0; i < allRrIndexes.length; i++) {
      int index = allRrIndexes[i];
      List<double> slice = await getSlice200(index);
      print("SLICELEN: ${slice.length}");
      if (slice.length == 200) {
        slice = filterData(slice);
        slice = aiClasser!.movingAverage(slice);
        slice = scalerTwo.transform(slice);
        List<List<List<double>>> input = [
          slice.map((e) => [e]).toList(),
        ];
        List<List<double>> output = List.generate(
          1,
          (_) => List.filled(14, 0.0),
        );
        interpreter.run(input, output);
        int maxIndex = output[0].indexWhere(
          (e) => e == output[0].reduce((a, b) => a > b ? a : b),
        );

        String label = aiClasser!.classLabels[maxIndex];
        int conIndex = conditions.indexWhere(
          (element) => element["name"] == label,
        );
        var confidenceScore = output[0][maxIndex];
        if (label != 'normal') {
          if (confidenceScore > 0.5) {
            if (conIndex != -1) {
              conditions[conIndex]["index"].add(index);
            } else {
              conditions.add({
                "name": label,
                "index": [index],
              });
            }
          }
        }
      }

      processedIndex++;
      final double progressPercent =
          (processedIndex / allRrIndexes.length) * 100;
      progress.value = "${progressPercent.toStringAsFixed(2)}%";
    }
  }

  Future<List<double>> getSlice200(int index) async {
    int sliceBefore = 100; // Number of samples before the index
    int sliceAfter = 100; // Number of samples after the index

    int startIndex = index - sliceBefore;
    int endIndex = index + sliceAfter;

    final file = File(fileName.toString());
    final fileLength = await file.length();

    // Calculate total number of samples in the file
    int bytesPerSample = 8; // Assuming 64-bit (double) data
    int totalSamples = (fileLength / bytesPerSample).floor();

    // Adjust startIndex and endIndex dynamically based on file length
    if (startIndex < 0) {
      startIndex = 0;
    }
    if (endIndex > totalSamples) {
      endIndex = totalSamples;
    }

    // Recalculate byte offsets after adjustment
    int startByte = startIndex * bytesPerSample;
    int endByte = endIndex * bytesPerSample;

    // If there is no valid range after adjustments, return an empty list
    if (startByte >= fileLength || startByte < 0 || endByte <= startByte) {
      return [];
    }

    final randomAccessFile = await file.open();

    try {
      // Move to the start byte position
      await randomAccessFile.setPosition(startByte);

      // Read the chunk
      int chunkSize = endByte - startByte;
      Uint8List chunk = await randomAccessFile.read(chunkSize);

      // Convert the chunk to doubles
      Float64List floatData = Float64List.view(chunk.buffer);

      // Apply filtering to the data
      return filterData(floatData.toList());
    } finally {
      await randomAccessFile.close();
    }
  }

  Future<List<double>> getSlice(int index) async {
    int sliceBefore = 900; // Number of samples before the index
    int sliceAfter = 300; // Number of samples after the index

    int startIndex = index - sliceBefore;
    int endIndex = index + sliceAfter;

    final file = File(fileName.toString());
    final fileLength = await file.length();

    // Calculate total number of samples in the file
    int bytesPerSample = 8; // Assuming 64-bit (double) data
    int totalSamples = (fileLength / bytesPerSample).floor();

    // Adjust startIndex and endIndex dynamically based on file length
    if (startIndex < 0) {
      startIndex = 0;
    }
    if (endIndex > totalSamples) {
      endIndex = totalSamples;
    }

    // Recalculate byte offsets after adjustment
    int startByte = startIndex * bytesPerSample;
    int endByte = endIndex * bytesPerSample;

    // If there is no valid range after adjustments, return an empty list
    if (startByte >= fileLength || startByte < 0 || endByte <= startByte) {
      return [];
    }

    final randomAccessFile = await file.open();

    try {
      // Move to the start byte position
      await randomAccessFile.setPosition(startByte);

      // Read the chunk
      int chunkSize = endByte - startByte;
      Uint8List chunk = await randomAccessFile.read(chunkSize);

      // Convert the chunk to doubles
      Float64List floatData = Float64List.view(chunk.buffer);

      // Apply filtering to the data
      return filterData(floatData.toList());
    } finally {
      await randomAccessFile.close();
    }
  }

  Future<List<double>> getSliceOneMinute({
    int startIndex = 0,
    int endIndex = 18000,
    double gainFactor = 1 / 2,
  }) async {
    final file = File(fileName.toString());
    final fileLength = await file.length();

    int bytesPerSample = 8; // 64-bit double
    int totalSamples = (fileLength / bytesPerSample).floor();

    if (startIndex < 0) {
      startIndex = 0;
    }
    if (endIndex > totalSamples) {
      endIndex = totalSamples;
    }

    int startByte = startIndex * bytesPerSample;
    int endByte = endIndex * bytesPerSample;

    if (startByte >= fileLength || startByte < 0 || endByte <= startByte) {
      return [];
    }

    final randomAccessFile = await file.open();

    try {
      await randomAccessFile.setPosition(startByte);
      int chunkSize = endByte - startByte;
      Uint8List chunk = await randomAccessFile.read(chunkSize);

      Float64List floatData = Float64List.view(chunk.buffer);

      // Downsample from 300 Hz to 75 Hz
      List<double> downsampledData = [];
      for (int i = 0; i < floatData.length; i += 4) {
        // Keep every 4th sample
        downsampledData.add(floatData[i]);
      }

      // Apply filtering to the downsampled data
      return filterData(
        downsampledData,
        gainFactor: gainFactor,
        samplingRate: 75,
      );
    } finally {
      await randomAccessFile.close();
    }
  }

  detectConditions(List<double> rrIntervals, List<int> rrIndex) {
    // print("RRINTERVALDETCON");
    // print(rrIntervals);
    var conditionsMap = {
      "Tachycardia": [],
      "Bradycardia": [],
      "Pause": [],
      "Superventricular Tachycardia (SVT)": [],
    };

    if (rrIntervals.length < 4) {
      // Not enough intervals to check for the condition
      return [];
    }

    // Iterate through the RR intervals to check for tachycardia, bradycardia, and SVT
    for (int i = 0; i <= rrIntervals.length - 4; i++) {
      bool tachycardiaMet = true;
      bool bradycardiaMet = true;
      bool svtMet = true;

      // Check four consecutive intervals
      for (int j = i; j < i + 4; j++) {
        double bpm = 60 / rrIntervals[j];

        // Check for tachycardia (greater than 100 BPM and up to 200 BPM)
        if (bpm <= 100 || bpm > 200) {
          tachycardiaMet = false;
        }

        // Check for bradycardia (between 30 and 55 BPM)
        if (bpm >= 55 || bpm < 30) {
          bradycardiaMet = false;
        }

        // Check for SVT (greater than 150 BPM and up to 250 BPM)
        if (bpm <= 150 || bpm > 250) {
          svtMet = false;
        }

        // If no condition is met, break the loop
        if (!tachycardiaMet && !bradycardiaMet && !svtMet) {
          break;
        }
      }

      // If tachycardia condition is met, add the index
      if (tachycardiaMet) {
        conditionsMap["Tachycardia"]!.add(rrIndex[i]);
      }

      // If bradycardia condition is met, add the index
      if (bradycardiaMet) {
        conditionsMap["Bradycardia"]!.add(rrIndex[i]);
      }

      // If SVT condition is met, add the index
      if (svtMet) {
        conditionsMap["Superventricular Tachycardia (SVT)"]!.add(rrIndex[i]);
      }
    }

    // Check for pauses
    for (int i = 0; i < rrIntervals.length; i++) {
      if (rrIntervals[i] >= 3.0) {
        conditionsMap["Pause"]!.add(rrIndex[i]);
      }
    }

    // Convert the map to the desired array format
    var conditions =
        conditionsMap.entries
            .where((entry) => entry.value.isNotEmpty)
            .map((entry) => {"name": entry.key, "index": entry.value})
            .toList();
    // print(conditions);
    return conditions;
  }

  Future<List<double>> readFileInChunks(
    File file,
    int startByte,
    int endByte,
  ) async {
    final raf = await file.open();
    try {
      await raf.setPosition(startByte);
      int readSize = endByte - startByte;
      Uint8List chunk = await raf.read(readSize);
      Float64List floatData = Float64List.view(chunk.buffer);

      return floatData.toList();
    } finally {
      await raf.close();
    }
  }

  List<double> filterData(
    List<double> data, {
    double gainFactor = 0.0,
    int samplingRate = 0,
  }) {
    FilterClass? filCls;
    if (samplingRate != 0) {
      filCls = FilterClass();
      filCls.init(samplingRate, 3, 5, 1, 2, 0, 0.65, 5, 2, 6);
    } else {
      filCls = filterClass;
    }
    if (filCls == null) {
      throw StateError('FilterClass is not initialized');
    }

    List<double> filteredData = [];
    int tempPos;

    for (double val in data) {
      val = val * GainFact;

      tempPos = Pos;
      filterBuff[Pos] = val;

      double sum = 0;

      for (int stage = 0; stage <= 2; stage++) {
        sum = 0;
        for (int c = 0; c <= 5 - 1; c++) {
          sum +=
              filterBuff[(tempPos + FILT_BUF_SIZE - c) % FILT_BUF_SIZE] *
              filCls.Coeff[stage][c];
        }
        sum *= 2;
        filterBuff[(tempPos + 1) % FILT_BUF_SIZE] = sum;
        filterBuff[(tempPos + 6) % FILT_BUF_SIZE] = sum;
        tempPos = (tempPos + 6) % FILT_BUF_SIZE;
      }

      Pos = (Pos + 2) % FILT_BUF_SIZE;
      if (gainFactor != 0.0) {
        sum = sum * gainFactor;
      }
      filteredData.add(sum);
    }

    return filteredData;
  }

  /// Simple baseline correction using a centered moving-average detrend.
  /// This estimates the slow baseline wander over a given window and subtracts
  /// it from the signal. Keeps the length unchanged and is O(n).
  List<double> _baselineCorrect(
    List<double> data, {
    int samplingRate = 300,
    double windowSec = 0.6,
  }) {
    final n = data.length;
    if (n == 0) return data;

    int window = (windowSec * samplingRate).round();
    if (window < 1) window = 1;
    // Prefer an odd window for symmetric centering
    if (window % 2 == 0) window += 1;
    final half = window ~/ 2;

    // Prefix sum for fast sliding mean
    final prefix = List<double>.filled(n + 1, 0.0);
    for (int i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + data[i];
    }

    final out = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      int l = i - half;
      if (l < 0) l = 0;
      int r = i + half;
      if (r >= n) r = n - 1;
      final len = (r - l + 1);
      final baseline = (prefix[r + 1] - prefix[l]) / len;
      out[i] = data[i] - baseline;
    }
    return out;
  }

  void updateChartData1(double val) {
    int tempPos = 0;
    //    dot moving code
    //     if (currentIndex < 256 * 2) {
    if (rawDataFullLength > 900) {
      val = val * GainFact;

      tempPos = Pos;
      filterBuff[Pos] = val;
      // baselineFilterBuff[Pos] = val;
      // if (val > (4096 / 12) * 10 || val < -(4096 / 12) * 10) {
      //   baselineFilterBuff[Pos] = 0;
      // }
      for (int stage = 0; stage <= 2; stage++) {
        sum = 0;
        baselineSum = 0;

        for (int c = 0; c <= 5 - 1; c++) {
          sum =
              sum +
              filterBuff[(tempPos + FILT_BUF_SIZE - c) % FILT_BUF_SIZE] *
                  filterClass!.Coeff[stage][c];
          // baselineSum = baselineSum +
          //     baselineFilterBuff[
          //             (tempPos + FILT_BUF_SIZE - c) % FILT_BUF_SIZE] *
          //         baselineFilterClass!.Coeff[stage][c];
        }

        sum = sum * 2;
        // baselineSum = baselineSum * 2;
        filterBuff[(tempPos + 1) % FILT_BUF_SIZE] = sum;
        // baselineFilterBuff[(tempPos + 1) % FILT_BUF_SIZE] = baselineSum;
        filterBuff[(tempPos + 6) % FILT_BUF_SIZE] = sum;
        // baselineFilterBuff[(tempPos + 6) % FILT_BUF_SIZE] = baselineSum;
        tempPos = (tempPos + 6) % FILT_BUF_SIZE;
      }
      // average filter buffer
      // val = filterBuff[Pos];
      // val = filterBuff.reduce((a, b) => a + b) / filterBuff.length;
      // val = sum;
      val = sum;
      // print(baselineSum);
      // print(val);
      Pos = (Pos + 2) % FILT_BUF_SIZE;

      //       print("prev  ${val}");
      //     val = iirFilter!.apply(val);
      // print("After  ${val}");
      //       if (rawDataFull.length > 230) {
      if (windowEcgData.length > windowSize) {
        windowEcgData.removeAt(0);
      }

      // round val
      // val = double.parse(val.toStringAsFixed(2));
      // 4096 / 12
      // if(val > (4096 /12) * 2){
      //
      //   resetECG();
      //
      // }
      // print("Filtered: ${val}");
      windowEcgData.add(val);
      // print(max())
      // get max value from windowEcgData
      //       double maxVal = windowEcgData
      //           .reduce((value, element) => value > element ? value : element);
      // print(maxVal);
      if (currentIndex >= windowSize) {
        // processWindowData();
        currentIndex = 0;
      }
      currentIndex++;
      // print(currentIndex);
    }
  }

  // void processWindowData() async {
  //   if (rStart == 0) {
  //     lastIndex = rawDataFullLength;
  //   }
  //   ecgStats = PanThonkins().getRPeaks(windowEcgData, 300);
  //
  //   if (rStart == 0) {
  //     allRrIndexes = List<int>.from(ecgStats);
  //     rStart = 1;
  //   } else {
  //     for (int rs in ecgStats) {
  //       int globalIndex = rs + lastIndex;
  //       allRrIndexes.add(globalIndex);
  //
  //       // Calculate the RR interval directly
  //       int interval = globalIndex - (allRrIndexes.length > 1 ? allRrIndexes[allRrIndexes.length - 2] : 0);
  //
  //       // Write the interval as bytes
  //       await saveSingleRrIntervalToBytes(interval);
  //     }
  //     lastIndex += windowEcgData.length;
  //   }
  // }
  //
  // Future<void> saveSingleRrIntervalToBytes(int interval) async {
  //
  //   final file = File('${appDocumentDir.path}/${this.guid.toString()}-rr.bin');
  //
  //   // Convert the interval to bytes (as a 32-bit integer)
  //   final byteData = ByteData(4);
  //   byteData.setInt32(0, interval, Endian.little); // Use little-endian format
  //
  //   // Append the bytes to the file
  //   final raf = await file.open(mode: FileMode.append);
  //   await raf.writeFrom(byteData.buffer.asUint8List());
  //   await raf.close();
  // }

  //   void processWindowData() async {
  //     if (rStart == 0) {
  //       lastIndex = rawDataFullLength;
  //     }
  //     ecgStats = PanThonkins().getRPeaks(windowEcgData, 300);
  // // print(ecgStats);
  //     // int maxRRCon = 4;
  //     // if (allRrIndexes.length > maxRRCon) {
  //     //   while (allRrIndexes.length > maxRRCon) {
  //     //     allRrIndexes.removeAt(0);
  //     //   }
  //     // }
  //     // print("Rpeak count");
  // // print(ecgStats["rPeaks"].length);
  //
  //     if (rStart == 0) {
  //       allRrIndexes = List<int>.from(ecgStats);
  //       rStart = 1;
  //     } else {
  //       for (int rs in ecgStats) {
  //         allRrIndexes.add(rs + lastIndex);
  //         // if (allRrIndexes.length > maxRRCon) {
  //         //   allRrIndexes.removeAt(0);
  //         // }
  //       }
  //       lastIndex += windowEcgData.length;
  //     }
  //     allRrIntervals =
  //         EcgBPMCalculator().convertRRIndexesToInterval(allRrIndexes);
  //     // print(allRrIntervals);
  //     // print("All RR Indexes");
  //     // print(allRrIndexes);
  //     // print(allRrIndexes.length);
  //     // print("All RR Intervals");
  //     // print(allRrIntervals);
  //   }
  void processWindowData(List<double> data) {
    for (double val in data) {
      updateChartData1(val); // Update the sliding window with each data point
    }
    // Implement your RR peak detection logic here (e.g., Pan-Tompkins algorithm)
    List<int> rrIndexes = PanThonkins().getRPeaks(data, sampleRate);
    for (int rrIndex in rrIndexes) {
      allRrIndexes.add(rrIndex + rawDataFullLength);
    }
    rawDataFullLength += data.length;
  }

  /// Initialize using a local SQLite recording ID. Fetches file path from DB and processes it.
  Future<void> initWithRecordingId(AppDatabase db, int recordingId) async {
    // Get recording from local database
    final recording =
        await (db.select(db.recordings)
          ..where((tbl) => tbl.id.equals(recordingId))).getSingleOrNull();

    if (recording == null) {
      throw Exception('Recording not found for id: $recordingId');
    }

    final path = recording.filePath;
    if (path.isEmpty) {
      throw Exception('Recording file path is empty for id: $recordingId');
    }

    fileName = path;
    appDocumentDir = await getApplicationDocumentsDirectory();
    // Prepare filter buffers and filters
    filterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    baselineFilterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    filterClass = FilterClass();
    baselineFilterClass = FilterClass();
    filterClass!.init(sampleRate, 3, 5, 1, 2, 0, 0.65, 5, 2, 6);
    baselineFilterClass!.init(sampleRate, 12, 7, 1, 2, 0, 0.65, 5, 2, 6);

    await _runHolterOnFile(fileName!);
  }

  /// Initialize directly with a file path (bypasses prefs/guid and DB).
  Future<void> initWithFile(String filePath) async {
    fileName = filePath;
    appDocumentDir = await getApplicationDocumentsDirectory();
    filterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    baselineFilterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    filterClass = FilterClass();
    baselineFilterClass = FilterClass();
    filterClass!.init(sampleRate, 3, 5, 1, 2, 0, 0.65, 5, 2, 6);
    baselineFilterClass!.init(sampleRate, 12, 7, 1, 2, 0, 0.65, 5, 2, 6);
    await _runHolterOnFile(fileName!);
  }

  Future<void> _runHolterOnFile(String filePath) async {
    // file = File(fileName.toString());
    //
    // await readFileInChunks(file);
    print(filePath);
    final file = File(filePath);
    final fileLength = await file.length();
    final partSize = (fileLength / 3).ceil();

    Future<List<double>> part1 = readFileInChunks(file, 0, partSize);
    Future<List<double>> part2 = readFileInChunks(file, partSize, partSize * 2);
    Future<List<double>> part3 = readFileInChunks(
      file,
      partSize * 2,
      fileLength,
    );

    // Wait for all parts to complete
    List<List<double>> results = await Future.wait([part1, part2, part3]);
    // print("PRESULTS");
    // print(results);
    // Process each part's results to extract RR intervals
    for (var result in results) {
      processWindowData(result);
    }
    allRrIntervals = EcgBPMCalculator().convertRRIndexesToInterval(
      allRrIndexes,
    );

    // Stitch the RR intervals together
    // allRrIntervals = stitchIntervals();

    // Process remaining data if the final chunk didn't trigger the condition
    if (windowEcgData.isNotEmpty) {
      // processWindowData();
    }

    avrBpm = EcgBPMCalculator().getAverageBPM(allRrIntervals);
    maxBpm = EcgBPMCalculator().getMaxBPM(allRrIntervals);
    minBpm = EcgBPMCalculator().getMinBPM(allRrIntervals);
    conditions = detectConditions(allRrIntervals, allRrIndexes);

    print("RAWDATALEN: ${rawDataFullLength}");
  }

  /// Returns raw ECG samples for a given range [startSample, startSample+lengthSamples).
  /// Supports both:
  /// - Raw Float64 streams (8 bytes per sample)
  /// - HolterSync .bin with JSON header + 5 Float64 channels per sample (40 bytes per sample)
  Future<List<double>> getEcgSamples(int startSample, int lengthSamples) async {
    if (fileName == null || fileName!.isEmpty) {
      throw StateError('HolterReportGenerator not initialized with a file');
    }

    final file = File(fileName!);
    if (!await file.exists()) return [];

    final raf = await file.open();
    try {
      // Try to detect headered 5-channel format
      int headerLen = 0;
      int baseOffset = 0;
      int bytesPerSample = 8; // default: raw Float64 stream

      // Read first 4 bytes to check for header length
      if (await file.length() >= 4) {
        final headerLenBytes = await raf.read(4);
        if (headerLenBytes.length == 4) {
          headerLen = ByteData.sublistView(
            headerLenBytes,
          ).getUint32(0, Endian.little);
          // Plausible header length guard
          if (headerLen > 0 &&
              headerLen <= 8192 &&
              await file.length() >= 4 + headerLen) {
            baseOffset = 4 + headerLen;
            final dataBytes = (await file.length()) - baseOffset;
            if (dataBytes > 0 && dataBytes % (5 * 8) == 0) {
              // Treat as 5-channel [ECG,O2,CO2,Vol,Flow] Float64
              bytesPerSample = 5 * 8;
            } else {
              // Not a valid 5-channel bin, fallback to raw
              baseOffset = 0;
              bytesPerSample = 8;
            }
          } else {
            // No valid header, fallback to raw
            headerLen = 0;
            baseOffset = 0;
            bytesPerSample = 8;
          }
        }
      }

      final fileLen = await file.length();
      final totalSamples = ((fileLen - baseOffset) ~/ bytesPerSample);
      if (startSample >= totalSamples) return [];

      final safeLength = lengthSamples.clamp(0, totalSamples - startSample);
      if (safeLength <= 0) return [];

      final startByte = baseOffset + startSample * bytesPerSample;
      await raf.setPosition(startByte);
      final readBytes = await raf.read(safeLength * bytesPerSample);

      // Extract ECG
      if (bytesPerSample == 8) {
        // Raw Float64 stream
        final floats = Float64List.view(readBytes.buffer, 0, safeLength);
        // Apply filtering and baseline correction
        final filtered = filterData(floats.toList());
        return _baselineCorrect(
          filtered,
          samplingRate: sampleRate,
          windowSec: 0.6,
        );
      } else {
        // 5-channel; take ECG at channel offset 0
        final bd = ByteData.sublistView(readBytes);
        final List<double> ecg = List.filled(safeLength, 0.0);
        for (int i = 0; i < safeLength; i++) {
          final off = i * bytesPerSample;
          ecg[i] = bd.getFloat64(off + 0, Endian.little);
        }
        // Apply filtering and baseline correction
        final filtered = filterData(ecg);
        return _baselineCorrect(
          filtered,
          samplingRate: sampleRate,
          windowSec: 0.6,
        );
      }
    } finally {
      await raf.close();
    }
  }

  /// Returns total number of ECG samples available in the underlying file.
  Future<int> getTotalEcgSamples() async {
    if (fileName == null || fileName!.isEmpty) {
      throw StateError('HolterReportGenerator not initialized with a file');
    }
    final file = File(fileName!);
    if (!await file.exists()) return 0;
    final len = await file.length();
    if (len < 4) {
      // raw float64 stream
      return (len ~/ 8);
    }
    final raf = await file.open();
    try {
      final headerLenBytes = await raf.read(4);
      if (headerLenBytes.length != 4) return (len ~/ 8);
      final headerLen = ByteData.sublistView(
        headerLenBytes,
      ).getUint32(0, Endian.little);
      if (headerLen > 0 && headerLen <= 8192 && len >= 4 + headerLen) {
        final dataBytes = len - (4 + headerLen);
        if (dataBytes > 0 && dataBytes % (5 * 8) == 0) {
          return (dataBytes ~/ (5 * 8));
        }
      }
      // fallback raw
      return (len ~/ 8);
    } finally {
      await raf.close();
    }
  }
}
