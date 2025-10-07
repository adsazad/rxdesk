import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:holtersync/Pages/AI/ECGClassV1.dart';
import 'package:holtersync/Services/EcgBPMCalculator.dart';
import 'package:holtersync/Services/FilterClass.dart';
import 'package:holtersync/Services/PanThomkins.dart';
import 'package:holtersync/data/local/database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Scans the entire recording for R-peaks using parsed ECG samples from
  /// [getEcgSamples], applying a small overlap between chunks to avoid
  /// losing beats at boundaries. Populates [allRrIndexes] and [allRrIntervals].
  Future<void> analyzeFullRecordingRPeaks({
    int chunkSeconds = 300, // 5 minutes
    int overlapSeconds = 2, // 2 seconds overlap
    void Function(double p)? onProgress,
  }) async {
    if (fileName == null || fileName!.isEmpty) {
      throw StateError('HolterReportGenerator not initialized with a file');
    }

    final total = await getTotalEcgSamples();
    if (total <= 0) {
      allRrIndexes = [];
      allRrIntervals = [];
      rawDataFullLength = 0;
      return;
    }

    // Reset series
    allRrIndexes = [];
    allRrIntervals = [];
    rawDataFullLength = total;

    // Ensure filter buffers are initialized for streaming filtering inside getEcgSamples
    Pos = 0;
    filterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);

    final fs = sampleRate;
    final int chunk = (chunkSeconds * fs).clamp(1, total);
    final int overlap = (overlapSeconds * fs).clamp(0, chunk);

    int start = 0;
    int lastAccepted = -0x3fffffff;

    while (start < total) {
      final bool hasOverlap = (start + chunk + overlap) <= total;
      final int len = hasOverlap ? (chunk + overlap) : (total - start);

      // Read filtered ECG for this segment (handles raw vs 5-channel automatically)
      final ecg = await getEcgSamples(start, len);

      // Detect local R-peaks and map to global indices
      final local = PanThonkins().getRPeaks(ecg, fs);
      for (final lp in local) {
        final g = start + lp;
        // De-dup in overlap and enforce a 200ms refractory
        if (g <= lastAccepted) continue;
        if (allRrIndexes.isNotEmpty && (g - allRrIndexes.last) < (0.2 * fs)) {
          continue;
        }
        allRrIndexes.add(g);
        lastAccepted = g;
      }

      // Advance by chunk size; we purposely keep an overlap at the END of this
      // segment that will be re-visited at the START of the next segment
      start += chunk;
      onProgress?.call((start / total).clamp(0.0, 1.0));
    }

    allRrIntervals = EcgBPMCalculator().convertRRIndexesToInterval(
      allRrIndexes,
      sampleRate: fs,
    );
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
    // Initialize AI classifier using shared pipeline (ignore + PVC rule logic)
    aiClasser = await ECGClassv1.create();
    aiClasser!.setSampleRateHz(sampleRate.toDouble());
    aiClasser!.setPVCDetectionConfig(enable: true, overrideAI: true);

    // Load full ECG trace once to feed the predictor (predict extracts 200-sample windows itself)
    final total = await getTotalEcgSamples();
    if (total <= 0 || allRrIndexes.isEmpty) {
      // If R-peaks are not available yet, run a quick scan here with progress
      if (total > 0 && allRrIndexes.isEmpty) {
        try {
          print('AI: R-peak scan starting');
          await analyzeFullRecordingRPeaks(
            onProgress: (p) {
              final pct = (p * 30.0).clamp(0.0, 30.0); // reserve first 30%
              progress.value = '${pct.toStringAsFixed(2)}%';
            },
          );
          print('AI: R-peak scan done, beats=${allRrIndexes.length}');
        } catch (e) {
          print('AI: R-peak scan failed: $e');
          aiReport = [];
          return;
        }
      } else {
        aiReport = [];
        return;
      }
    }

    // Progress setup
    processedIndex = 0;
    progress.value = "0.00%";

  // Fetch ECG data at native rate with filtering/baseline correction
  print('AI: loading ECG samples total=$total');
  final ecg = await getEcgSamples(0, total);
  print('AI: ECG loaded (${ecg.length} samples)');

    // Process in small batches using an isolate for preprocessing (segment + scaling)
    final List<dynamic> preds = [];
    final int nBeats = allRrIndexes.length;
    if (nBeats <= 0) {
      print('AI: No R-peaks found; aborting AI.');
      aiReport = [];
      progress.value = '100.00%';
      return;
    }
    const int batchSize = 24; // smaller batch to keep UI responsive
    print('AI: beats=$nBeats, batchSize=$batchSize');
    // Ensure the UI sees progress after ECG load
    progress.value = '30.00%';
    // Yield once before heavy loop to keep UI responsive
    await Future<void>.delayed(Duration.zero);

    // Extract scaler params to send across isolate (rootBundle not available in isolate)
    final List<double> scaler1Mean = List<double>.from(aiClasser!.scalerOne.mean);
    final List<double> scaler1Scale = List<double>.from(aiClasser!.scalerOne.scale);
    final List<double> scaler2Mean = List<double>.from(aiClasser!.scalerTwo.mean);
    final List<double> scaler2Scale = List<double>.from(aiClasser!.scalerTwo.scale);

  bool useCompute = false; // Default to main-isolate to avoid isolate send errors
  print('AI: using compute isolate: $useCompute');
  for (int startBeat = 0; startBeat < nBeats; startBeat += batchSize) {
      // Optional: light heartbeat log every ~200 batches
      if (startBeat % (batchSize * 200) == 0) {
        // ignore: avoid_print
        print('AI: processing beats $startBeat/${nBeats}');
      }
      final int endBeat = (startBeat + batchSize < nBeats)
          ? startBeat + batchSize
          : nBeats;

      // Build 200-sample raw segments locally (cheap copies), then preprocess in isolate
      final rawSegments = <List<double>>[];
      final rPeaksBatch = allRrIndexes.sublist(startBeat, endBeat);
      for (final r in rPeaksBatch) {
        int start = r - 100;
        int end = r + 100;
        int adjustedStart = start < 0 ? 0 : start;
        int adjustedEnd = end > ecg.length ? ecg.length : end;
        final int validLen = adjustedEnd - adjustedStart;
        final seg = List<double>.filled(200, 0.0);
        if (validLen > 0) {
          final valid = ecg.sublist(adjustedStart, adjustedEnd);
          seg.setRange(0, validLen, valid);
        }
        rawSegments.add(seg);
      }

      // Prepare segments in a background isolate (smoothing + scaling)
      final prepArgs = <String, dynamic>{
        'rawSegments': rawSegments,
        'rPeaks': rPeaksBatch,
        'scaler1Mean': scaler1Mean,
        'scaler1Scale': scaler1Scale,
        'scaler2Mean': scaler2Mean,
        'scaler2Scale': scaler2Scale,
      };
      List<Map<String, dynamic>> areaOfInterests;
      if (useCompute) {
        try {
          areaOfInterests = await compute(_prepareSegmentsForBeats, prepArgs)
              .timeout(const Duration(seconds: 30));
          // Diagnostic
          // ignore: avoid_print
          print('AI: batch ${startBeat}..${endBeat} preprocessed=${areaOfInterests.length}');
        } catch (e) {
          // Fallback: preprocess on main isolate and disable compute for this run
          print('AI: compute preprocess failed/timeout (${e.runtimeType}): $e. Disabling compute; falling back to main isolate.');
          useCompute = false;
          areaOfInterests = [];
          for (int i = 0; i < rawSegments.length; i++) {
            final r = rPeaksBatch[i];
            int start = r - 100;
            int end = r + 100;
            List<double> seg = rawSegments[i];
            // Smooth + scale via aiClasser scalers
            try {
              seg = aiClasser!.movingAverage(seg);
              final scaled1 = aiClasser!.scalerOne.transform(seg);
              final scaled2 = aiClasser!.scalerTwo.transform(seg);
              areaOfInterests.add({
                'start': start,
                'end': end,
                'segment': scaled2,
                'osegment': scaled1,
                'classification': 'AOL',
                'confidence': 1.0,
              });
            } catch (ee) {
              // Skip problematic segment but keep going
              print('AI: preprocess fallback failed at seg $i: $ee');
            }
          }
        }
      } else {
        // Direct main-isolate preprocessing
        areaOfInterests = [];
        for (int i = 0; i < rawSegments.length; i++) {
          final r = rPeaksBatch[i];
          int start = r - 100;
          int end = r + 100;
          List<double> seg = rawSegments[i];
          try {
            seg = aiClasser!.movingAverage(seg);
            final scaled1 = aiClasser!.scalerOne.transform(seg);
            final scaled2 = aiClasser!.scalerTwo.transform(seg);
            areaOfInterests.add({
              'start': start,
              'end': end,
              'segment': scaled2,
              'osegment': scaled1,
              'classification': 'AOL',
              'confidence': 1.0,
            });
          } catch (ee) {
            print('AI: preprocess main-isolate failed at seg $i: $ee');
          }
        }
      }

      // Run model on main isolate for each segment
      for (int i = 0; i < areaOfInterests.length; i++) {
        final seg = areaOfInterests[i];
        final List<double> segment = seg['segment'];
        if (segment.length != 200) continue;
        // Build input [1,200,1]
        final input = [segment.map((e) => [e]).toList()];
        final output = [List.filled(14, 0.0)];
        try {
          aiClasser!.interpreter.run(input, output);
        } catch (e) {
          print('AI: interpreter.run failed at index ${startBeat + i}: $e');
          continue;
        }
        final scores = output[0];
        int maxIndex = 0;
        double maxVal = scores[0];
        for (int k = 1; k < scores.length; k++) {
          if (scores[k] > maxVal) {
            maxVal = scores[k];
            maxIndex = k;
          }
        }
        final classification = aiClasser!.classLabels[maxIndex];
        if (classification != 'NA' &&
            !aiClasser!.ignoredClassifications.contains(classification)) {
          preds.add({
            'start': seg['start'],
            'end': seg['end'],
            'index': startBeat + i,
            'classification': classification,
            'segment': seg,
            'confidence': maxVal,
            'aoiConfidence': seg['confidence'] ?? 1.0,
          });
        }
      }

      // Update progress and yield to UI
      processedIndex = endBeat.toDouble();
      // Map AI loop to 30..100% to keep room for the pre-scan phase
      final base = 30.0;
      final pctAi = (processedIndex / nBeats * (100.0 - base));
      final pct = (base + pctAi).clamp(0.0, 100.0);
      progress.value = "${pct.toStringAsFixed(2)}%";
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    // Rule-based PVC override logic (mirror ECGClassv1.predict behavior)
    if (aiClasser!.enablePVCRuleDetector) {
      try {
        final pvcEvents = aiClasser!.detectPVCs(
          ecg,
          List<int>.from(allRrIndexes),
          fs: aiClasser!.fsHz,
          window: aiClasser!.pvcConfig.windowSamples,
        );
        final pvcIdx = pvcEvents.map((e) => e['i'] as int).toSet();

        // Map global beat index -> prediction index
        final Map<int, int> predIdxByBeat = {};
        for (int k = 0; k < preds.length; k++) {
          final bIdx = preds[k]['index'];
          if (bIdx is int) predIdxByBeat[bIdx] = k;
        }

        for (final i in pvcIdx) {
          final k = predIdxByBeat[i];
          if (k == null) continue;
          if (aiClasser!.overrideAIForPVC) {
            preds[k]['classification'] = 'PVC';
            final oldConf = (preds[k]['confidence'] as num?)?.toDouble() ?? 0.0;
            if (oldConf < 0.95) preds[k]['confidence'] = 0.95;
            preds[k]['source'] = 'rule-pvc';
            preds[k]['pvcRule'] = true;
          } else {
            preds[k]['pvcRule'] = true;
          }
        }
      } catch (_) {
        // Never break AI pipeline on rule engine issues
      }
    }

    // Apply final filtering: drop ignored classifications
    if (aiClasser!.ignoredClassifications.isNotEmpty) {
      preds.removeWhere(
        (p) => aiClasser!.ignoredClassifications.contains(p['classification']),
      );
    }

    aiReport = preds;

    // Aggregate into Holter conditions structure for UI tabs and highlighting
    final Map<String, List<int>> idxByName = {};
    for (final p in preds) {
      final String? cls = p['classification']?.toString();
      if (cls == null || cls == 'AOL') continue;
      final int? s = (p['start'] as num?)?.toInt();
      final int? e = (p['end'] as num?)?.toInt();
      if (s == null || e == null) continue;
      final int center = ((s + e) / 2).round();
      (idxByName[cls] ??= <int>[]).add(center);
    }

    // Convert to list of { name, index: [centers...] }
    final List<Map<String, dynamic>> grouped = [];
    idxByName.forEach((name, indices) {
      if (indices.isEmpty) return;
      indices.sort();
      grouped.add({'name': name, 'index': indices});
    });
    conditions = grouped;

    // Finalize progress
    processedIndex = allRrIndexes.length.toDouble();
    progress.value = "100.00%";
  }

/// Top-level pure function to prepare 200-sample, smoothed and scaled segments.
/// This runs in a background isolate via `compute` and MUST NOT use any plugins.
List<Map<String, dynamic>> _prepareSegmentsForBeats(
  Map<String, dynamic> args,
) {
  final List<List<double>> rawSegments =
      (args['rawSegments'] as List).map((e) => (e as List).cast<double>()).toList();
  final List<int> rPeaks = (args['rPeaks'] as List).cast<int>();
  final List<double> s1m = (args['scaler1Mean'] as List).cast<double>();
  final List<double> s1s = (args['scaler1Scale'] as List).cast<double>();
  final List<double> s2m = (args['scaler2Mean'] as List).cast<double>();
  final List<double> s2s = (args['scaler2Scale'] as List).cast<double>();

  List<Map<String, dynamic>> out = [];
  for (int i = 0; i < rawSegments.length; i++) {
    final r = rPeaks[i];
    final start = r - 100;
    final end = r + 100;
    List<double> seg = rawSegments[i];
    // Smooth + scale using provided scaler params
    seg = _movingAverage5(seg);
    final scaled1 = _standardScale(seg, s1m, s1s);
    final scaled2 = _standardScale(seg, s2m, s2s);

    out.add({
      'start': start,
      'end': end,
      'segment': scaled2, // same as ECGClassv1.post-scalerTwo
      'osegment': scaled1,
      'classification': 'AOL',
      'confidence': 1.0,
    });
  }

  return out;
}

List<double> _movingAverage5(List<double> data) {
  final n = data.length;
  final out = List<double>.filled(n, 0.0);
  const w = 5;
  final h = w ~/ 2;
  for (int i = 0; i < n; i++) {
    int l = i - h;
    if (l < 0) l = 0;
    int r = i + h;
    if (r >= n) r = n - 1;
    double sum = 0.0;
    for (int j = l; j <= r; j++) sum += data[j];
    out[i] = sum / (r - l + 1);
  }
  return out;
}

List<double> _standardScale(
  List<double> input,
  List<double> mean,
  List<double> scale,
) {
  final n = input.length;
  final out = List<double>.filled(n, 0.0);
  for (int i = 0; i < n; i++) {
    final m = (i < mean.length) ? mean[i] : 0.0;
    final sRaw = (i < scale.length) ? scale[i] : 1.0;
    final s = (sRaw.abs() < 1e-12) ? 1.0 : sRaw;
    double v = (input[i] - m) / s;
    if (v.isNaN || v.isInfinite) v = 0.0;
    out[i] = v;
  }
  return out;
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

  /// Run initialization and analysis on a background isolate to avoid blocking the UI thread.
  /// Emits coarse progress updates via [onProgress] where p is 0..1 and stage is a short label.
  Future<void> initWithRecordingIdOnBackground(
    AppDatabase db,
    int recordingId, {
    void Function(double p, String stage)? onProgress,
  }) async {
    // Resolve file path on main isolate (DB is not sendable to isolates)
    final recording =
        await (db.select(db.recordings)
          ..where((tbl) => tbl.id.equals(recordingId))).getSingleOrNull();
    if (recording == null) {
      throw Exception('Recording not found for id: $recordingId');
    }
    final String filePath = recording.filePath;
    if (filePath.isEmpty) {
      throw Exception('Recording file path is empty for id: $recordingId');
    }

    final receivePort = ReceivePort();
    await Isolate.spawn<_HolterIsolateParams>(
      _holterAnalyzeEntry,
      _HolterIsolateParams(
        sendPort: receivePort.sendPort,
        filePath: filePath,
        sampleRate: sampleRate,
      ),
      errorsAreFatal: true,
    );

    await for (final msg in receivePort) {
      if (msg is Map && msg['type'] == 'progress') {
        final p = (msg['p'] as num?)?.toDouble() ?? 0.0;
        final stage = (msg['stage'] as String?) ?? '';
        onProgress?.call(p, stage);
      } else if (msg is Map && msg['type'] == 'done') {
        // Apply analysis results to this instance on main isolate
        final result = msg['result'] as Map;
        fileName = filePath;
        allRrIndexes = (result['rr'] as List).cast<int>();
        allRrIntervals =
            (result['rrIntervals'] as List)
                .map((e) => (e as num).toDouble())
                .toList();
        avrBpm = (result['avrBpm'] as num?)?.toDouble() ?? 0.0;
        minBpm = (result['minBpm'] as num?)?.toDouble() ?? 0.0;
        maxBpm = (result['maxBpm'] as num?)?.toDouble() ?? 0.0;
        conditions = result['conditions'];
        rawDataFullLength = (result['rawLen'] as num?)?.toInt() ?? 0;
        // Prepare filters for later getEcgSamples() calls on UI isolate
        filterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
        baselineFilterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
        filterClass = FilterClass();
        baselineFilterClass = FilterClass();
        filterClass!.init(sampleRate, 3, 5, 1, 2, 0, 0.65, 5, 2, 6);
        baselineFilterClass!.init(sampleRate, 12, 7, 1, 2, 0, 0.65, 5, 2, 6);
        receivePort.close();
        break;
      } else if (msg is Map && msg['type'] == 'error') {
        receivePort.close();
        throw Exception(msg['message'] as String? ?? 'Unknown analysis error');
      }
    }
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
    // Use robust scanner that parses ECG and applies overlap-safe peak picking
    await analyzeFullRecordingRPeaks();
    avrBpm = EcgBPMCalculator().getAverageBPM(allRrIntervals);
    maxBpm = EcgBPMCalculator().getMaxBPM(allRrIntervals);
    minBpm = EcgBPMCalculator().getMinBPM(allRrIntervals);
    conditions = detectConditions(allRrIntervals, allRrIndexes);
  }

  /// Returns ECG samples for a given range [startSample, startSample+lengthSamples).
  /// Supports both:
  /// - Raw Float64 streams (8 bytes per sample)
  /// - HolterSync .bin with JSON header + 5 Float64 channels per sample (40 bytes per sample)
  Future<List<double>> getEcgSamples(
    int startSample,
    int lengthSamples, {
    int? targetSamplingRate,
  }) async {
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
        final raw = floats.toList();
        // Decimation path for overview (top chart)
        if (targetSamplingRate != null &&
            targetSamplingRate > 0 &&
            targetSamplingRate < sampleRate &&
            sampleRate % targetSamplingRate == 0) {
          final stride = sampleRate ~/ targetSamplingRate;
          // Simple anti-aliasing: block-average over stride, then filter at target rate
          final decimated = <double>[];
          for (int i = 0; i < raw.length; i += stride) {
            double acc = 0.0;
            int end = (i + stride <= raw.length) ? (i + stride) : raw.length;
            int cnt = end - i;
            for (int j = i; j < end; j++) acc += raw[j];
            decimated.add(acc / cnt);
          }
          final filtered60 = filterData(
            decimated,
            samplingRate: targetSamplingRate,
          );
          return _baselineCorrect(
            filtered60,
            samplingRate: targetSamplingRate,
            windowSec: 0.6,
          );
        }
        // Full-resolution path
        final filtered = filterData(raw);
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
        if (targetSamplingRate != null &&
            targetSamplingRate > 0 &&
            targetSamplingRate < sampleRate &&
            sampleRate % targetSamplingRate == 0) {
          final stride = sampleRate ~/ targetSamplingRate;
          final decimated = <double>[];
          for (int i = 0; i < ecg.length; i += stride) {
            double acc = 0.0;
            int end = (i + stride <= ecg.length) ? (i + stride) : ecg.length;
            int cnt = end - i;
            for (int j = i; j < end; j++) acc += ecg[j];
            decimated.add(acc / cnt);
          }
          final filtered60 = filterData(
            decimated,
            samplingRate: targetSamplingRate,
          );
          return _baselineCorrect(
            filtered60,
            samplingRate: targetSamplingRate,
            windowSec: 0.6,
          );
        }
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

class _HolterIsolateParams {
  final SendPort sendPort;
  final String filePath;
  final int sampleRate;
  _HolterIsolateParams({
    required this.sendPort,
    required this.filePath,
    required this.sampleRate,
  });
}

void _holterAnalyzeEntry(_HolterIsolateParams params) async {
  final send = params.sendPort;
  try {
    send.send({'type': 'progress', 'p': 0.02, 'stage': 'Opening file'});
    final file = File(params.filePath);
    final fileLength = await file.length();
    if (fileLength == 0) {
      throw Exception('Recording file is empty');
    }

    final worker = HolterReportGenerator();
    worker.sampleRate = params.sampleRate;
    worker.fileName = params.filePath;
    worker.filterBuff = List<double>.filled(worker.FILT_BUF_SIZE, 0.0);
    worker.baselineFilterBuff = List<double>.filled(worker.FILT_BUF_SIZE, 0.0);
    worker.filterClass = FilterClass();
    worker.baselineFilterClass = FilterClass();
    worker.filterClass!.init(worker.sampleRate, 3, 5, 1, 2, 0, 0.65, 5, 2, 6);
    worker.baselineFilterClass!.init(
      worker.sampleRate,
      12,
      7,
      1,
      2,
      0,
      0.65,
      5,
      2,
      6,
    );

    send.send({'type': 'progress', 'p': 0.08, 'stage': 'Scanning R-peaks'});
    await worker.analyzeFullRecordingRPeaks(
      chunkSeconds: 300,
      overlapSeconds: 2,
      onProgress:
          (p) => send.send({
            'type': 'progress',
            'p': 0.08 + 0.85 * p,
            'stage': 'Scanning R-peaks',
          }),
    );

    final rrIntervals = worker.allRrIntervals;
    final avg = EcgBPMCalculator().getAverageBPM(rrIntervals);
    final max = EcgBPMCalculator().getMaxBPM(rrIntervals);
    final min = EcgBPMCalculator().getMinBPM(rrIntervals);
    final cond = worker.detectConditions(rrIntervals, worker.allRrIndexes);

    send.send({
      'type': 'done',
      'result': {
        'rr': worker.allRrIndexes,
        'rrIntervals': rrIntervals,
        'avrBpm': avg,
        'minBpm': min,
        'maxBpm': max,
        'conditions': cond,
        'rawLen': worker.rawDataFullLength,
      },
    });
  } catch (e) {
    send.send({'type': 'error', 'message': e.toString()});
  }
}
