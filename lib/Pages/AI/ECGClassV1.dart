import 'dart:math';

import 'package:holtersync/Services/StandardScaler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

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
    interpreter = await tfl.Interpreter.fromAsset('assets/model.tflite');
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
    print("AREA OF INTEREST");
    print(areaOfInterests);
    // return areaOfInterests;
    List<dynamic> predictions = modelTwo(areaOfInterests);

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
    print("INPUTSHAPE");
    print(inputShape);
    print("OUTPUTSHAPE");
    print(outputShape);
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
        print(segments[i]);
        if (classification != "NA") {
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
}
