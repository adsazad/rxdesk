import 'package:scidart/numdart.dart';

enum WindowType { hanning, hamming, blackman }

class FFTProcessor {
  static const int MAX_FFT_CNT = 512; // Define according to your requirement
  static const int MAX_FFT_PTS = 512; // Define according to your requirement
  static const int SAMPLING_RATE_HZ = 4;
  List<double> realF = [];
  List<double> imagiF = [];
  List<double> sampBuf = [];
  List<double> fr = [];
  List<double> psd = [];
  List<double> interRR = [];
  double nnMean = 0.0;
  List<double> rrIntervals = [];
  List<double> frVals = [];
  List<double> frValX = [];

  double vlfPower = 0;
  double lfPower = 0;
  double hfPower = 0;

  double vlfPercentage = 0;
  double lfPercentage = 0;
  double hfPercentage = 0;

  double lfHfRatio = 0;
  double lfNu = 0;
  double hfNu = 0;

  init(List<double> rrIntervals, RRMean) async {
    nnMean = (RRMean * 1000);
    // remove decimals
    nnMean = nnMean.roundToDouble();
    // print("RR MEAN");
    // print(nnMean);
    this.rrIntervals = rrIntervals;
    // print("INIT FFT Processor");
    calculateFFTPoints(rrIntervals.length);
    List<double> cumRRTime = rrIntervalsToTimePoints(rrIntervals);
    // print("CUMRR");
    // print(cumRRTime);
    interRR = interpolate4Hz(cumRRTime, rrIntervals);
    // Ensure we have a fixed-length buffer for downstream FFT windowing
    if (interRR.isEmpty || interRR.length < MAX_FFT_PTS) {
      interRR = interpolateLiniar(cumRRTime, rrIntervals);
    }
    // print("RRII");
    // print(rrIntervals);
    // print(interRR);
    generateFRValues(WindowType.hamming, interRR);
    return calculatePowerFFT();
    // print(channelResults);
  }

  List<double> interpolate4Hz(List<double> times, List<double> values) {
    if (times.isEmpty || values.isEmpty || times.length != values.length) {
      return [];
    }

    double startTime = times.first;
    double endTime = times.last;
    if (endTime < startTime) {
      endTime = startTime; // avoid empty ranges due to non-monotonic times
    }
    double interval = (1.0 / SAMPLING_RATE_HZ).abs(); // 4 Hz = every 0.25 s

    // Generate new time points at 4 Hz
    List<double> newTimes = [];
    for (double t = startTime; t <= endTime; t += interval) {
      newTimes.add(t);
    }

    // Adjust last time point to exactly match the last original timestamp
    if (newTimes.isNotEmpty && newTimes.last != endTime) {
      newTimes[newTimes.length - 1] = endTime;
    }

    // Perform linear interpolation
    List<double> interpolatedValues = List.filled(newTimes.length, 0.0);
    for (int i = 0; i < newTimes.length; i++) {
      double newTime = newTimes[i];
      int idx = times.indexWhere((t) => t >= newTime);

      if (idx == 0 || idx == -1) {
        interpolatedValues[i] = values[idx == -1 ? values.length - 1 : 0];
      } else {
        double t1 = times[idx - 1];
        double t2 = times[idx];
        double v1 = values[idx - 1];
        double v2 = values[idx];

        final denom = (t2 - t1);
        final alpha = denom != 0 ? ((newTime - t1) / denom) : 0.0;
        interpolatedValues[i] = v1 + (v2 - v1) * alpha;
      }
    }

    return interpolatedValues;
  }

  calculatePowerFFT() {
    int maxFftPoints =
        MAX_FFT_PTS; // Assuming this as per previous conversation
    List<double> spBuff = List.filled(maxFftPoints, 0);
    List<double> freqBand = [
      0.04,
      0.15,
      0.4,
    ]; // Frequency bands for VLF, LF, HF
    List<double> sum = List.filled(3, 0.0);
    List<double> maxFreq = List.filled(3, 0.0);
    List<double> midFreq = List.filled(3, 0.0);
    double resFact = 2 / nnMean;
    double totalAmp = 0;
    double powerFactor = 3;

    // Calculate power for VLF, LF, HF bands
    for (int band = 0; band < 3; band++) {
      int lower = (freqBand[band] / resFact).floor();
      int upper =
          band < 2
              ? (freqBand[band + 1] / resFact).floor()
              : (maxFftPoints / 2).floor();

      for (int i = lower; i < upper && i < maxFftPoints; i++) {
        double val = frVals[i] * pow(10, powerFactor);
        spBuff[i] = val;
        totalAmp += val;
        sum[band] += val;
      }
    }

    // Calculate mid and max frequencies for each band
    for (int j = 0; j < 3; j++) {
      double totPower = 0;
      double max = 0;
      bool isMidFreqFound = false;
      int lower = (freqBand[j] / resFact).floor();
      int upper =
          j < 2
              ? (freqBand[j + 1] / resFact).floor()
              : (maxFftPoints / 2).floor();

      for (int i = lower; i < upper && i < maxFftPoints; i++) {
        double val = spBuff[i];
        totPower += val;
        if (!isMidFreqFound && totPower >= (sum[j] * resFact / 2)) {
          midFreq[j] = i * resFact;
          isMidFreqFound = true;
        }
        if (val > max) {
          max = val;
          maxFreq[j] = i * resFact;
        }
      }
    }

    vlfPower = sum[0];
    lfPower = sum[1];
    hfPower = sum[2];
    vlfPercentage = (vlfPower / totalAmp) * 100;
    lfPercentage = (lfPower / totalAmp) * 100;
    hfPercentage = (hfPower / totalAmp) * 100;
    lfHfRatio = lfPower / hfPower;
    lfNu = lfPercentage / (100 - vlfPercentage) * 100;
    hfNu = hfPercentage / (100 - vlfPercentage) * 100;

    print("Total Input RR: ${rrIntervals.length}");
    print("VLF Power: $vlfPower");
    print("LF Power: $lfPower");
    print("HF Power: $hfPower");
    print("VLF Percentage: $vlfPercentage");
    print("LF Percentage: $lfPercentage");
    print("HF Percentage: $hfPercentage");
    print("LF/HF Ratio: $lfHfRatio");
    print("LFnu: $lfNu");
    print("HFnu: $hfNu");

    return {
      'vlfPower': vlfPower,
      'lfPower': lfPower,
      'hfPower': hfPower,
      'vlfPercentage': vlfPercentage,
      'lfPercentage': lfPercentage,
      'hfPercentage': hfPercentage,
      'lfHfRatio': lfHfRatio,
      'lfNu': lfNu,
      'hfNu': hfNu,
      "frVals": frVals,
      "frValX": frValX,
    };
  }

  void applyInterpolation() {
    int n = 0;
    final int maxFftPoints =
        MAX_FFT_PTS; // Define this constant as per your requirements
    interRR = List.filled(maxFftPoints, 0.0);

    // Initial interpolation value
    interRR[0] = calRRI(
      0,
    ); // Assuming calRRI is a function to calculate or retrieve RR intervals

    for (int i = 1; i < rrIntervals.length; i++) {
      if (i >= maxFftPoints) break;

      double targetTime =
          i *
          nnMean; // Assuming N_N_MEAN is the mean interval you use, define this constant
      double currentTime = 0;

      // Find the correct segment for interpolation
      while (n < rrIntervals.length - 2 &&
          targetTime > (currentTime + rrIntervals[n + 1])) {
        n++;
        currentTime += rrIntervals[n];
      }

      if (targetTime >= currentTime &&
          targetTime < currentTime + rrIntervals[n + 1]) {
        // Perform interpolation
        double timeDifference = currentTime + rrIntervals[n + 1] - currentTime;
        double factor = (targetTime - currentTime) / timeDifference;
        double interpolatedValue =
            rrIntervals[n] + factor * (rrIntervals[n + 1] - rrIntervals[n]);
        interRR[i] = interpolatedValue;
      }
    }
  }

  double calRRI(int index) {
    // This function should return the RR interval from the `rrIntervals` list or calculate it
    return rrIntervals[index]; // Adjust this function as necessary for your actual computation
  }

  // Constants to

  void generateFRValues(WindowType windowType, List<double> interRR) {
    const int maxFftPoints = MAX_FFT_PTS;
    List<List<double>> w = List.generate(
      2,
      (i) => List.filled(maxFftPoints, 0),
    );
    frVals = List.filled(maxFftPoints ~/ 2, 0.0);
    frValX = List.filled(maxFftPoints ~/ 2, 0.0);

    // Precompute cosine and sine tables
    for (int i = 0; i < maxFftPoints; i++) {
      w[0][i] = cos(2 * pi * (i / maxFftPoints));
      w[1][i] = -sin(2 * pi * (i / maxFftPoints));
    }

    // Apply window function to the data
    switch (windowType) {
      case WindowType.hanning:
        for (int i = 0; i < maxFftPoints; i++) {
          interRR[i] *= 0.5 - (0.5 * cos(2 * pi * i / maxFftPoints));
        }
        break;
      case WindowType.hamming:
        for (int i = 0; i < maxFftPoints; i++) {
          interRR[i] *= 0.54 - (0.46 * cos(2 * pi * i / maxFftPoints));
        }
        break;
      case WindowType.blackman:
        for (int i = 0; i < maxFftPoints; i++) {
          interRR[i] *=
              0.42 -
              (0.5 * cos(2 * pi * i / maxFftPoints)) +
              (0.08 * cos(4 * pi * i / maxFftPoints));
        }
        break;
    }

    // Perform the DFT calculations manually
    double x0, x1;
    for (int k = 1; k < maxFftPoints ~/ 2; k++) {
      x0 = 0.0;
      x1 = 0.0;
      for (int i = 0; i < maxFftPoints; i++) {
        int n = (i * k) % maxFftPoints;
        x0 += (interRR[i] * w[0][n]) / maxFftPoints;
        x1 += (interRR[i] * w[1][n]) / maxFftPoints;
      }
      frVals[k] = sqrt(x0 * x0 + x1 * x1); // Magnitude of the complex number
      frValX[k] = k * (1 / (maxFftPoints / 2)); // Normalized frequency
    }

    // Print or use the results as needed
    print("Frequency Values: $frVals");
    print("Frequency Bins: $frValX");
  }

  getInterRR() {
    return interRR;
  }

  calculateFFTPoints(int rrCnt) {
    try {
      if (rrCnt <= 1) return; // Ensure there's enough data to process

      int fftN = (log(rrCnt - 1) / log(2)).floor();
      int fftPoints = pow(2, fftN).toInt();
      fftPoints = min(fftPoints, MAX_FFT_CNT);
      // bool fftOverlap = (rrCnt - 1) > fftPoints; // not used currently

      realF = List.filled(fftPoints, 0.0);
      imagiF = List.filled(fftPoints, 0.0);
      sampBuf = List.filled(fftPoints, 0.0);
      fr = List.filled(fftPoints, 0.0);

      int psdSize = fftPoints + 32 < MAX_FFT_PTS ? MAX_FFT_PTS : fftPoints + 32;
      psd = List.filled(psdSize, 0.0);
    } catch (e) {
      // Handle the error appropriately
      print('Error in calculateFFTPoints: $e');
    }
  }

  List<double> interpolateLiniar(List<double> times, List<double> values) {
    int maxFftPoints = MAX_FFT_PTS;
    if (times.isEmpty || values.isEmpty || times.length != values.length) {
      return [];
    }

    double totalTime = times.last - times.first;
    double interval = totalTime / (maxFftPoints - 1);
    List<double> newTimes = [
      for (double t = times.first; t <= times.last; t += interval) t,
    ];

    // Adjust the last time point if necessary
    if (newTimes.last != times.last) {
      newTimes[newTimes.length - 1] = times.last;
    }

    List<double> interpolatedValues = List.filled(maxFftPoints, 0.0);
    for (int i = 0; i < newTimes.length; i++) {
      double newTime = newTimes[i];
      int idx = times.indexWhere((t) => t >= newTime);
      if (idx == 0 || idx == -1) {
        interpolatedValues[i] = values[idx == -1 ? values.length - 1 : 0];
      } else {
        double t1 = times[idx - 1];
        double t2 = times[idx];
        double v1 = values[idx - 1];
        double v2 = values[idx];
        interpolatedValues[i] = v1 + (v2 - v1) * ((newTime - t1) / (t2 - t1));
      }
    }

    return interpolatedValues;
  }

  // // Converts a list of RR intervals to cumulative time points
  List<double> rrIntervalsToTimePoints(List<double> rrIntervals) {
    List<double> timePoints = [];
    double currentTime = 0;
    for (double interval in rrIntervals) {
      timePoints.add(currentTime);
      currentTime += interval;
    }
    return timePoints;
  }
}
