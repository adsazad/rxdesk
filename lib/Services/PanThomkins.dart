import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:bluevo2/Services/FilterClass.dart';
import 'package:share_plus/share_plus.dart';

class PanThonkins {
  int samplingRate = 0;
  Future<void> writeDataToFile( integratedData) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = appDocDir.path + '/integratedData.json';
    // print('Directory: ${appDocDir.path}');

    File file = File(filePath);

    await file.writeAsString(jsonEncode(integratedData));
    // print('Array has been written to integratedData.json');
    Share.shareXFiles([XFile(filePath)], text: 'integratedData.json');
    // return ;
  }
  List<int> getRPeaks(List<double> ecgData, int samplingRate) {
    // print("GET RPEAKS");
    this.samplingRate = samplingRate;

    // Step 1: Filter the signal
    List<double> filteredData = filterForRR(ecgData);

    // Step 2: Differentiate the signal
    List<double> differentiatedData = differentiate(filteredData);

    // Step 3: Square the signal
    List<double> squaredData = square(differentiatedData);

    // Step 4: Perform moving window integration
    // int windowSize = 86;
    int windowSize = 15;
    if(samplingRate != 300){
      windowSize = (samplingRate * 0.080).round();
    }
    List<double> integratedData =
    movingWindowIntegration(squaredData, windowSize);

    // writeDataToFile(ecgData)

    // **Compensate for integration lag**
    // int integrationLag = windowSize ~/ 2;
    // integratedData = integratedData.sublist(integrationLag);
    // Track the offset caused by warmup
    int offset = windowSize;

    // Step 5: Thresholding and peak detection
    double threshold = calculateDynamicThreshold(integratedData);
    List<int> rPeaks = detectPeaks(integratedData, threshold);

    // Lower the threshold if no peaks are found
    double minThreshold = threshold * 0.5;
    while (rPeaks.isEmpty && threshold > minThreshold) {
      threshold *= 0.9;
      rPeaks = detectPeaks(integratedData, threshold);
    }

    // Step 6: Adjust peak indices to account for the offset
    rPeaks = rPeaks.map((index) => index + offset).toList();

    // Step 7: Refine the peak locations
    // refineRPeaksToMaxSlope
    // rPeaks = refineRPeaksToMaxSlope(ecgData, rPeaks, windowSize);
    // rPeaks = refineRPeaksToMaxAmplitude(ecgData, rPeaks, windowSize);
    // rPeaks = refinePeakLocations(ecgData, rPeaks, windowSize);

    rPeaks = refinePeaksWithSlopeCheck(ecgData, rPeaks, integratedData, windowSize);
    int qrsWindowSize = (0.080 * samplingRate).toInt(); // 100ms around the peak
    rPeaks = refinePeaksToMaxAmplitudeWithinQRS(ecgData, rPeaks,integratedData, qrsWindowSize);
    // print("PAN RR DETECTED COUNT");
    // print(rPeaks.length);
    // writeDataToFile(rPeaks);

    // clear memory


    return rPeaks;
  }
  List<int> refinePeaksToMaxAmplitudeWithinQRS(
      List<double> ecgData,
      List<int> initialPeaks,
      List<double> integratedData,
      int qrsWindowSize) {
    List<int> refinedPeaks = [];
    int halfWindowSize = qrsWindowSize ~/ 2;

    for (int peak in initialPeaks) {
      // Define the QRS window around the peak
      int start = (peak - halfWindowSize).clamp(0, ecgData.length - 1);
      int end = (peak + halfWindowSize).clamp(0, ecgData.length - 1);

      // Variables to track the maximum amplitude and its index
      double maxAmplitude = ecgData[start];
      int maxAmplitudeIndex = start;

      // Variables to track the maximum slope and its index
      double maxSlope = 0.0;
      int maxSlopeIndex = start;

      for (int i = start + 1; i <= end; i++) {
        // Find the point with the highest amplitude within the QRS window
        if (ecgData[i] > maxAmplitude) {
          maxAmplitude = ecgData[i];
          maxAmplitudeIndex = i;
        }

        // Find the point with the highest slope in the integrated data
        if (i < integratedData.length - 1) {
          double slope = integratedData[i + 1] - integratedData[i];
          if (slope > maxSlope) {
            maxSlope = slope;
            maxSlopeIndex = i + 1;
          }
        }
      }

      // Ensure the peak aligns within QRS boundaries
      int refinedPeak = maxAmplitudeIndex; // Default to max amplitude
      if ((maxSlopeIndex >= start && maxSlopeIndex <= end) &&
          (maxSlopeIndex - maxAmplitudeIndex).abs() <= (qrsWindowSize ~/ 4)) {
        refinedPeak = maxSlopeIndex; // Prefer slope-based if close to amplitude peak
      }

      // Check if the refined peak is valid (not moved to T-wave)
      if (refinedPeak > peak + (0.05 * samplingRate).toInt()) {
        refinedPeak = peak; // Revert to original peak if refinement is beyond QRS duration
      }

      refinedPeaks.add(refinedPeak);
    }

    return refinedPeaks;
  }



  List<int> refinePeaksWithSlopeCheck(List<double> ecgData, List<int> initialPeaks, List<double> integratedData, int windowSize) {
    List<int> refinedPeaks = [];
    int halfWindowSize = windowSize ~/ 2;

    for (int peak in initialPeaks) {
      int start = peak - halfWindowSize;
      int end = peak + halfWindowSize;

      // Ensure indices are within bounds
      start = start.clamp(0, integratedData.length - 2); // -2 to avoid out-of-bounds in slope calculation
      end = end.clamp(0, integratedData.length - 2);

      double maxSlope = 0.0;
      int maxSlopeIndex = peak;

      // Calculate slope and find the point with maximum slope in the integrated data
      for (int i = start; i < end; i++) {
        double slope = integratedData[i + 1] - integratedData[i]; // Slope in integrated data

        // Update if the slope is the maximum found in this range
        if (slope > maxSlope) {
          maxSlope = slope;
          maxSlopeIndex = i + 1;  // Choose the next index since slope is between two points
        }
      }

      refinedPeaks.add(maxSlopeIndex);
    }

    return refinedPeaks;
  }

  List<int> refineRPeaksToMaxSlope(List<double> ecgData, List<int> initialPeaks, int windowSize) {
    List<int> refinedPeaks = [];
    int halfWindowSize = windowSize ~/ 2;

    for (int peak in initialPeaks) {
      int start = peak - halfWindowSize;
      int end = peak + halfWindowSize;

      // Ensure the indices are within bounds
      if (start < 0) start = 0;
      if (end >= ecgData.length) end = ecgData.length - 1;

      // Calculate the slope values within the window
      double maxSlope = 0.0;
      int maxSlopeIndex = start;

      for (int i = start; i < end; i++) {
        double slope = ecgData[i + 1] - ecgData[i];  // Calculate slope between two points

        // Update maxSlope and maxSlopeIndex
        if (slope > maxSlope) {
          maxSlope = slope;
          maxSlopeIndex = i + 1;  // We want the index of the next point as the slope is calculated between two points
        }
      }

      refinedPeaks.add(maxSlopeIndex);
    }

    return refinedPeaks;
  }

  List<double> applyMedianFilter(List<double> signal, int windowSize) {
    List<double> smoothedSignal = List<double>.filled(signal.length, 0.0);

    for (int i = 0; i < signal.length; i++) {
      int start = (i - windowSize ~/ 2).clamp(0, signal.length - 1);
      int end = (i + windowSize ~/ 2).clamp(0, signal.length - 1);
      List<double> window = signal.sublist(start, end + 1)..sort();
      smoothedSignal[i] = window[window.length ~/ 2];  // Median value
    }
    return smoothedSignal;
  }


  List<int> refineRPeaksToMaxAmplitude(List<double> ecgData, List<int> initialPeaks, int windowSize) {
    List<int> refinedPeaks = [];
    int halfWindowSize = windowSize ~/ 2;

    for (int peak in initialPeaks) {
      int start = peak - halfWindowSize;
      int end = peak + halfWindowSize;
      if (start < 0) start = 0;
      if (end >= ecgData.length) end = ecgData.length - 1;

      // Find the point of maximum amplitude within the window
      double maxAmplitude = ecgData[start];
      int maxAmplitudeIndex = start;
      for (int i = start + 1; i <= end; i++) {
        if (ecgData[i] > maxAmplitude) {
          maxAmplitude = ecgData[i];
          maxAmplitudeIndex = i;
        }
      }
      refinedPeaks.add(maxAmplitudeIndex);
    }

    return refinedPeaks;
  }



  List<int> refinePeakLocations(List<double> ecgData, List<int> initialPeaks, int windowSize) {
    List<int> refinedPeaks = [];
    int halfWindowSize = windowSize ~/ 2;

    for (int peak in initialPeaks) {
      int start = peak - halfWindowSize;
      int end = peak + halfWindowSize;
      if (start < 0) start = 0;
      if (end >= ecgData.length) end = ecgData.length - 1;

      double maxVal = ecgData[start];
      int maxIndex = start;
      for (int i = start + 1; i <= end; i++) {
        if (ecgData[i] > maxVal) {
          maxVal = ecgData[i];
          maxIndex = i;
        }
      }
      refinedPeaks.add(maxIndex);
    }

    return refinedPeaks;
  }

  List<int> detectPeaks(List<double> signal, double threshold) {
    List<int> peakIndices = [];
    int refractoryPeriod = (0.500 * samplingRate).round();  // Initial refractory period
    double prevRPeakAmplitude = 0.0;
    double minAmplitudeRatio = 0.6;  // Minimum amplitude ratio to distinguish peaks
    double dynamicThreshold = threshold;  // Adaptive threshold

    for (int i = 1; i < signal.length - 1; i++) {
      // Check for local maximum
      if (signal[i] > dynamicThreshold && signal[i] > signal[i - 1] && signal[i] > signal[i + 1]) {
        // Check refractory period
        if (peakIndices.isEmpty || i - peakIndices.last > refractoryPeriod) {
          // Check amplitude constraint
          if (prevRPeakAmplitude == 0.0 ||
              signal[i] > prevRPeakAmplitude * minAmplitudeRatio ||
              i - peakIndices.last > 2 * refractoryPeriod) {  // Relax condition if RR interval is long

            peakIndices.add(i);
            prevRPeakAmplitude = signal[i];

            // Update refractory period based on the latest RR interval
            if (peakIndices.length > 1) {
              int rrInterval = peakIndices.last - peakIndices[peakIndices.length - 2];
              refractoryPeriod = (0.5 * rrInterval).round();  // Adjust refractory period to 20% of RR interval
            }

            // Adjust the dynamic threshold based on recent peak amplitude
            dynamicThreshold = prevRPeakAmplitude * 0.4;  // Adaptive threshold
            // print("TH: ");
            // print(dynamicThreshold);
          }
        }
      }
    }

    return peakIndices;
  }



  double calculateDynamicThreshold(List<double> signal) {
    if (signal.isEmpty) {
      return 0.0;  // or any default value you deem appropriate
    }

    // Calculate mean and standard deviation
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double sumOfSquares = signal.fold(0.0, (sum, val) => sum + (val - mean) * (val - mean));
    double stdDev = sqrt(sumOfSquares / signal.length);

    return mean + 0.5 * stdDev;  // Adjust based on desired sensitivity
  }

  List<double> movingWindowIntegration(List<double> signal, int windowSize) {
    List<double> integratedSignal = List.filled(signal.length, 0.0);

    for (int i = 0; i < signal.length; i++) {
      double sum = 0.0;
      for (int j = 0; j < windowSize; j++) {
        if (i - j >= 0) {
          sum += signal[i - j];
        }
      }
      integratedSignal[i] = sum / windowSize;
    }

    // Warmup adjustment - skip initial peaks
    int warmup = windowSize;
    List<double> finalIntegrated;

    // Ensure the warmup value is within range
    if (warmup < integratedSignal.length) {
      finalIntegrated = integratedSignal.sublist(warmup);
    } else {
      // If warmup is larger, just use the entire list as a fallback
      finalIntegrated = integratedSignal;
    }

    return finalIntegrated;
  }



  // List<double> movingWindowIntegration(List<double> signal, int windowSize) {
  //   List<double> integratedSignal = [];
  //   for (int i = 0; i < signal.length; i++) {
  //     double sum = 0.0;
  //     for (int j = 0; j < windowSize; j++) {
  //       if (i - j >= 0) {
  //         sum += signal[i - j];
  //       }
  //     }
  //     integratedSignal.add(sum / windowSize);
  //   }
  //   return integratedSignal;
  // }

  List<double> square(List<double> signal) {
    return signal.map((x) => x * x).toList();
  }

  List<double> differentiate(List<double> signal) {
    List<double> differentiatedSignal = [];
    for (int i = 1; i < signal.length; i++) {
      differentiatedSignal.add(signal[i] - signal[i - 1]);
    }
    return differentiatedSignal;
  }

  List<double> filterForRR(List<double> ecgData) {
    FilterClass filterClass = FilterClass();
    double GainFact = 1 / 1.5;
    int Pos = 0;
    int FILT_BUF_SIZE = 3 * 6 + 7;
    List<double> filterBuff = List<double>.filled(FILT_BUF_SIZE, 0.0);
    double sum = 0;

    filterClass!.init(this.samplingRate, 10, 8, 0, 2, 0, 0.65, 5, 2, 6);
    List<double> filteredData = [];

    for (double val in ecgData) {
      int tempPos = 0;
      val = val * GainFact;
      tempPos = Pos;
      filterBuff[Pos] = val;
      for (int stage = 0; stage <= 2; stage++) {
        sum = 0;
        for (int c = 0; c <= 5 - 1; c++) {
          sum = sum + filterBuff[(tempPos + FILT_BUF_SIZE - c) % FILT_BUF_SIZE] * filterClass!.Coeff[stage][c];
        }
        sum = sum * 2;
        filterBuff[(tempPos + 1) % FILT_BUF_SIZE] = sum;
        filterBuff[(tempPos + 6) % FILT_BUF_SIZE] = sum;
        tempPos = (tempPos + 6) % FILT_BUF_SIZE;
      }
      val = sum;
      Pos = (Pos + 2) % FILT_BUF_SIZE;
      filteredData.add(val);
    }

    return filteredData;
  }
}
