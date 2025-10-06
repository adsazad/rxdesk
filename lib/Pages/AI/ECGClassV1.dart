import 'dart:math';

import 'package:holtersync/Services/StandardScaler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

/// Configuration for the rule-based PVC detector
class PVCDetectorConfig {
  // QRS duration threshold to consider a beat "wide" (ms)
  final double wideQrsMs;
  // A beat is premature if preRR < prematureFactor * medianRR
  final double prematureFactor;
  // A compensatory pause is flagged if postRR > compPauseFactor * medianRR
  final double compPauseFactor;
  // Allowable relative error on (preRR + postRR) ≈ 2*medianRR
  final double compSumSlack;
  // Morphology correlation threshold vs running normal template
  final double morphCorrThreshold;
  // Samples per window around R (total), should match segmentSize
  final int windowSamples;

  const PVCDetectorConfig({
    this.wideQrsMs = 120.0,
    this.prematureFactor = 0.8,
    this.compPauseFactor = 1.2,
    this.compSumSlack = 0.15,
    this.morphCorrThreshold = 0.85,
    this.windowSamples = 200,
  });
}

class ECGClassv1 {
  var aoiInterpreter;

  final int segmentSize = 200;
  final int overlapping = 30;
  final List<String> classLabels = [
    'Abnormal ECG',
    'Atrial Fibrillation',
    'Atrial Flutter',
    'Bigeminy',
    'Hypokalemia',
    'Idioventricular Rhythm',
    'Normal',
    'PVC',
    'Prolonged PR (PR)',
    'Succinate Dehydrogenase Complex Subunit B (SBHB)',
    'Supraventricular Tachyarrhythmia',
    'Trigeminy',
    'Ventricular Tachycardia',
    'Wolff-Parkinson-White (WPW)',
  ];
  // final List<String> classLabels = [
  //   'Atrial Fibrillation', 'Atrial Flutter',
  //   'Bigeminy', 'Fusion', 'Idioventricular Rhythm',
  //   // 'Left Bundle Branch Block',
  //   // 'Noise',
  //   'Normal', 'PVC', 'Prolonged PR (PR)',
  //   // 'Right Bundle Branch Block',
  //   'Succinate Dehydrogenase Complex Subunit B (SBHB)',
  //   'Supraventricular Tachyarrhythmia', 'Trigeminy', 'Ventricular Tachycardia',
  //   'Wolff-Parkinson-White (WPW)'
  // ];
  late tfl.Interpreter interpreter;
  late StandardScaler scalerOne;
  late StandardScaler scalerTwo;

  // Classifications to ignore. Any prediction with a label in this set
  // will be filtered out from model outputs and summary.
  final Set<String> ignoredClassifications = <String>{'Normal', "Abnormal ECG"};

  // Replace the ignored set with the provided labels
  void setIgnoredClassifications(Iterable<String> labels) {
    ignoredClassifications
      ..clear()
      ..addAll(labels);
  }

  // Add a single classification to ignore
  void addIgnoredClassification(String label) {
    ignoredClassifications.add(label);
  }

  // Remove a single classification from ignore
  void removeIgnoredClassification(String label) {
    ignoredClassifications.remove(label);
  }

  // Sampling rate (Hz) used by the rule-based features (QRS width, RR, etc.)
  double fsHz = 250.0;
  // Toggle rule-based PVC detection
  bool enablePVCRuleDetector = true;
  // If true, PVC beats detected by the rule engine will override AI PVC/non-PVC
  bool overrideAIForPVC = true;
  PVCDetectorConfig pvcConfig = const PVCDetectorConfig();

  void setSampleRateHz(double fs) {
    fsHz = fs;
  }

  void setPVCDetectionConfig({
    bool? enable,
    bool? overrideAI,
    PVCDetectorConfig? config,
  }) {
    if (enable != null) enablePVCRuleDetector = enable;
    if (overrideAI != null) overrideAIForPVC = overrideAI;
    if (config != null) pvcConfig = config;
  }

  // Factory constructor to handle async initialization
  ECGClassv1._();

  static Future<ECGClassv1> create() async {
    print("Creating ECGClassv1 instance");
    final instance = ECGClassv1._();
    await instance._initialize();
    print("ECGClassv1 instance created");
    return instance;
  }

  Future<void> _initialize() async {
    print("MODEL LOADER STARTING");
    try {
      interpreter = await tfl.Interpreter.fromAsset('assets/model.tflite');
    } catch (e) {
      print("Error loading model: $e");
      rethrow;
    }
    print("MODEL LOADER DONE");
    print("SCALER LOADER STARTING");
    scalerTwo = await StandardScaler.fromJsonFile("assets/scaler_params.json");
    print("SCALER LOADER DONE");
    scalerOne = await StandardScaler.fromJsonFile(
      "assets/areaofinterestscaler.json",
    );
  }

  init() async {}

  String consolidateAIResult(List<dynamic> predictions) {
    int pvcCount = 0;
    int afibCount = 0;
    int vtCount = 0;
    int aflutterCount = 0;
    int wpwCount = 0;
    int arrhythmiaCount = 0;
    bool normalPresent = false;

    for (var prediction in predictions) {
      print("PRD CONSL");
      String label = prediction['classification'];
      double confidence = prediction['confidence'];
      print(label);
      print(confidence);

      // Skip ignored classifications in consolidation
      if (ignoredClassifications.contains(label)) {
        continue;
      }

      if (confidence >= 0.7) {
        if (label == 'Normal') {
          normalPresent = true;
        } else if (label == 'PVC' && confidence > 0.9) {
          pvcCount++;
        } else if (label == 'Atrial Fibrillation' && confidence > 0.8) {
          afibCount++;
        } else if (label == 'Ventricular Tachycardia' && confidence > 0.8) {
          vtCount++;
        } else if (label == 'Atrial Flutter' && confidence > 0.8) {
          aflutterCount++;
        } else if (label == 'Wolff-Parkinson-White' && confidence > 0.8) {
          wpwCount++;
        } else if ((label == 'Idioventricular Rhythm' ||
                label == 'Fusion' ||
                label == 'Bigeminy' ||
                label == 'Trigeminy' ||
                label == 'Supraventricular Tachyarrhythmia') &&
            confidence > 0.8) {
          arrhythmiaCount++;
        }
      }
    }

    // Check conditions and return appropriate result
    if (pvcCount > 2 && normalPresent) {
      return 'Normal Sinus Rhythm with PVC';
    } else if (afibCount > 3) {
      return 'Atrial Fibrillation Detected';
    } else if (vtCount > 3) {
      return 'Ventricular Tachycardia Detected';
    } else if (aflutterCount > 3) {
      return 'Atrial Flutter Detected';
    } else if (wpwCount > 3) {
      return 'Wolff-Parkinson-White Detected';
    } else if (arrhythmiaCount > 3) {
      return 'Arrhythmia Detected';
    } else if (normalPresent) {
      return 'Normal Sinus Rhythm';
    } else {
      return 'Unknown';
    }
  }

  List<dynamic> segmentDataWithOverlap(List<double> data) {
    int totalLength = data.length;
    int overlapSize = (segmentSize * (overlapping / 100)).ceil();
    int requiredSegments = (totalLength / overlapSize).ceil();

    List<dynamic> segments = [];

    for (int i = 0; i < requiredSegments; i++) {
      int start = i * overlapSize;
      int end = start + segmentSize;
      if (end > totalLength) {
        end =
            totalLength; // Adjust the last segment if it exceeds the total length
      }
      List<double> segment = data.sublist(start, end);
      segments.add({"start": start, "end": end, "segment": segment});
    }

    return segments;
  }

  predict(List<double> data, dynamic rPeak) async {
    // aoiInterpreter =
    // await tfl.Interpreter.fromAsset("assets/areaofinterest.tflite");

    // List<dynamic> segments = segmentDataWithOverlap(data);
    // for (int i = 0; i < segments.length; i++) {
    //   List<double> segment = segments[i]["segment"];
    //   if (segment.length == 200) {
    //     segment = movingAverage(segment);
    //     segment = scalerOne.transform(segment);
    //     segments[i]["osegment"] = movingAverage(segments[i]["segment"]);
    //     segments[i]["segment"] = segment;
    //   }
    // }
    // print("SCALED SEGMENTS");
    // print(segments.length);

    // List<dynamic> areaOfInterests = areaOfInterestModel(segments);
    List<dynamic> areaOfInterests = [];
    for (int i = 0; i < rPeak.length; i++) {
      int start = rPeak[i] - 100;
      int end = rPeak[i] + 100;

      // Initialize an empty segment with a fixed size of 200
      List<double> segment = List.filled(200, 0.0);
      List<double> osegment = List.filled(200, 0.0); // Original segment copy

      // Adjust the start and end to ensure they are within data bounds
      int adjustedStart = start < 0 ? 0 : start;
      int adjustedEnd = end > data.length ? data.length : end;

      // Calculate the actual length of the valid segment within the data bounds
      int validSegmentLength = adjustedEnd - adjustedStart;

      // Copy the valid segment from the data into the segment list
      List<double> validSegment = data.sublist(adjustedStart, adjustedEnd);

      // Place the valid segment in the center of the pre-initialized 200-size segment
      segment.setRange(0, validSegmentLength, validSegment);
      osegment.setRange(
        0,
        validSegmentLength,
        validSegment,
      ); // Copy to osegment

      // Apply moving average to the segment
      segment = movingAverage(segment);

      // Apply the standard scaler to the segment
      segment = scalerOne.transform(segment);

      // Apply moving average to the original segment
      osegment = movingAverage(osegment);

      // Add the segment to the area of interests
      areaOfInterests.add({
        "start": start,
        "end": end,
        "segment": segment,
        "osegment": osegment,
        "classification": "AOL",
        'confidence': 1.0,
      });
    }

    // scalerTwo
    for (int i = 0; i < areaOfInterests.length; i++) {
      List<double> segment = areaOfInterests[i]["osegment"];
      segment = scalerTwo.transform(segment);
      areaOfInterests[i]["segment"] = segment;
      areaOfInterests[i]["classification"] = "AOL";
      areaOfInterests[i]["start"] = areaOfInterests[i]["start"];
      areaOfInterests[i]["end"] = areaOfInterests[i]["end"];
      // areaOfInterests[i]["confidence"] = areaOfInterests[i]["confidence"];
    }
    // print("AREA OF INTEREST");
    // print(areaOfInterests);
    // return areaOfInterests;
    List<dynamic> predictions = modelTwo(areaOfInterests);

    // Rule-based PVC override logic
    if (enablePVCRuleDetector) {
      print("PVC RULE ENGINE STARTING");
      try {
        final pvcEvents = detectPVCs(
          data,
          List<int>.from(rPeak as List),
          fs: fsHz,
          window: pvcConfig.windowSamples,
        );
        print("PVC EVENTS DETECTED");
        print(pvcEvents);
        final pvcIdx = pvcEvents.map((e) => e['i'] as int).toSet();

        // Build an index for quick lookup by beat index
        final Map<int, int> predIdxByBeat = {};
        for (int k = 0; k < predictions.length; k++) {
          final bIdx = predictions[k]['index'];
          if (bIdx is int) predIdxByBeat[bIdx] = k;
        }

        for (final i in pvcIdx) {
          final k = predIdxByBeat[i];
          if (k == null) continue;
          // Override AI classification for PVC beats if configured
          if (overrideAIForPVC) {
            predictions[k]['classification'] = 'PVC';
            // Boost confidence to reflect rule-based decision while preserving max
            final oldConf =
                (predictions[k]['confidence'] as num?)?.toDouble() ?? 0.0;
            predictions[k]['confidence'] = max(0.95, oldConf);
            predictions[k]['source'] = 'rule-pvc';
            predictions[k]['pvcRule'] = true;
          } else {
            // Add a flag but keep AI decision
            predictions[k]['pvcRule'] = true;
          }
        }
      } catch (e) {
        // Fail-safe: never break AI pipeline on rule engine issues
        // print('PVC rule engine error: $e');
      }
    }
    // Apply final filtering: drop any predictions that are in the ignore list
    if (ignoredClassifications.isNotEmpty) {
      predictions =
          predictions
              .where(
                (p) => !ignoredClassifications.contains(p['classification']),
              )
              .toList();
    }

    return predictions;
  }

  areaOfInterestModel(segments) {
    List<dynamic> areasOfInterest = [];
    var inputShape = aoiInterpreter.getInputTensor(0).shape;
    var outputShape = aoiInterpreter.getOutputTensor(0).shape;
    print("INPUTSHAPE");
    print(inputShape);
    print("OUTPUTSHAPE");
    print(outputShape);
    for (int i = 0; i < segments.length; i++) {
      List<double> segment = segments[i]["segment"];
      // segment = movingAverage(segment);
      if (segment.length == 200) {
        List<List<List<double>>> input = [
          segment.map((e) => [e]).toList(),
        ];
        List<List<double>> output = List.generate(
          1,
          (_) => List.filled(2, 0.0),
        );
        aoiInterpreter.run(input, output);
        int maxIndex = output[0].indexOf(
          output[0].reduce((a, b) => a > b ? a : b),
        );
        if (maxIndex == 1) {
          // areasOfInterest.add(segments[i]);
          areasOfInterest.add({
            "start": segments[i]["start"],
            "end": segments[i]["end"],
            "segment": segments[i]["segment"],
            "osegment": segments[i]["osegment"],
            "classification": "AOI",
            'confidence': output[0][maxIndex],
          });
        }
      }
    }
    areasOfInterest = nonMaximumSuppression(areasOfInterest, 0.5);

    return areasOfInterest;
  }

  modelTwo(segments) {
    List<dynamic> predictions = [];

    var inputShape = interpreter.getInputTensor(0).shape;
    var outputShape = interpreter.getOutputTensor(0).shape;
    // print("INPUTSHAPE");
    // print(inputShape);
    // print("OUTPUTSHAPE");
    // print(outputShape);
    // List<String> classLabels = ["NA","Noise", "Normal", "PVC"];

    for (int i = 0; i < segments.length; i++) {
      List<double> segment = segments[i]["segment"];
      // segment = movingAverage(segment);

      // print(segment.length);

      if (segment.length == 200) {
        // // Reshape the segment to [1, 200, 1] to match the expected input dimensions
        List<List<List<double>>> input = [
          segment.map((e) => [e]).toList(),
        ];
        List<List<double>> output = List.generate(
          1,
          (_) => List.filled(14, 0.0),
        ); // Adjusted for three classifications
        interpreter.run(input, output);
        int maxIndex = output[0].indexWhere(
          (e) => e == output[0].reduce((a, b) => a > b ? a : b),
        );
        // print("PREDICTION");
        // List<dynamic> prefs = [];
        // for (int i = 0; i < output[0].length; i++) {
        //   print("${i}: ${classLabels[i]}: ${output[0][i]}");
        //   prefs.add({
        //     "index": i,
        //     "classification": classLabels[i],
        //     "confidence": output[0][i]
        //   });
        // }
        // // non max suppression
        // var newPred = nonMaximumSuppression(predictions, 0.5);
        // print("NEWPRED");
        // print(newPred);
        // print(classLabels[maxIndex]);
        String classification = classLabels[maxIndex];
        print("Class AI: ${classification}: ${output[0][maxIndex]}");
        // print(segments[i]);
        // Skip NA and any ignored classifications
        if (classification != "NA" &&
            !ignoredClassifications.contains(classification)) {
          predictions.add({
            "start": segments[i]["start"],
            "end": segments[i]["end"],
            'index': i,
            'classification': classification,
            "segment": segments[i],
            'confidence': output[0][maxIndex],
            "aoiConfidence": segments[i]["confidence"],
          });
        }
      }
    }

    // return nonMaximumSuppression(predictions, 0.5);
    // print(predictions);
    // var filteredPreds = fixOverLapping(predictions);
    return predictions;
  }

  List<Map<String, dynamic>> nonMaximumSuppression(
    List<dynamic> predictions,
    double threshold,
  ) {
    List<Map<String, dynamic>> filteredPredictions = [];

    predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));

    for (var pred in predictions) {
      bool overlap = false;

      for (var filtered in filteredPredictions) {
        if (iou(pred, filtered) > threshold) {
          overlap = true;
          break;
        }
      }

      if (!overlap) {
        filteredPredictions.add(pred);
      }
    }

    return filteredPredictions;
  }

  double iou(Map<String, dynamic> seg1, Map<String, dynamic> seg2) {
    int start1 = seg1['start'];
    int end1 = seg1['end'];
    int start2 = seg2['start'];
    int end2 = seg2['end'];

    int intersectionStart = max(start1, start2);
    int intersectionEnd = min(end1, end2);
    int intersection = max(0, intersectionEnd - intersectionStart);

    int union = (end1 - start1) + (end2 - start2) - intersection;

    return intersection / union;
  }

  List<double> movingAverage(List<double> data, {int windowSize = 5}) {
    List<double> result = List<double>.filled(data.length, 0.0);

    for (int i = 0; i < data.length; i++) {
      int start = max(0, i - (windowSize ~/ 2));
      int end = min(data.length, i + (windowSize ~/ 2) + 1);
      double sum = 0.0;

      for (int j = start; j < end; j++) {
        sum += data[j];
      }

      result[i] = sum / (end - start);
    }

    return result;
  }

  fixOverLapping(predections) {
    List<Map<String, dynamic>> filteredPredictions = [];
    predections.sort(
      (a, b) =>
          (b['confidence'] as double).compareTo((a['confidence'] as double)),
    );

    for (var pred in predections) {
      bool overlap = false;

      for (var filtered in filteredPredictions) {
        if (iou(pred, filtered) > 0.5) {
          overlap = true;
          break;
        }
      }

      if (!overlap) {
        filteredPredictions.add(pred);
      }
    }

    return filteredPredictions;
  }

  /// Rule-based PVC detector (non-AI). Returns events with beat index and features.
  /// Each event contains: { type: 'PVC', i: beatIndex, rSample, tSec, qrsMs, preRR, postRR, corr, ... }
  List<Map<String, dynamic>> detectPVCs(
    List<double> ecg,
    List<int> rPeaks, {
    required double fs,
    int? window,
  }) {
    final events = <Map<String, dynamic>>[];
    if (ecg.isEmpty || rPeaks.length < 3) return events;

    final win = (window ?? pvcConfig.windowSamples);

    // RR stats
    final rr = <double>[];
    for (int i = 1; i < rPeaks.length; i++) {
      rr.add((rPeaks[i] - rPeaks[i - 1]) / fs);
    }
    final medianRR = _median(rr);
    if (medianRR <= 0) return events;

    // Morphology template window radius (±80 ms around R)
    final tplRad = (0.08 * fs).round();
    List<double>? normalTpl;
    const double corrUpdateAlpha = 0.15;

    for (int i = 1; i < rPeaks.length - 1; i++) {
      final r = rPeaks[i];
      final half = (win / 2).round();
      final start = max(0, r - half);
      final end = min(ecg.length, r + half);
      final seg = ecg.sublist(start, end);
      if (seg.length < 40) continue; // too short
      final smooth = movingAverage(seg, windowSize: 5);
      final rInSeg = r - start;

      // QRS width (ms)
      final qrsMs = _qrsWidthMs(smooth, rInSeg, fs);

      // RR timing
      final preRR = (rPeaks[i] - rPeaks[i - 1]) / fs;
      final postRR = (rPeaks[i + 1] - rPeaks[i]) / fs;

      // Morphology correlation vs running normal template
      double corr = 1.0;
      final cStart = max(0, rInSeg - tplRad);
      final cEnd = min(smooth.length, rInSeg + tplRad);
      if (cEnd > cStart) {
        final cand = smooth.sublist(cStart, cEnd);
        if (cand.length >= 16) {
          if (normalTpl == null || normalTpl.length != cand.length) {
            normalTpl = List<double>.from(cand);
          } else {
            corr = _normCorr(normalTpl, cand);
          }
        }
      }

      final isWide = qrsMs >= pvcConfig.wideQrsMs;
      final isPremature = preRR < pvcConfig.prematureFactor * medianRR;
      final hasCompPause =
          ((preRR + postRR) - 2 * medianRR).abs() <
              pvcConfig.compSumSlack * medianRR ||
          postRR > pvcConfig.compPauseFactor * medianRR;
      final morphAbnormal = corr < pvcConfig.morphCorrThreshold;

      final isPVC =
          (isWide && (isPremature || hasCompPause)) ||
          (isPremature && morphAbnormal);

      // Update normal template with likely normal narrow beats
      if (!isPVC && qrsMs <= (pvcConfig.wideQrsMs - 10.0)) {
        final nStart = max(0, rInSeg - tplRad);
        final nEnd = min(smooth.length, rInSeg + tplRad);
        if (nEnd > nStart) {
          final cand = smooth.sublist(nStart, nEnd);
          if (cand.length >= 16) {
            if (normalTpl == null || normalTpl.length != cand.length) {
              normalTpl = List<double>.from(cand);
            } else {
              for (int k = 0; k < normalTpl.length; k++) {
                normalTpl[k] =
                    (1 - corrUpdateAlpha) * normalTpl[k] +
                    corrUpdateAlpha * cand[k];
              }
            }
          }
        }
      }

      if (isPVC) {
        events.add({
          'type': 'PVC',
          'i': i,
          'rSample': r,
          'tSec': r / fs,
          'qrsMs': qrsMs,
          'preRR': preRR,
          'postRR': postRR,
          'corr': corr,
          'isWide': isWide,
          'isPremature': isPremature,
          'hasCompPause': hasCompPause,
          'morphAbnormal': morphAbnormal,
        });
      }
    }

    return events;
  }

  // Estimate QRS width using slope-threshold delineation around R.
  double _qrsWidthMs(List<double> seg, int rIdx, double fs) {
    if (seg.isEmpty) return 0.0;
    final n = seg.length;
    if (n < 3) return 0.0;
    // First difference magnitude
    final d = List<double>.filled(max(1, n - 1), 0.0);
    for (int i = 0; i < d.length; i++) {
      d[i] = (seg[i + 1] - seg[i]).abs();
    }

    final mad = _median(List<double>.from(d));
    final thr = max(1e-6, 3.0 * mad); // robust slope threshold

    // Search left
    int left = rIdx.clamp(1, n - 2);
    int run = 0;
    const stable = 5;
    for (int i = left - 1; i >= 1; i--) {
      if (d[i] < thr) {
        run++;
        if (run >= stable) {
          left = i;
          break;
        }
      } else {
        run = 0;
      }
    }

    // Search right
    int right = rIdx.clamp(1, n - 2);
    run = 0;
    for (int i = right; i < d.length - 1; i++) {
      if (d[i] < thr) {
        run++;
        if (run >= stable) {
          right = i;
          break;
        }
      } else {
        run = 0;
      }
    }

    // Clamp width to reasonable bounds (60–200 ms)
    final minW = (0.06 * fs).round();
    final maxW = (0.20 * fs).round();
    final widthSamples = (right - left).abs().clamp(minW, maxW);
    return 1000.0 * widthSamples / fs;
  }

  double _median(List<double> a) {
    if (a.isEmpty) return 0.0;
    final b = List<double>.from(a)..sort();
    final n = b.length;
    return (n % 2 == 1) ? b[n ~/ 2] : 0.5 * (b[n ~/ 2 - 1] + b[n ~/ 2]);
  }

  // Normalized correlation (zero-mean, unit-norm)
  double _normCorr(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    if (n == 0) return 0.0;
    double meanA = 0, meanB = 0;
    for (int i = 0; i < n; i++) {
      meanA += a[i];
      meanB += b[i];
    }
    meanA /= n;
    meanB /= n;
    double num = 0, denA = 0, denB = 0;
    for (int i = 0; i < n; i++) {
      final xa = a[i] - meanA;
      final xb = b[i] - meanB;
      num += xa * xb;
      denA += xa * xa;
      denB += xb * xb;
    }
    final den = sqrt(max(denA * denB, 1e-12));
    return (num / den).clamp(-1.0, 1.0);
  }
}
