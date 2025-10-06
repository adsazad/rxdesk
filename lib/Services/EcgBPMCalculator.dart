import 'dart:collection';
import 'dart:math';

import 'package:holtersync/Services/PanThomkins.dart';

class EcgBPMCalculator {
  int ecgIndex = 0;
  int samplingRate = 300;

  List<double> ecgData = [];
  List<double> realEcgData = [];
  List<double> smoothLine = [];
  List<double> baseline = [];
  List<double> bottomLine = [];

  List<int> rPeaks = [];
  List<int> qPeaks = [];
  List<int> sPeaks = [];
  List<int> pPeaks = [];
  List<int> tPeaks = [];

  List<dynamic> pStart = [];
  List<dynamic> pEnds = [];
  List<dynamic> QStarts = [];
  List<dynamic> SEnds = [];
  List<dynamic> tEnds = [];

  double rThreshold = 700;

  int qPeakIndex = 0;
  int sPeakIndex = 0;
  double qPeakValue = 0;
  double sPeakValue = 0;

  // Accept List<List<double>> and extract signal from ecgIndex
  List<double> extractECGChannel(List<List<double>> rawData, {int index = 0}) {
    return rawData.map((row) => row.length > index ? row[index] : 0.0).toList();
  }

  /// Lightweight stats: Only extract R-peaks using Pan-Tompkins
  List<int> getStatsLite(
    List<List<double>> rawData, {
    int index = 0,
    int sampleRate = 300,
  }) {
    this.ecgIndex = index;
    this.samplingRate = sampleRate;
    realEcgData = extractECGChannel(rawData, index: index);
    rPeaks = PanThonkins().getRPeaks(realEcgData, samplingRate);
    return rPeaks;
  }

  /// Full ECG analysis with detailed metrics and intervals
  Map<String, dynamic> getStats(
    List<List<double>> rawData, {
    int index = 0,
    int sampleRate = 300,
  }) {
    this.ecgIndex = index;
    this.samplingRate = sampleRate;
    realEcgData = extractECGChannel(rawData, index: index);
    ecgData = realEcgData;

    smoothLine = SmoothDataAvr(realEcgData);
    baseline = getBaseLine(smoothLine);
    bottomLine = findBottomLine(smoothLine);

    double RRInterval = calculateRRInterval(
      realEcgData,
      sampleRate: sampleRate,
    );
    double BPM = calculateBPM(RRInterval);

    qPeaks = findQPeaks(realEcgData);
    pPeaks = findPPeaks(realEcgData);
    pStart = findPStarts(smoothLine, pPeaks);
    QStarts = findQStarts();
    pEnds = findPEnds(smoothLine, pPeaks);
    sPeaks = findSPeaks(realEcgData);
    tPeaks = findTPeaks(realEcgData);
    SEnds = findSEnds(smoothLine, sPeaks);
    tEnds = findTEnd();

    double qrsInterval = calculateQRSInterval();
    double qtInterval = calculateQTInterval(realEcgData);
    double qtc = qtInterval / sqrt(RRInterval);
    double prInterval = calculatePRInterval(realEcgData);

    // double averageRAmplitude = calculateRAverageAmplitude();
    // double averagePAmplitude = calculatePAverageAmplitude();
    // double averageTAmplitude = calculateTAverageAmplitude();
    // double averageSAmplitude = calculateSAverageAmplitude();

    int secondRPeakIndex = rPeaks.length > 1 ? rPeaks[1] : -1;
    double secondRPeakValue =
        secondRPeakIndex >= 0 ? ecgData[secondRPeakIndex] : 0;
    int secondTPeakIndex = tPeaks.length > 1 ? tPeaks[1] : -1;
    double secondTPeakValue =
        secondTPeakIndex >= 0 ? ecgData[secondTPeakIndex] : 0;
    int secondPPeakIndex = pPeaks.length > 1 ? pPeaks[1] : -1;
    double secondPPeakValue =
        secondPPeakIndex >= 0 ? ecgData[secondPPeakIndex] : 0;

    double averageBpm = getAverageBPM(
      convertRRIndexesToInterval(rPeaks, sampleRate: sampleRate),
    );
    double timeLengthSecond = (ecgData.length / samplingRate);

    var pvcBeats = detectAllPVCsFinal();

    return {
      "timeLengthSecond": timeLengthSecond,
      "rThreshold": rThreshold,
      "RrInterval": RRInterval,
      // "smoothLine": smoothLine,
      // "baseline": baseline,
      "pStart": pStart,
      "pEnds": pEnds,
      "qStarts": QStarts,
      "sEnds": SEnds,
      "bpm": BPM,
      "averageBpm": averageBpm,
      "qtInterval": qtInterval,
      "qtc": qtc,
      "prInterval": prInterval,
      "bottomLine": bottomLine,
      // "averageRAmplitude": averageRAmplitude,
      // "averagePAmplitude": averagePAmplitude,
      // "averageTAmplitude": averageTAmplitude,
      // "averageSAmplitude": averageSAmplitude,
      "qrsInterval": qrsInterval,
      "qPeakIndex": qPeakIndex,
      "sPeakIndex": sPeakIndex,
      "qPeakValue": qPeakValue,
      "sPeakValue": sPeakValue,
      "rPeaks": rPeaks,
      "qPeaks": qPeaks,
      "tPeaks": tPeaks,
      "pPeaks": pPeaks,
      "sPeaks": sPeaks,
      "tEnds": tEnds,
      "secondRPeakIndex": secondRPeakIndex,
      "secondRPeakValue": secondRPeakValue,
      "secondTPeakIndex": secondTPeakIndex,
      "secondTPeakValue": secondTPeakValue,
      "secondPPeakIndex": secondPPeakIndex,
      "secondPPeakValue": secondPPeakValue,
      "pvcBeats": pvcBeats,
    };
  }

  calculateQRSInterval() {
    List<double> valQrs = [];
    for (int i = 0; i < QStarts.length; i++) {
      // print("QStarts ${QStarts[i]}");
      int qStartIndex = QStarts[i]["index"];

      // find s peak in range of 600 after q index in speaks values
      int sIndex = 0;
      for (int j = 0; j < sPeaks.length; j++) {
        if (sPeaks[j] > qStartIndex && sPeaks[j] < qStartIndex + 600) {
          sIndex = sPeaks[j];
          break;
        }
      }
      double qrsInterval = (sIndex - qStartIndex) / samplingRate;
      qrsInterval = qrsInterval.abs();
      if (qrsInterval >= 0.06 && qrsInterval <= 0.13) {
        valQrs.add(qrsInterval);
      }
    }

    double qrsInterval = _calculateAverage(valQrs);
    // int qStartIndex = QStarts[1]["index"];
    // int sIndex = sPeaks[1];
    //
    // // calculate interval in seconds
    // double qrsInterval = (sIndex - qStartIndex) / samplingRate;
    return qrsInterval;
  }

  List<double> getBaseLine(List<double> ecgData) {
    int windowSize = 200;
    List<double> baseline = List.filled(ecgData.length, 0.0);

    for (int i = 0; i < ecgData.length; i++) {
      int start = max(0, i - windowSize ~/ 2);
      int end = min(ecgData.length - 1, i + windowSize ~/ 2);
      double sum = 0.0;
      for (int j = start; j <= end; j++) {
        sum += ecgData[j];
      }
      baseline[i] = sum / (end - start + 1);
    }

    return baseline;
  }

  List<double> SmoothDataAvr(List<double> ecgData) {
    int windowSize = 5;
    List<double> smoothLine = List.filled(ecgData.length, 0.0);

    for (int i = 0; i < ecgData.length; i++) {
      int start = max(0, i - windowSize ~/ 2);
      int end = min(ecgData.length - 1, i + windowSize ~/ 2);
      double sum = 0.0;
      for (int j = start; j <= end; j++) {
        sum += ecgData[j];
      }
      smoothLine[i] = sum / (end - start + 1);
    }

    return smoothLine;
  }

  double _calculateAverage(List<double> signal) {
    try {
      double sum = signal.reduce((a, b) => a + b);
      return sum / signal.length;
    } catch (e) {
      return 0;
    }
  }

  // double findBaseline(List<double> ecgData) {
  //   double sum = 0;
  //   int count = 0;
  //   int windowSize = 10;
  //   List<int> pqrstMerged = [];
  //   pqrstMerged.addAll(pPeaks);
  //   pqrstMerged.addAll(qPeaks);
  //   pqrstMerged.addAll(rPeaks);
  //   pqrstMerged.addAll(sPeaks);
  //   pqrstMerged.addAll(tPeaks);
  //   List<int> peaksIndices = pqrstMerged;
  //
  //   // Iterate over the signal, excluding regions around peaks
  //   for (int i = 0; i < ecgData.length; i++) {
  //     bool exclude = false;
  //     for (int peakIndex in peaksIndices) {
  //       if (i >= peakIndex - windowSize && i <= peakIndex + windowSize) {
  //         exclude = true;
  //         break;
  //       }
  //     }
  //     if (!exclude) {
  //       sum += ecgData[i];
  //       count++;
  //     }
  //   }
  //
  //   // Calculate the baseline as the average value of the signal
  //   double baseline = sum / count;
  //   return baseline;
  // }

  // calculate average amplitude of r peaks
  double calculateRAverageAmplitude() {
    // Find R-peaks in the ECG signal
    double sum = 0;
    for (int i = 0; i < rPeaks.length; i++) {
      sum += realEcgData[rPeaks[i]] - bottomLine[0];
    }
    double average = sum / rPeaks.length;
    average = calculateAmplitude(average);
    return average;
  }

  double calculatePAverageAmplitude() {
    double sum = 0;
    for (int i = 0; i < pPeaks.length; i++) {
      sum += realEcgData[pPeaks[i]] - bottomLine[0];
    }
    double average = sum / pPeaks.length;
    average = calculateAmplitude(average);
    return average;
  }

  double calculateTAverageAmplitude() {
    double sum = 0;
    for (int i = 0; i < tPeaks.length; i++) {
      sum += realEcgData[tPeaks[i]] - bottomLine[0];
    }
    double average = sum / tPeaks.length;
    average = calculateAmplitude(average);
    return average;
  }

  double calculateSAverageAmplitude() {
    double sum = 0;
    for (int i = 0; i < sPeaks.length; i++) {
      sum += realEcgData[sPeaks[i]] - bottomLine[0];
    }
    double average = sum / sPeaks.length;
    average = calculateAmplitude(average);
    return average;
  }

  // Calculate amplitute in millivoltes 1 millivolte is 4096/12
  double calculateAmplitude(double val) {
    // 1 millivolte is 4096/12
    double amplitude = val * (6 / 4096); // two boxes = 1 mv
    return amplitude;
  }

  List<double> findBottomLine(List<double> ecgData) {
    // Set a threshold for flatness (you can adjust this based on your data)
    int flatnessThreshold = 1;

    List<double> bottomLineValues = [];

    // Iterate through the ECG data to find flat line sections
    for (int i = 0; i < ecgData.length; i++) {
      double currentValue = ecgData[i];

      // Check if the difference between current and next values is below the threshold
      if (i < ecgData.length - 1 &&
          (ecgData[i + 1] - currentValue).abs() <= flatnessThreshold) {
        bottomLineValues.add(currentValue.toDouble());
      } else if (bottomLineValues.isNotEmpty) {
        // If a flat line section ends, calculate the average value
        double averageValue =
            bottomLineValues.reduce((a, b) => a + b) / bottomLineValues.length;
        return [averageValue];
      }
    }

    return bottomLineValues;
  }

  double calculatePRInterval(List<double> ecgData) {
    // print("PR Interval Calculator");

    // Find P-peaks and R-peaks in the ECG signal
    // List<int> rPeaks = findRPeaks(ecgData);

    // Check if there are at least one P-peak and one R-peak
    if (pPeaks.isEmpty || rPeaks.isEmpty) {
      throw Exception(
        "Insufficient P-peaks or R-peaks to calculate PR interval",
      );
    }

    // Calculate PR interval using the first P-peak and R-peak
    int firstPPeakIndex = pPeaks[0];
    int firstRPeakIndex = rPeaks[0];

    // Assuming a sampling rate of 256 Hz (adjust accordingly)
    double prInterval = (firstRPeakIndex - firstPPeakIndex) / samplingRate;

    return prInterval;
  }

  List<dynamic> findPStarts(List<double> ecgData, List<int> pPeaks) {
    List<dynamic> pStarts = [];

    for (int pPeak in pPeaks) {
      int windowStart = max(0, pPeak - 20); // Adjust window start
      int windowEnd = min(ecgData.length - 1, pPeak);

      // Flag to indicate if P wave is detected
      bool inPWave = false;
      int pStartIndex = -1;

      for (int i = windowStart; i <= windowEnd; i++) {
        // Check if signal rises above baseline
        if (ecgData[i] > baseline[i] && !inPWave) {
          inPWave = true; // Start of P wave
          pStartIndex = i; // Set P start index
        } else if (ecgData[i] <= baseline[i] && inPWave) {
          // End of P wave, exit loop
          break;
        }
      }

      // Add the index and value of the start of P wave
      if (pStartIndex != -1) {
        pStarts.add({"index": pStartIndex, "value": realEcgData[pStartIndex]});
      }
    }

    return pStarts;
  }

  List<dynamic> findPEnds(List<double> ecgData, List<int> pPeaks) {
    List<dynamic> pEnds = [];

    for (int pPeak in pPeaks) {
      int windowStart = pPeak; // Adjust window start to P peak
      int windowEnd = min(ecgData.length - 1, pPeak + 20); // Adjust window end

      // Flag to indicate if P wave is detected
      bool inPWave = false;
      int pEndIndex = -1;

      for (int i = windowStart; i <= windowEnd; i++) {
        // Check if signal returns to baseline
        if (ecgData[i] <= baseline[i] && inPWave) {
          // End of P wave
          pEndIndex = i - 1; // Adjust index to the end of P wave
          break;
        } else if (ecgData[i] > baseline[i] && !inPWave) {
          inPWave = true; // Start of P wave
        }
      }

      // Add the index and value of the end of P wave
      if (pEndIndex != -1) {
        pEnds.add({"index": pEndIndex, "value": realEcgData[pEndIndex]});
      }
    }

    return pEnds;
  }

  List<int> findPPeaks(List<double> ecgData) {
    List<int> pPeaks = [];

    for (int qPeak in qPeaks) {
      int windowStart = max(0, qPeak - 60); // Adjust the window size as needed
      int windowEnd = min(ecgData.length - 1, qPeak);

      int maxIndex = windowStart;
      double maxValue = ecgData[windowStart];

      for (int i = windowStart + 1; i <= windowEnd; i++) {
        if (ecgData[i] > maxValue) {
          maxValue = ecgData[i];
          maxIndex = i;
        }
      }

      pPeaks.add(maxIndex);
    }
    // print("PPEAKS");
    // print(pPeaks);
    // print(ecgData[pPeaks[0]]);

    return pPeaks;
  }

  // depreciated
  // List<int> findPPeaks(List<double> ecgData) {
  //   List<int> pPeaks = [];
  //   double threshold =
  //       450; // Adjust this value based on your data characteristics
  //   List<double> smoothedData =
  //       movingAverage(ecgData, 3); // Adjust the window size as needed
  //
  //   for (int i = 1; i < smoothedData.length - 1; i++) {
  //     // Simple peak detection: Check if the current value is greater than both neighbors
  //     if (smoothedData[i] > smoothedData[i - 1] &&
  //         smoothedData[i] > smoothedData[i + 1] &&
  //         smoothedData[i] > threshold) {
  //       pPeaks.add(i);
  //     }
  //   }
  //
  //   return pPeaks;
  // }

  // calculateQS(List<double> ecgData) {
  //   // print("QS Interval Calculator");
  //
  //   // Find Q-peaks and S-peaks in the ECG signal
  //
  //   // Check if there are at least one Q-peak and one S-peak
  //   if (qPeaks.isEmpty || sPeaks.isEmpty) {
  //     throw Exception(
  //         "Insufficient Q-peaks or S-peaks to calculate QS interval");
  //   }
  // }

  double calculateBPM(rrInterval) {
    // Calculate RR interval using the provided function
    // double rrInterval = calculateRRInterval(ecgData);

    // Calculate BPM using the formula: BPM = 60 / RR interval
    double bpm = 60 / rrInterval;
    // print("Calculate BPM Function ${bpm}");
    // print(bpm);
    return bpm;
  }

  double calculateRRInterval(List<double> ecgData, {int sampleRate = 300}) {
    this.samplingRate = sampleRate;
    // print("RR Interval Calculator");
    // Find R-peaks in the ECG signal
    rPeaks = findRPeaksPanTompkins(ecgData, sampleRate: samplingRate);

    // Check if there are at least three R-peaks
    if (rPeaks.length <= 1) {
      throw Exception("Insufficient R-peaks to calculate RR interval");
    }

    // Calculate RR interval using the first and second R-peaks
    int secondRPeakIndex = rPeaks[0];
    int thirdRPeakIndex = rPeaks[1];

    double rrInterval = (thirdRPeakIndex - secondRPeakIndex) / samplingRate;

    return rrInterval;
  }

  List<int> findRPeaksPanTompkins(
    List<double> ecgData, {
    int sampleRate = 300,
  }) {
    this.samplingRate = sampleRate;
    List<int> rPeaks = PanThonkins().getRPeaks(ecgData, samplingRate);
    // print("RPEAKS");
    // print(rPeaks);
    return rPeaks;
  }

  List<int> findRPeaks(List<double> ecgData) {
    List<int> rPeaks = [];
    // double rThreshold = 300.0; // Adjust this value based on your data characteristics
    // List<double> smoothedData =
    // movingAverage(ecgData, 3); // Adjust the window size as needed

    int peakIndex = -1;
    double peakValue = double.negativeInfinity;

    for (int i = 1; i < ecgData.length - 1; i++) {
      // Simple peak detection: Check if the current value is greater than the threshold
      if (ecgData[i] > rThreshold) {
        // Update peak if the current value is greater than the previously identified peak value
        if (ecgData[i] > peakValue) {
          peakValue = ecgData[i];
          peakIndex = i;
        }
      } else if (peakIndex != -1) {
        // If the current value is not greater than the threshold,
        // consider the previous peak as a valid R-peak
        rPeaks.add(peakIndex);
        peakIndex = -1;
        peakValue = double.negativeInfinity;
      }
    }

    // If the last value is part of an R-peak, consider it as well
    if (peakIndex != -1) {
      rPeaks.add(peakIndex);
    }

    return rPeaks;
  }

  //  Depreciated
  //  List<int> findRPeaks(List<double> ecgData) {
  //    List<int> rPeaks = [];
  // // Adjust this value based on your data characteristics
  //    List<double> smoothedData =
  //    movingAverage(ecgData, 3); // Adjust the window size as needed
  //
  //    for (int i = 1; i < smoothedData.length - 1; i++) {
  //      // Simple peak detection: Check if the current value is greater than both neighbors
  //
  //      if (smoothedData[i] > rThreshold) {
  //        print(smoothedData[i]);
  //        print(rThreshold);
  //
  //        // print(i);
  //        rPeaks.add(i);
  //      }
  //    }
  //    // print(rPeaks);
  //    return rPeaks;
  //  }

  List<dynamic> findQStarts() {
    List<dynamic> qStarts = [];
    //
    for (int i = 0; i < pStart.length; i++) {
      dynamic pS = pStart[i];
      // mark the closes entry from pS["index"] to the baseline[pS] as qStart from after next 36 to 60 entries
      int windowStart = max(0, pS["index"] + 36);
      int windowEnd = 0;
      if (pS["index"] + 60 <= qPeaks[i]) {
        windowEnd = min(ecgData.length - 1, pS["index"] + 60);
      } else {
        windowEnd = min(ecgData.length - 1, qPeaks[i]);
      }
      // mark the highest value from this window
      int maxIndex = windowStart;
      double maxValue = ecgData[windowStart];
      for (int i = windowStart + 1; i <= windowEnd; i++) {
        if (ecgData[i] > maxValue) {
          maxValue = ecgData[i];
          maxIndex = i;
        }
      }
      qStarts.add({"index": maxIndex, "value": realEcgData[maxIndex]});
    }
    return qStarts;
  }

  List<dynamic> findSEnds(List<double> ecgData, List<int> sPeaks) {
    List<dynamic> sEnds = [];

    for (int sPeak in sPeaks) {
      int windowStart = sPeak; // Adjust window start to S peak
      int windowEnd = max(0, sPeak - 20); // Adjust window end

      // Flag to indicate if S wave is detected
      bool inSWave = false;
      int sEndIndex = -1;

      for (int i = windowStart; i >= windowEnd; i--) {
        // Check if signal returns to baseline
        if (ecgData[i] >= baseline[i] && inSWave) {
          // End of S wave
          sEndIndex = i + 1; // Adjust index to the end of S wave
          break;
        } else if (ecgData[i] < baseline[i] && !inSWave) {
          inSWave = true; // Start of S wave
        }
      }

      // Add the index and value of the end of S wave
      if (sEndIndex != -1) {
        sEnds.add({"index": sEndIndex, "value": realEcgData[sEndIndex]});
      }
    }

    return sEnds;
  }

  List<int> findQPeaks(List<double> ecgData) {
    List<int> qPeaks = [];

    for (int rPeak in rPeaks) {
      int windowStart = max(0, rPeak - 24);
      int windowEnd = min(ecgData.length - 1, rPeak);

      int minIndex = windowStart;
      double minValue = ecgData[windowStart];

      for (int i = windowStart + 1; i <= windowEnd; i++) {
        if (ecgData[i] < minValue) {
          minValue = ecgData[i];
          minIndex = i;
        }
      }

      qPeaks.add(minIndex);
    }

    return qPeaks;
  }

  // depreciated
  // List<int> findQPeaks(List<double> ecgData) {
  //   List<int> qPeaks = [];
  //   double threshold =
  //       500; // Adjust this value based on your data characteristics
  //   List<double> smoothedData =
  //       movingAverage(ecgData, 3); // Adjust the window size as needed
  //
  //   for (int i = 1; i < smoothedData.length - 1; i++) {
  //     // Simple peak detection: Check if the current value is less than both neighbors
  //     if (smoothedData[i] < smoothedData[i - 1] &&
  //         smoothedData[i] < smoothedData[i + 1] &&
  //         smoothedData[i] < threshold) {
  //       qPeaks.add(i);
  //     }
  //   }
  //
  //   return qPeaks;
  // }

  double calculateQTInterval(List<double> ecgData) {
    // print("QT Interval Calculator");
    List<double> valQt = [];
    for (int i = 0; i < tEnds.length; i++) {
      int tEndIndex = tEnds[i]["index"];
      int qIndex = qPeaks[i];
      double qtInterval = (tEndIndex - qIndex) / samplingRate;
      // print("QT Interval ${qtInterval}");
      if (qtInterval >= 0.30 && qtInterval <= 0.55) {
        valQt.add(qtInterval);
      }
    }
    // print("VAL QT");
    // print(valQt);
    double qtInterval = _calculateAverage(valQt);
    //
    //
    // // Check if there are at least one Q-peak and one T-peak
    // if (qPeaks.isEmpty || tPeaks.isEmpty) {
    //   throw Exception(
    //       "Insufficient Q-peaks or T-peaks to calculate QT interval");
    // }
    //
    // // Calculate QT interval using the first Q-peak and T-peak
    // int firstQPeakIndex = QStarts[0]["index"];
    // int firstTPeakIndex = tEnds[0]["index"];
    //
    // double qtInterval = (firstTPeakIndex - firstQPeakIndex) / samplingRate;
    return qtInterval;
  }

  List<int> findSPeaks(List<double> ecgData) {
    // This could involve searching for the local minimum after each R-peak
    // Adjust the algorithm according to your signal characteristics
    // For simplicity, we'll use a basic search for the minimum in a window:
    List<int> sPeaks = [];

    for (int rPeak in rPeaks) {
      int windowStart = max(0, rPeak);
      int windowEnd = min(ecgData.length - 1, rPeak + 24);

      int minIndex = windowStart;
      double minValue = ecgData[windowStart];

      for (int i = windowStart + 1; i <= windowEnd; i++) {
        if (ecgData[i] < minValue) {
          minValue = ecgData[i];
          minIndex = i;
        }
      }

      sPeaks.add(minIndex);
    }

    return sPeaks;
  }

  List<dynamic> findTEnd() {
    List<dynamic> tEndIndexes = [];

    for (int tIndex in tPeaks) {
      // Assuming the end of the T wave is when the signal returns to the baseline
      double baseline = 0; // Update this with your baseline value
      int endIndex = tIndex;
      int windowStart = max(0, tIndex); // Adjust window start
      int windowEnd = min(ecgData.length - 1, tIndex + 20); // Adjust window end

      for (int i = windowStart; i <= windowEnd; i++) {
        if (ecgData[i] <= baseline) {
          endIndex = i;
        }
      }

      tEndIndexes.add({"index": endIndex, "value": realEcgData[endIndex]});
    }

    return tEndIndexes;
  }

  List<int> findTPeaks(List<double> ecgData) {
    List<int> tPeaks = [];

    for (int sPeak in sPeaks) {
      int windowStart = max(0, sPeak);
      int windowEnd = min(
        ecgData.length - 1,
        sPeak + 120,
      ); // Adjust the window size as needed

      int maxIndex = windowStart;
      double maxValue = ecgData[windowStart];

      for (int i = windowStart + 1; i <= windowEnd; i++) {
        if (ecgData[i] > maxValue) {
          maxValue = ecgData[i];
          maxIndex = i;
        }
      }

      tPeaks.add(maxIndex);
    }

    return tPeaks;
  }

  // depreciated
  // List<int> findTPeaks(List<double> ecgData) {
  //   List<int> tPeaks = [];
  //   double threshold =
  //       700; // Adjust this value based on your data characteristics
  //   List<double> smoothedData =
  //       movingAverage(ecgData, 3); // Adjust the window size as needed
  //
  //   for (int i = 1; i < smoothedData.length - 1; i++) {
  //     // Simple peak detection: Check if the current value is greater than both neighbors
  //     if (smoothedData[i] > smoothedData[i - 1] &&
  //         smoothedData[i] > smoothedData[i + 1] &&
  //         smoothedData[i] > threshold) {
  //       tPeaks.add(i);
  //     }
  //   }
  //
  //   return tPeaks;
  // }

  // Simple moving average filter
  List<double> movingAverage(List<double> data, int windowSize) {
    List<double> result = [];

    for (int i = 0; i < data.length; i++) {
      int start = i - windowSize ~/ 2;
      int end = i + windowSize ~/ 2;

      if (start < 0) {
        start = 0;
      }

      if (end >= data.length) {
        end = data.length - 1;
      }

      double sum = 0;
      for (int j = start; j <= end; j++) {
        sum += data[j];
      }

      result.add(sum / (end - start + 1));
    }

    return result;
  }

  getMeanRR(List<double> rrIntervalsMs) {
    double sum = 0;
    for (int i = 0; i < rrIntervalsMs.length; i++) {
      sum += rrIntervalsMs[i];
    }
    double mean = sum / rrIntervalsMs.length;
    return mean;
  }

  getSTDRR(List<double> rrIntervalsMs) {
    double mean = getMeanRR(rrIntervalsMs);
    double sum = 0;
    for (int i = 0; i < rrIntervalsMs.length; i++) {
      sum += pow(rrIntervalsMs[i] - mean, 2);
    }
    double std = sqrt(sum / rrIntervalsMs.length);
    return std;
  }

  getEveryRRHeartRate(List<double> rrIntervalsMs) {
    List<double> heartRates = [];
    for (int i = 0; i < rrIntervalsMs.length; i++) {
      heartRates.add(60 / rrIntervalsMs[i]);
    }
    return heartRates;
  }

  getMeanHeartRate(List<double> rrIntervalsMs) {
    List<double> heartRates = getEveryRRHeartRate(rrIntervalsMs);
    double sum = 0;
    for (int i = 0; i < heartRates.length; i++) {
      sum += heartRates[i];
    }
    double mean = sum / heartRates.length;
    return mean;
  }

  getSTDHeartRate(List<double> rrIntervalsMs) {
    List<double> heartRates = getEveryRRHeartRate(rrIntervalsMs);
    double mean = getMeanHeartRate(rrIntervalsMs);
    double sum = 0;
    for (int i = 0; i < heartRates.length; i++) {
      sum += pow(heartRates[i] - mean, 2);
    }
    double std = sqrt(sum / heartRates.length);
    return std;
  }

  double getAverageBPM(
    List<double> rrIntervalsSeconds, {
    int sampleRate = 300,
  }) {
    this.samplingRate = sampleRate;
    double sum = 0;
    int count = 0;

    for (int i = 0; i < rrIntervalsSeconds.length; i++) {
      // Validate RR interval: only include values within the valid range (0.3 to 2.0 seconds)
      if (rrIntervalsSeconds[i] >= 0.3 && rrIntervalsSeconds[i] <= 2.0) {
        sum += rrIntervalsSeconds[i];
        count++;
      }
    }

    // If no valid intervals are found, return 0 or an appropriate default value
    if (count == 0) {
      return 0.0; // or throw an exception, or return null if necessary
    }

    double average = sum / count;

    // Convert seconds to BPM
    return 60 / average;
  }

  double getMaxBPM(List<double> rrIntervalsSeconds) {
    double min = double.infinity;

    for (int i = 0; i < rrIntervalsSeconds.length; i++) {
      // Validate RR interval: ignore values outside the valid range (e.g., 0.3 to 2 seconds)
      if (rrIntervalsSeconds[i] >= 0.3 && rrIntervalsSeconds[i] <= 2.0) {
        if (rrIntervalsSeconds[i] < min) {
          min = rrIntervalsSeconds[i];
        }
      }
    }

    // If no valid intervals are found, return 0 or an appropriate default value
    if (min == double.infinity) {
      return 0.0; // or throw an exception, or return null if necessary
    }

    // Convert seconds to BPM
    return 60 / min;
  }

  double getMinBPM(List<double> rrIntervalsSeconds) {
    double max = double.negativeInfinity;

    for (int i = 0; i < rrIntervalsSeconds.length; i++) {
      // Validate RR interval: ignore values outside the valid range (e.g., 0.3 to 2.0 seconds)
      if (rrIntervalsSeconds[i] >= 0.3 && rrIntervalsSeconds[i] <= 2.0) {
        if (rrIntervalsSeconds[i] > max) {
          max = rrIntervalsSeconds[i];
        }
      }
    }

    // If no valid intervals are found, return 0 or an appropriate default value
    if (max == double.negativeInfinity) {
      return 0.0; // or throw an exception, or return null if necessary
    }

    // Convert seconds to BPM
    return 60 / max;
  }

  getRMSSD(List<double> rrIntervalsMs) {
    double sum = 0;
    for (int i = 0; i < rrIntervalsMs.length - 1; i++) {
      sum += pow(rrIntervalsMs[i + 1] - rrIntervalsMs[i], 2);
    }
    double rmsd = sqrt(sum / (rrIntervalsMs.length - 1));
    rmsd = rmsd * 1000;
    return rmsd;
  }

  // NN50
  getNN50(List<double> rrIntervalsMs) {
    int count = 0;
    for (int i = 0; i < rrIntervalsMs.length - 1; i++) {
      if ((rrIntervalsMs[i + 1] - rrIntervalsMs[i]).abs() > 0.050) {
        count++;
      }
    }
    var res = {"nn50": count, "pnn50": (count / rrIntervalsMs.length * 100)};
    return res;
  }

  //   get Poincaré plot data
  getPoincarePlotData(List<double> rrIntervalsMs) {
    List<double> x = [];
    List<double> y = [];
    for (int i = 0; i < rrIntervalsMs.length - 1; i++) {
      x.add(rrIntervalsMs[i]);
      y.add(rrIntervalsMs[i + 1]);
    }
    return {"x": x, "y": y};
  }

  List<double> filterEctopicBeats(
    List<double> rrIntervals, {
    double thresholdPercentage = 35.0,
  }) {
    // Early exit if list is too short to process
    if (rrIntervals.length < 2) return rrIntervals;

    List<double> filteredRRIntervals = [];
    double meanRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    try {
      // Filter the RR intervals
      for (int i = 0; i < rrIntervals.length; i++) {
        double deviation = (rrIntervals[i] - meanRR).abs() / meanRR * 100;
        if (deviation <= thresholdPercentage) {
          filteredRRIntervals.add(rrIntervals[i]);
        }
      }
    } catch (e) {
      print(e);
    }

    return filteredRRIntervals;
  }

  //   RR Triangular Index
  double calculateRRTriangularIndex(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.isEmpty) {
      throw Exception('RR intervals list cannot be empty.');
    }

    Map<double, int> histogram = _createHistogram(
      rrIntervalsMs,
      binSize: 7.8125,
    ); // Bin size in ms

    int maxCount = histogram.values.reduce((a, b) => a > b ? a : b);
    int totalCount = rrIntervalsMs.length;

    double rrTriangularIndex = totalCount / maxCount.toDouble();
    return rrTriangularIndex;
  }

  // Helper method to create a histogram from RR intervals
  Map<double, int> _createHistogram(List<double> data, {double binSize = 8.0}) {
    Map<double, int> histogram = HashMap();
    for (double value in data) {
      double binKey = (value / binSize).floor() * binSize;
      histogram.update(binKey, (count) => count + 1, ifAbsent: () => 1);
    }
    return histogram;
  }

  List<double> interpolateRRIntervals(List<double> rrIntervals, double nnMean) {
    if (rrIntervals.isEmpty) return [];

    List<double> interpolatedRR = List.filled(rrIntervals.length, 0);
    List<double> cumRRTime = List.filled(rrIntervals.length, 0.0);

    // Calculate cumulative RR times
    cumRRTime[0] = rrIntervals[0].toDouble();
    for (int i = 1; i < rrIntervals.length; i++) {
      cumRRTime[i] = cumRRTime[i - 1] + rrIntervals[i];
    }

    // Interpolation process
    double currentTime = 0.0;
    int index = 0;
    for (int i = 0; i < rrIntervals.length; i++) {
      currentTime += nnMean;
      while (index < cumRRTime.length - 1 && currentTime > cumRRTime[index]) {
        index++;
      }

      if (index == 0 || index >= cumRRTime.length - 1) continue;

      // Linear interpolation
      double t1 = cumRRTime[index - 1];
      double t2 = cumRRTime[index];
      double r1 = rrIntervals[index - 1].toDouble();
      double r2 = rrIntervals[index].toDouble();

      // Calculate interpolated RR interval at the current time
      interpolatedRR[i] = ((r2 - r1) / (t2 - t1) * (currentTime - t1) + r1);
    }

    return interpolatedRR;
  }

  // Parabolic
  List<double> interpolate(List<double> data) {
    // Result list to hold interpolated values
    List<double> interpolated = [];

    // Time between data points, assuming 2 Hz frequency
    double dt = 0.5;

    // Loop over the data points, skipping the first and last for boundary issues
    for (int i = 1; i < data.length - 1; i++) {
      // Use three points to form a parabola: (x1, y1), (x2, y2), (x3, y3)
      double x1 = (i - 1) * dt;
      double x2 = i * dt;
      double x3 = (i + 1) * dt;
      double y1 = data[i - 1];
      double y2 = data[i];
      double y3 = data[i + 1];

      // Calculate coefficients of the parabola: ax^2 + bx + c
      double denom = (x1 - x2) * (x1 - x3) * (x2 - x3);
      double a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / denom;
      double b =
          (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) /
          denom;
      double c =
          (x2 * x3 * (x2 - x3) * y1 +
              x3 * x1 * (x3 - x1) * y2 +
              x1 * x2 * (x1 - x2) * y3) /
          denom;

      // Interpolate at midpoint between x2 and x3
      double midPoint = x2 + dt / 2;
      double interpolatedValue = a * midPoint * midPoint + b * midPoint + c;

      // Add interpolated value to the result
      interpolated.add(interpolatedValue);
    }

    // Return the interpolated values
    return interpolated;
  }

  List<double> interpolateLiniar(
    List<double> times,
    List<double> values,
    double frequency,
  ) {
    if (times.isEmpty || values.isEmpty || times.length != values.length) {
      return [];
    }

    double interval = 1 / frequency;
    List<double> newTimes = [
      for (double t = times.first; t <= times.last; t += interval) t,
    ];
    List<double> interpolatedValues = [];

    for (double newTime in newTimes) {
      int i = times.indexWhere((t) => t >= newTime);
      if (i == 0) {
        interpolatedValues.add(values.first);
      } else if (i == -1) {
        interpolatedValues.add(values.last);
      } else {
        double t1 = times[i - 1];
        double t2 = times[i];
        double v1 = values[i - 1];
        double v2 = values[i];
        double interpolatedValue =
            v1 + (v2 - v1) * ((newTime - t1) / (t2 - t1));
        interpolatedValues.add(interpolatedValue);
      }
    }

    return interpolatedValues;
  }

  // List<double> performWelchFFT(List<double> interpolatedData,
  //     {int segmentLength = 100, double overlap = 0.5}) {
  //   // print("WELCH FFT");
  //   int N = interpolatedData.length;
  //
  //   int fftPoints = math.pow(2, (math.log(N) / math.ln2).ceil()).toInt();
  //   // print("FFT Points: $fftPoints");
  //
  //   // print("interpolated DataLen");
  //   // print(N);
  //   int stepSize = (segmentLength * (1 - overlap)).floor();
  //
  //   List<double> psdAverage = List.filled((segmentLength / 2).floor(), 0.0);
  //   int count = 0;
  //
  //   for (int start = 0; start + segmentLength <= N; start += stepSize) {
  //     // print("here");
  //     List<double> segment =
  //     interpolatedData.sublist(start, start + segmentLength);
  //     var h = hamming(segment.length, sym: true);
  //     List<double> hammingWindow = h.map((e) => e.toDouble()).toList();
  //     List<double> windowedData =
  //     List<double>.generate(segment.length, (int i) {
  //       return segment[i] * hammingWindow[i];
  //     });
  //     // Perform FFT on the windowed data, zero-padded to fftPoints if necessary
  //     List<double> paddedData = List<double>.filled(fftPoints, 0.0);
  //     for (int i = 0; i < segment.length; i++) {
  //       paddedData[i] = windowedData[i];
  //     }
  //
  //     final fastft = FFT(paddedData.length);
  //     final fftData = fastft.realFft(paddedData);
  //     // print("fftLength");
  //     // print(fftData.length);
  //
  //     // print("FFT done");
  //     List<double> psd = fftData
  //         .map((complex) =>
  //     (complex.x * complex.x + complex.y * complex.y) / segment.length)
  //         .toList();
  //
  //     // multiply with hamming window again
  //     // for (int i = 0; i < psd.length; i++) {
  //     //   psd[i] *= hammingWindow[i];
  //     // }
  //     try {
  //       for (int i = 0; i < psdAverage.length - 1; i++) {
  //         // print("PSD AVR");
  //         psdAverage[i] += psd[i];
  //       }
  //     } catch (e) {
  //       print(e);
  //     }
  //     // print("LOOP DONE");
  //     count++;
  //   }
  //
  //   // print("Welch done");
  //
  //   for (int i = 0; i < psdAverage.length; i++) {
  //     psdAverage[i] /= count; // Average the sum of the PSDs
  //   }
  //   // print("WELCH END");
  //   // psdAverage.removeRange(0, 1);
  //
  //   // print("PSD LENGTH");
  //   List<double> flist = List<double>.from(psdAverage);
  //   flist.removeRange(0, 1);
  //   // print(flist.length);
  //   // print(flist);
  //
  //   return flist;
  // }
  //
  // performFFT(List<double> interpolatedData) {
  //   int N = interpolatedData.length;
  //   var h = hamming(N, sym: true);
  //   List<double> hammingWindow = h.map((e) => e.toDouble()).toList();
  //   // return hammingWindow;
  //   List<double> windowedData = List<double>.generate(N, (int i) {
  //     return interpolatedData[i] * hammingWindow[i];
  //   });
  //   final fastft = FFT(windowedData.length);
  //   final fftData = fastft.realFft(windowedData);
  //
  //   // make it list double
  //   List<double> psdDouble = fftData
  //       .map((complex) =>
  //   (complex.x * complex.x + complex.y * complex.y) /
  //       interpolatedData.length)
  //       .toList();
  //
  //   psdDouble.removeRange(0, 1);
  //   // smotthen
  //   psdDouble = movingAverage(psdDouble, 3);
  //   return psdDouble;
  // }

  Map<String, List<double>> makePeriodogram(psdValues, int totalPoints) {
    final int samplingRate = 2; // Sampling rate in Hz (e.g., 1000 Hz)

    // Example PSD values from your FFT processing

    // Calculate frequencies
    List<double> frequencies = List.generate(totalPoints, (index) {
      return index * samplingRate / totalPoints;
    });

    // Since we usually plot half the spectrum (up to the Nyquist frequency)
    int halfPoint = totalPoints ~/ 2;
    List<double> plotFrequencies = frequencies.sublist(0, halfPoint);
    List<double> plotPsdValues = psdValues.sublist(0, halfPoint);

    // Print the arrays to verify or use them directly in your plotting function
    return {"frequencies": plotFrequencies, "psdValues": plotPsdValues};
  }

  Map<String, Map> computeFrequencyBandPowers(
    List<double> psd,
    int interpolatedDataLength,
  ) {
    // Assume the effective sampling rate
    double fs = 2; // Hz of the interpolation
    double N = 512;
    double frequencyResolution = fs / N;
    List<double> frequencies = List.generate(psd.length, (index) {
      return index * fs / psd.length;
    });
    double ulfPower = 0, vlfPower = 0, lfPower = 0, hfPower = 0;
    double ulfPeakPower = 0, vlfPeakPower = 0, lfPeakPower = 0, hfPeakPower = 0;
    double ulfPeakFreq = 0, vlfPeakFreq = 0, lfPeakFreq = 0, hfPeakFreq = 0;

    for (int i = 0; i < psd.length; i++) {
      // fix frequency to 2 decimal places
      // frequency = double.parse((frequency).toStringAsFixed(2));
      if (frequencies[i] >= 0 && frequencies[i] < 0.04) {
        vlfPower += psd[i] * frequencyResolution;
        if (psd[i] > vlfPeakPower) {
          vlfPeakPower = psd[i];
          vlfPeakFreq = frequencies[i];
        }
      } else if (frequencies[i] >= 0.04 && frequencies[i] < 0.15) {
        lfPower += psd[i] * frequencyResolution;
        if (psd[i] > lfPeakPower) {
          lfPeakPower = psd[i];
          lfPeakFreq = frequencies[i];
        }
      } else if (frequencies[i] >= 0.15 && frequencies[i] < 0.4) {
        hfPower += psd[i] * frequencyResolution;
        if (psd[i] > hfPeakPower) {
          hfPeakPower = psd[i];
          hfPeakFreq = frequencies[i];
        }
      }
    }

    // convert powers to ms^2
    // ulfPower = ulfPower * 1000;
    // vlfPower = vlfPower * 1000;
    // lfPower = lfPower * 1000;
    // hfPower = hfPower * 1000;
    // ulfPeakPower = ulfPeakPower * 1000;
    // vlfPeakPower = vlfPeakPower * 1000;
    // lfPeakPower = lfPeakPower * 1000;
    // hfPeakPower = hfPeakPower * 1000;
    double totalPower = ulfPower + vlfPower + lfPower + hfPower;

    // Map to return the powers and peak information
    return {
      'TotalPower': {"Power": totalPower},
      'ULF': {
        'Power': ulfPower,
        'Peak': {'Power': ulfPeakPower, 'Frequency': ulfPeakFreq},
      },
      'VLF': {
        'Power': vlfPower,
        'Peak': {'Power': vlfPeakPower, 'Frequency': vlfPeakFreq},
      },
      'LF': {
        'Power': lfPower,
        'Peak': {'Power': lfPeakPower, 'Frequency': lfPeakFreq},
      },
      'HF': {
        'Power': hfPower,
        'Peak': {'Power': hfPeakPower, 'Frequency': hfPeakFreq},
      },
    };
  }

  // Map<String, double> computeFrequencyBandPowers(List<double> psd, interpolatedDataLength) {
  //   // Assume the effective sampling rate
  //   double fs = 2.0; // Hz of the interpolation
  //   int n = interpolatedDataLength;
  //   double frequencyResolution = fs / n;
  //   double ulfPower = 0, vlfPower = 0, lfPower = 0, hfPower = 0;
  //   for (int i = 0; i < psd.length; i++) {
  //     double frequency = i * frequencyResolution;
  //    if (frequency >= 0 && frequency < 0.04) {
  //       vlfPower += psd[i];
  //     } else if (frequency >= 0.04 && frequency < 0.15) {
  //       lfPower += psd[i];
  //     } else if (frequency >= 0.15 && frequency < 0.45) {
  //       hfPower += psd[i];
  //     }
  //   }
  //
  //   // Map to return the powers
  //   return {'ULF': ulfPower, 'VLF': vlfPower, 'LF': lfPower, 'HF': hfPower};
  // }

  List<double> calculateFrequencyBins(int numDataPoints, double samplingRate) {
    int numFrequencyBins = (numDataPoints ~/ 2) + 1; // Include zero frequency
    double frequencyResolution = samplingRate / numDataPoints;

    List<double> frequencyBins = List.generate(
      numFrequencyBins,
      (index) => frequencyResolution * index,
    );

    return frequencyBins;
  }

  calculateSD1SD2(var data) {
    List<dynamic> x = data['x']!;
    List<dynamic> y = data['y']!;

    List<double> differences = [];
    List<double> sums = [];

    for (int i = 0; i < x.length; i++) {
      differences.add(y[i] - x[i]);
      sums.add(y[i] + x[i]);
    }

    double sd1 = sqrt(0.5 * calculateVariance(differences));
    double sd2 = sqrt(0.5 * calculateVariance(sums));

    // convert seconds to ms
    sd1 = sd1 * 1000;
    sd2 = sd2 * 1000;

    // print('SD1 = $sd1');
    // print('SD2 = $sd2');
    return {"sd1": sd1, "sd2": sd2};
  }

  double calculateVariance(List<double> values) {
    double mean = values.reduce((a, b) => a + b) / values.length;
    return values.map((value) => pow(value - mean, 2)).reduce((a, b) => a + b) /
        values.length;
  }

  double calculatePNSHealthIndex(double hr, double rmssd, double hf) {
    // Convert sdnn seconds to ms
    // rmssd = rmssd * 1000;
    // print("CPNS");
    // print(hr);
    // print(rmssd);
    // print(hf);

    // Define the min and max values for HR, SDNN, and HF
    const double minHR = 60.0;
    const double maxHR = 90.0;
    const double minRMSSD = 15.0;
    const double maxRMSSD = 60.0;
    const double minSD1SD2 = 300.0;
    const double maxSD1SD2 = 2000.0;

    // Normalize HR
    double normalizedHR = (hr - minHR) / (maxHR - minHR);

    // Normalize SDNN
    double normalizedRMSSD = (rmssd - minRMSSD) / (maxRMSSD - minRMSSD);

    // Normalize HF
    double normalizedSD1SD2 = (hf - minSD1SD2) / (maxSD1SD2 - minSD1SD2);

    // Calculate the combined index as the average of normalized values
    double combinedIndex =
        (normalizedHR + normalizedRMSSD + normalizedSD1SD2) / 3;

    return combinedIndex;
  }

  double calculateStressIndex(List<double> rrIntervals) {
    rrIntervals = rrIntervals.map((e) => e * 1000).toList();
    // print("RR");
    // print(rrIntervals);
    if (rrIntervals.isEmpty) {
      print('RR intervals list is empty.');
      return 0;
    }

    // Step 1: Create a histogram with a bin width of 50 ms
    int binWidth = 50;
    Map<int, int> rrHistogram = {};

    // Initialize histogram bins from 400 ms to 1400 ms
    for (int i = 400; i <= 1400; i += binWidth) {
      rrHistogram[(i / binWidth).floor()] = 0;
    }

    // Populate histogram bins
    for (double rr in rrIntervals) {
      if (rr >= 400 && rr < 1400) {
        int bin = (rr / binWidth).floor();
        rrHistogram[bin] = (rrHistogram[bin] ?? 0) + 1;
      }
    }

    // Remove bins with zero counts for clarity
    rrHistogram.removeWhere((key, value) => value == 0);
    // print bins with range
    // rrHistogram.forEach((key, value) {
    //   print("${key * binWidth}-${(key + 1) * binWidth}: $value");
    // });

    // 0.3 percent of total rr
    double threshold = 0.3 / 100 * rrIntervals.length;
    // print("Threshold");
    threshold = threshold.roundToDouble();
    // print(threshold);

    // remove bins with less than threshold
    rrHistogram.removeWhere((key, value) => value <= threshold);
    // remove the range of bing from original rr which threshhold was removed
    List<double> newRRIntervals = [];
    for (double rr in rrIntervals) {
      if (rr >= 400 && rr < 1400) {
        int bin = (rr / binWidth).floor();
        if (rrHistogram.containsKey(bin)) {
          newRRIntervals.add(rr);
        }
      }
    }
    rrIntervals = newRRIntervals;

    // rrHistogram.forEach((key, value) {
    //   print("${key * binWidth}-${(key + 1) * binWidth}: $value");
    // });

    double minRR = rrIntervals.reduce(min);
    double maxRR = rrIntervals.reduce(max);

    // Check if the histogram is not empty
    if (rrHistogram.isEmpty) {
      // print(
      //     'Histogram is empty, which might indicate an issue with RR interval data.');
      return 0;
    }

    // Step 2: Determine the Mode (Mo)
    var modeEntry = rrHistogram.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    int modeBin = modeEntry.key;
    // print("MBIN");
    // print(modeBin);
    double mbinStart = minRR + modeBin * binWidth;
    double mbinEnd = mbinStart + binWidth;
    // print("${mbinStart}-${mbinEnd}");
    double mode =
        ((mbinStart + mbinEnd) / 2) /
        1000.0; // Convert to seconds, use bin center
    // print("Mode");
    // print(mode);
    // Step 3: Calculate the Amplitude of Mode (AMo)
    int modeCount = modeEntry.value;
    double aMo = (modeCount / rrIntervals.length) * 100; // Percentage
    // print("AMO");
    // print(aMo);
    // Step 4: Calculate the Maximum (Mx) and Minimum (Mn) RR intervals
    // double maxRR = rrIntervals.reduce(max);
    // double minRR = rrIntervals.reduce(min);

    if (maxRR == minRR) {
      print('Max RR and Min RR are equal, resulting in zero variation.');
      return 0;
    }

    // Convert maxRR and minRR from milliseconds to seconds
    double maxRRSeconds = maxRR / 1000.0;
    double minRRSeconds = minRR / 1000.0;
    // print("MaxRR");
    // print(maxRRSeconds);
    // print("MinRR");
    // print(minRRSeconds);
    // Calculate MxDMn in seconds
    double mxDMn = maxRRSeconds - minRRSeconds;
    // print("MxDMn");
    // print(mxDMn);
    // Step 5: Compute the Stress Index (SI)
    double si = (aMo) / ((2 * mode) * mxDMn);

    return si;
  }

  calculateSNSHealthIndex(double hr, double sdnn, double lfHf) {
    // convert sdnn seconds to ms
    sdnn = sdnn * 1000;
    // print("CSNS");
    // print(hr);
    // print(sdnn);
    // print(lfHf);
    // Define the min and max values for HR, SDNN, and LF/HF
    const double minHR = 60.0;
    const double maxHR = 90.0;
    const double minSDNN = 40.0;
    const double maxSDNN = 200.0;
    const double minLFHF = 0.7;
    const double maxLFHF = 3.5;

    // Normalize HR
    double normalizedHR = (hr - minHR) / (maxHR - minHR);

    // Normalize SDNN
    double normalizedSDNN = (sdnn - minSDNN) / (maxSDNN - minSDNN);

    // Normalize LF/HF
    double normalizedLFHF = (lfHf - minLFHF) / (maxLFHF - minLFHF);

    // Calculate the combined index as the average of normalized values
    double combinedIndex = (normalizedHR + normalizedSDNN + normalizedLFHF) / 3;

    return combinedIndex;
  }

  detectConditions(List<double> rrIntervals, qrs) {
    // print("QRS HERE DC");
    var conditions = [];

    if (rrIntervals.length < 4) {
      // Not enough intervals to check for the condition
      return [];
    }

    // Iterate through the RR intervals to check for tachycardia and bradycardia
    for (int i = 0; i <= rrIntervals.length - 4; i++) {
      bool tachycardiaMet = true;
      bool bradycardiaMet = true;

      // Check four consecutive intervals
      for (int j = i; j < i + 4; j++) {
        double bpm = 60 / rrIntervals[j];

        // Check for tachycardia
        if (bpm <= 100 || bpm > 200) {
          tachycardiaMet = false;
        }

        // Check for bradycardia
        // Check for bradycardia (between 30 and 55 BPM)
        if (bpm >= 55 || bpm < 30) {
          bradycardiaMet = false;
        }

        // If neither condition is met, break the loop
        if (!tachycardiaMet && !bradycardiaMet) {
          break;
        }
      }

      // If tachycardia condition is met, add it to the array
      if (tachycardiaMet) {
        bool conditionExists = conditions.any(
          (condition) => condition["name"] == "Tachycardia",
        );

        if (!conditionExists) {
          conditions.add({"name": "Tachycardia", "index": i});
        }
      }

      // If bradycardia condition is met, add it to the array
      if (bradycardiaMet) {
        bool conditionExists = conditions.any(
          (condition) => condition["name"] == "Bradycardia",
        );

        if (!conditionExists) {
          conditions.add({"name": "Bradycardia", "index": i});
        }
      }
    }

    // Check the single QRS width value for the wide QRS condition
    if (qrs > 120) {
      conditions.add({"name": "Wide QRS"});
    }

    return conditions;
  }

  //   Extract every qrs comples from r point as center
  Map<String, List<List<double>>> extractQRSComplexes(
    List<int> rrIndexes,
    List<double> ecgData, {
    int windowSize = 200,
  }) {
    List<List<double>> qrsComplexes = [];
    List<List<double>> nonComplex = [];
    int halfPoint = windowSize ~/ 2;

    int previousEnd = 0; // To keep track of the end of the last QRS complex

    for (var entry in rrIndexes.asMap().entries) {
      int rPeak = entry.value;
      int start = rPeak - halfPoint;
      int end = rPeak + halfPoint;

      // Ensure the start and end indices are within bounds
      if (start >= 0 && end < ecgData.length) {
        List<double> qrsComplex = ecgData.sublist(start, end + 1);
        qrsComplexes.add(qrsComplex);

        // Extract the non-complex part between the previous end and the current start
        if (previousEnd < start) {
          List<double> nonComplexSegment = ecgData.sublist(previousEnd, start);
          nonComplex.add(nonComplexSegment);
        }

        // Update previousEnd to the current end
        previousEnd = end + 1;
      }
    }

    // Handle the case where there is ECG data after the last QRS complex
    if (previousEnd < ecgData.length) {
      List<double> nonComplexSegment = ecgData.sublist(
        previousEnd,
        ecgData.length,
      );
      nonComplex.add(nonComplexSegment);
    }

    return {"complexes": qrsComplexes, "nonComplex": nonComplex};
  }

  List<List<double>> extractQRSComplexesV2(
    List<int> rrIndexes,
    List<double> ecgData,
  ) {
    List<List<double>> qrsComplexes = [];

    for (int i = 0; i < rrIndexes.length; i++) {
      int rPeak = rrIndexes[i];

      // Calculate the window size dynamically based on average R-R interval
      int previousRPeak = i > 0 ? rrIndexes[i - 1] : rPeak;
      int nextRPeak = i < rrIndexes.length - 1 ? rrIndexes[i + 1] : rPeak;

      int rrInterval = (nextRPeak - previousRPeak) ~/ 2;
      int halfWindowSize = rrInterval ~/ 2;

      int start = rPeak - halfWindowSize;
      int end = rPeak + halfWindowSize;

      // Ensure the start and end indices are within bounds
      if (start >= 0 && end < ecgData.length) {
        List<double> qrsComplex = ecgData.sublist(start, end + 1);
        qrsComplexes.add(qrsComplex);
      }
    }

    return qrsComplexes;
  }

  List<int> detectVentTachy(List<double> rrIntervals) {
    List<int> tachyIndices = [];

    for (int i = 0; i <= rrIntervals.length - 4; i++) {
      // Extract 4 consecutive RR intervals
      List<double> segment = rrIntervals.sublist(i, i + 4);

      // Calculate average RR interval
      double avgRR = segment.reduce((a, b) => a + b) / 4;

      // Convert average RR interval to BPM
      double bpm = 60000 / avgRR;

      // Check if BPM is greater than 135
      if (bpm > 170) {
        tachyIndices.add(i);
      }
    }

    return tachyIndices;
  }

  int calculateHarvardBPM(List<int> rrIndexes, int startSample, int endSample) {
    // Filter RR intervals within the range of samples
    List<int> rrInRange =
        rrIndexes
            .where((index) => index >= startSample && index < endSample)
            .toList();

    // Ensure there are enough R peaks to calculate BPM
    if (rrInRange.length < 2) {
      return 0; // Not enough data to calculate BPM
    }

    // Calculate all R-R intervals in seconds
    List<double> rrIntervals = [];
    for (int i = 1; i < rrInRange.length; i++) {
      rrIntervals.add((rrInRange[i] - rrInRange[i - 1]) / samplingRate);
    }

    // Calculate the average R-R interval
    double averageRRInterval =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    // Calculate BPM from the average R-R interval
    return (60 / averageRRInterval).round();
  }

  Map<String, dynamic> calculateHarvardStepTest(
    List<int> rrIndexes, {
    int sampleRate = 300,
  }) {
    // Sampling rate in Hz
    this.samplingRate = sampleRate;
    // Calculate start and end samples for each time segment
    int start1 = 0; // Start at 0 seconds
    int end1 = 90 * samplingRate; // End at 1 min 30 sec (90 sec)
    int start2 = 90 * samplingRate; // Start at 1 min 30 sec (90 sec)
    int end2 = 150 * samplingRate; // End at 2 min 30 sec (150 sec)
    int start3 = 150 * samplingRate; // Start at 2 min 30 sec (150 sec)
    int end3 = 210 * samplingRate; // End at 3 min 30 sec (210 sec)

    // Calculate BPMs and handle cases with insufficient data
    int bpm1 = 0;
    int bpm2 = 0;
    int bpm3 = 0;
    if (rrIndexes[rrIndexes.length - 1] > end1) {
      bpm1 = calculateHarvardBPM(rrIndexes, start1, end1);
    }
    if (rrIndexes[rrIndexes.length - 1] > end2) {
      bpm2 = calculateHarvardBPM(rrIndexes, start2, end2);
    }
    if (rrIndexes[rrIndexes.length - 1] > end3) {
      bpm3 = calculateHarvardBPM(rrIndexes, start3, end3);
    }
    // Use 0 for missing data in fitness index calculation
    int hr1 = bpm1 > 0 ? bpm1 : 0;
    int hr2 = bpm2 > 0 ? bpm2 : 0;
    int hr3 = bpm3 > 0 ? bpm3 : 0;

    // Calculate Fitness Index if all HR values are available
    int fitnessIndex =
        (hr1 > 0 && hr2 > 0 && hr3 > 0)
            ? (300 * 100 ~/ (2 * (hr1 + hr2 + hr3)))
            : -1; // Return -1 if any HR is missing

    // Return both BPMs and Fitness Index
    return {
      "BPM_1min30sec": bpm1 > 0 ? bpm1 : -1, // Return -1 if not enough data
      "BPM_2min30sec": bpm2 > 0 ? bpm2 : -1, // Return -1 if not enough data
      "BPM_3min30sec": bpm3 > 0 ? bpm3 : -1, // Return -1 if not enough data
      "FitnessIndex": fitnessIndex, // Fitness index or -1 if not enough data
    };
  }

  // PVC DETECTOR MODULE
  List<Map<String, dynamic>> detectAllPVCsFinal({
    double qrsWideThresholdMs = 130,
    double qrsRelativeThreshold = 1.4,
    double earlyRRThreshold = 0.85,
    double compensatoryRRThreshold = 1.15,
    double amplitudeDeviationThreshold = 0.3, // 30% amplitude difference
  }) {
    List<Map<String, dynamic>> pvcBeats = [];

    if (QStarts.isEmpty || SEnds.isEmpty || rPeaks.length < 5) {
      return pvcBeats;
    }

    List<double> qrsDurations = [];
    for (int i = 0; i < QStarts.length && i < SEnds.length; i++) {
      int qStartIndex = QStarts[i]["index"];
      int sEndIndex = SEnds[i]["index"];
      double qrsDuration =
          (sEndIndex - qStartIndex) / samplingRate * 1000; // ms
      qrsDurations.add(qrsDuration);
    }

    double avgQRS =
        qrsDurations
            .sublist(0, min(5, qrsDurations.length))
            .reduce((a, b) => a + b) /
        min(5, qrsDurations.length);
    double avgRAmplitude = calculateRAverageAmplitude();

    List<double> rrIntervals = convertRRIndexesToInterval(
      rPeaks,
      sampleRate: samplingRate,
    );

    for (int i = 1; i < min(qrsDurations.length, rrIntervals.length) - 1; i++) {
      double currentQRS =
          qrsDurations[i + 1]; // 🛠️ Look at the next beat's QRS
      double rrPrev = rrIntervals[i - 1];
      double rrThis = rrIntervals[i];
      double rrNext = rrIntervals[i + 1];
      double rAmplitude = realEcgData[rPeaks[i + 1]] - bottomLine[0];
      double rAmplitudeMv = calculateAmplitude(rAmplitude);

      bool qrsWideEnough = currentQRS > qrsWideThresholdMs;
      bool qrsRelativelyWider = currentQRS > qrsRelativeThreshold * avgQRS;
      bool earlyBeat = rrThis < earlyRRThreshold * rrPrev;
      bool amplitudeDifferent =
          (rAmplitudeMv - avgRAmplitude).abs() / avgRAmplitude >
          amplitudeDeviationThreshold;
      bool compensatoryPause = rrNext > compensatoryRRThreshold * rrPrev;

      bool pvcByMorphology =
          qrsWideEnough &&
          qrsRelativelyWider &&
          amplitudeDifferent &&
          earlyBeat;
      bool pvcByRROnly = earlyBeat && compensatoryPause;

      if (pvcByMorphology) {
        pvcBeats.add({
          "rPeakIndex": rPeaks[i + 1], // 🛠️ Correct Beat: NEXT R-peak
          "method": "Morphology + RR",
          "qrsDurationMs": currentQRS,
          "rAmplitudeMv": rAmplitudeMv,
          "averageRAmpMv": avgRAmplitude,
          "rrPrev": rrPrev,
          "rrThis": rrThis,
          "rrNext": rrNext,
          "confidence": "High",
        });
      } else if (pvcByRROnly) {
        pvcBeats.add({
          "rPeakIndex": rPeaks[i + 1], // 🛠️ Correct Beat: NEXT R-peak
          "method": "RR Only (Fallback)",
          "qrsDurationMs": currentQRS,
          "rAmplitudeMv": rAmplitudeMv,
          "averageRAmpMv": avgRAmplitude,
          "rrPrev": rrPrev,
          "rrThis": rrThis,
          "rrNext": rrNext,
          "confidence": "Medium",
        });
      }
    }
    print(pvcBeats);
    return pvcBeats;
  }

  List<Map<String, dynamic>> detectPVCsFinalCombined({
    double qrsWideThresholdMs = 130,
    double qrsRelativeThreshold = 1.5,
    double earlyBeatRRThreshold = 0.85,
    double rrEarlyThreshold = 0.85,
    double rrCompensatoryThreshold = 1.15,
  }) {
    List<Map<String, dynamic>> pvcBeats = [];

    if (QStarts.isEmpty || SEnds.isEmpty || rPeaks.length < 5) {
      return pvcBeats;
    }

    // --- STEP 1: Strict QRS Width + Early Beat Detection
    List<double> qrsDurations = [];
    for (int i = 0; i < QStarts.length && i < SEnds.length; i++) {
      int qStartIndex = QStarts[i]["index"];
      int sEndIndex = SEnds[i]["index"];
      double qrsDuration =
          (sEndIndex - qStartIndex) / samplingRate * 1000; // milliseconds
      qrsDurations.add(qrsDuration);
    }

    double avgQRS =
        qrsDurations
            .sublist(0, min(5, qrsDurations.length))
            .reduce((a, b) => a + b) /
        min(5, qrsDurations.length);

    List<double> rrIntervals = convertRRIndexesToInterval(
      rPeaks,
      sampleRate: samplingRate,
    );

    for (int i = 1; i < min(qrsDurations.length, rrIntervals.length - 1); i++) {
      double currentQRS = qrsDurations[i];
      double rrPrev = rrIntervals[i - 1];
      double rrThis = rrIntervals[i];
      // rrNext not needed in this strict QRS + Early RR step

      bool qrsWideEnough = currentQRS > qrsWideThresholdMs;
      bool qrsRelativelyWider = currentQRS > qrsRelativeThreshold * avgQRS;
      bool earlyBeat = rrThis < earlyBeatRRThreshold * rrPrev;

      if ((qrsWideEnough && qrsRelativelyWider) && earlyBeat) {
        pvcBeats.add({
          "rPeakIndex": rPeaks[i],
          "method": "Strict QRS Width + Early RR",
          "qrsDuration": currentQRS,
          "averageQrsDuration": avgQRS,
          "rrThis": rrThis,
          "confidence": "High",
        });
      }
    }

    // --- STEP 2: If No PVCs Found, Fallback to Pure RR Interval Detector
    if (pvcBeats.isEmpty) {
      for (int i = 1; i < rrIntervals.length - 1; i++) {
        double rrPrev = rrIntervals[i - 1];
        double rrThis = rrIntervals[i];
        double rrNext = rrIntervals[i + 1];

        bool earlyBeat = rrThis < rrEarlyThreshold * rrPrev;
        bool compensatoryPause = rrNext > rrCompensatoryThreshold * rrPrev;

        if (earlyBeat && compensatoryPause) {
          pvcBeats.add({
            "rPeakIndex": rPeaks[i],
            "method": "Pure RR Interval",
            "rrPrev": rrPrev,
            "rrThis": rrThis,
            "rrNext": rrNext,
            "confidence": "Medium",
          });
        }
      }
    }
    print(pvcBeats);
    return pvcBeats;
  }

  List<Map<String, dynamic>> detectPVCsOldSchool({
    double qrsWideThreshold = 120, // 120ms
    double qrsRelativeThreshold = 1.3, // 30% wider than average
    double qrsNarrowThreshold = 50, // Multifocal PVC if very narrow
  }) {
    List<Map<String, dynamic>> pvcBeats = [];

    if (QStarts.isEmpty || SEnds.isEmpty || rPeaks.length < 5) {
      return pvcBeats;
    }

    // Calculate all QRS durations
    List<double> qrsDurations = [];
    for (int i = 0; i < QStarts.length && i < SEnds.length; i++) {
      int qStartIndex = QStarts[i]["index"];
      int sEndIndex = SEnds[i]["index"];
      double qrsDuration =
          (sEndIndex - qStartIndex) / samplingRate * 1000; // milliseconds
      qrsDurations.add(qrsDuration);
    }

    // Calculate average QRS duration
    double avgQRS =
        qrsDurations
            .sublist(0, min(5, qrsDurations.length))
            .reduce((a, b) => a + b) /
        min(5, qrsDurations.length);

    for (int i = 0; i < qrsDurations.length; i++) {
      double currentQRS = qrsDurations[i];

      bool isPVC = false;

      if ((currentQRS / avgQRS > qrsRelativeThreshold &&
              currentQRS > qrsWideThreshold) ||
          (currentQRS < qrsNarrowThreshold && currentQRS > 0)) {
        isPVC = true;
      }

      if (isPVC) {
        pvcBeats.add({
          "rPeakIndex": rPeaks[i],
          "qrsDuration": currentQRS,
          "averageQrsDuration": avgQRS,
          "confidence": "High (QRS Width Rule)",
        });
      }
    }
    print(pvcBeats);
    return pvcBeats;
  }

  convertRRIndexesToInterval(List<int> rrIndexes, {int sampleRate = 300}) {
    this.samplingRate = sampleRate;
    List<double> rrIntervals = [];
    for (int i = 0; i < rrIndexes.length - 1; i++) {
      rrIntervals.add((rrIndexes[i + 1] - rrIndexes[i]) / samplingRate);
    }
    // only 3 decimal places
    rrIntervals =
        rrIntervals.map((e) => double.parse(e.toStringAsFixed(3))).toList();

    return rrIntervals;
  }

  List<Map<String, dynamic>> detectPVCsMorphologyAmplitudeQRS({
    double correlationThreshold = 0.85,
    double amplitudeMultiplierThreshold = 1.5,
    double qrsDurationThreshold = 0.10, // 100 ms
    double compensatoryPauseRatio = 1.10,
  }) {
    List<Map<String, dynamic>> pvcBeats = [];

    if (rPeaks.length < 5 ||
        QStarts.length < 5 ||
        SEnds.length < 5 ||
        pPeaks.length < 5) {
      return pvcBeats;
    }

    List<double> rrIntervals = convertRRIndexesToInterval(
      rPeaks,
      sampleRate: samplingRate,
    );
    Map<String, List<List<double>>> qrsData = extractQRSComplexes(
      rPeaks,
      realEcgData,
      windowSize: 150,
    );
    List<List<double>> qrsComplexes = qrsData["complexes"] ?? [];

    if (qrsComplexes.isEmpty) {
      return pvcBeats;
    }

    // Build normal template
    List<double> normalTemplate = _averageQRS(
      qrsComplexes.sublist(0, min(5, qrsComplexes.length)),
    );

    // Calculate normal R amplitude
    List<double> rAmplitudes = rPeaks.map((idx) => realEcgData[idx]).toList();
    double averageR =
        rAmplitudes
            .sublist(0, min(5, rAmplitudes.length))
            .reduce((a, b) => a + b) /
        min(5, rAmplitudes.length);

    int minLength = min(
      min(rrIntervals.length - 1, qrsComplexes.length),
      min(QStarts.length, SEnds.length),
    );

    for (int i = 1; i < minLength; i++) {
      double rrBefore = rrIntervals[i - 1];
      double rrPVC = rrIntervals[i];
      double rrAfter = rrIntervals[i + 1];

      double thisAmplitude = rAmplitudes[i];
      bool amplitudeHigh =
          thisAmplitude > amplitudeMultiplierThreshold * averageR;

      // Compensatory pause
      bool hasCompensatoryPause = rrAfter > compensatoryPauseRatio * rrBefore;

      // Morphology comparison
      double correlation = _calculateCrossCorrelation(
        normalTemplate,
        qrsComplexes[i],
      );
      bool morphologyDifferent = correlation < correlationThreshold;

      // QRS width check
      int qStartIndex = QStarts[i]["index"];
      int sEndIndex = SEnds[i]["index"];
      double qrsDuration = (sEndIndex - qStartIndex) / samplingRate;
      bool isWideQRS = qrsDuration > qrsDurationThreshold;

      // P-wave check
      bool pWaveMissing = false;
      try {
        int pPeakBeforeR = pPeaks.lastWhere((p) => p < rPeaks[i]);
        double pAmplitude = realEcgData[pPeakBeforeR] - bottomLine[0];
        pAmplitude = pAmplitude * (6 / 4096); // convert to mV

        if (pAmplitude.abs() < 0.05) {
          // 0.05 mV threshold for P-wave disappearance
          pWaveMissing = true;
        }
      } catch (e) {
        // No P-wave found before this R-peak
        pWaveMissing = true;
      }

      // Scoring
      int score = 0;
      if (amplitudeHigh) score++;
      if (morphologyDifferent) score++;
      if (isWideQRS) score++;
      if (hasCompensatoryPause) score++;
      if (pWaveMissing) score++;

      if (score >= 2) {
        // If 2 or more conditions match
        pvcBeats.add({
          "rPeakIndex": rPeaks[i],
          "amplitude": thisAmplitude,
          "averageAmplitude": averageR,
          "qrsDuration": qrsDuration,
          "rrPVC": rrPVC,
          "rrBefore": rrBefore,
          "rrAfter": rrAfter,
          "correlation": correlation,
          "pWaveMissing": pWaveMissing,
          "confidence":
              score >= 4 ? "Very High" : (score == 3 ? "High" : "Medium"),
        });
      }
    }
    print(pvcBeats);
    return pvcBeats;
  }

  // Cross-correlation between two signals
  double _calculateCrossCorrelation(
    List<double> signal1,
    List<double> signal2,
  ) {
    int n = min(signal1.length, signal2.length);
    double mean1 = signal1.sublist(0, n).reduce((a, b) => a + b) / n;
    double mean2 = signal2.sublist(0, n).reduce((a, b) => a + b) / n;

    double numerator = 0;
    double denominator1 = 0;
    double denominator2 = 0;

    for (int i = 0; i < n; i++) {
      numerator += (signal1[i] - mean1) * (signal2[i] - mean2);
      denominator1 += pow(signal1[i] - mean1, 2);
      denominator2 += pow(signal2[i] - mean2, 2);
    }

    return numerator / sqrt(denominator1 * denominator2);
  }

  // Average a list of QRS complexes to create a "normal template"
  List<double> _averageQRS(List<List<double>> qrsList) {
    if (qrsList.isEmpty) return [];

    int length = qrsList[0].length;
    List<double> average = List.filled(length, 0.0);

    for (var qrs in qrsList) {
      for (int i = 0; i < length; i++) {
        average[i] += qrs[i];
      }
    }

    for (int i = 0; i < length; i++) {
      average[i] /= qrsList.length;
    }

    return average;
  }
}
