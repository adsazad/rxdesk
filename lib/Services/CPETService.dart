import 'package:spirobtvo/Services/CalibrationFunction.dart';

class CPETService {
  CalibrationFunction? o2Calibrate;

  Map<String, dynamic> init(List<List<double>> data, dynamic globalSettings) {
    List<Map<String, dynamic>> volPeaks = getBreathVolumePeaks(data);
    List<Map<String, dynamic>> breathStats = calculateStatsAtPeaks(
      data,
      volPeaks,
    );
    Map<String, dynamic> averageStats = calculateAverages(breathStats);

    Map<String, dynamic>? lastBreathStat =
        breathStats.isNotEmpty ? breathStats.last : null;

    o2Calibrate = generateCalibrationFunction(
      voltage1: globalSettings.voltage1,
      value1: globalSettings.value1,
      voltage2: globalSettings.voltage2,
      value2: globalSettings.value2,
    );
    double? respirationRate;
    double? minuteVentilation;

    if (breathStats.length >= 2) {
      int index1 = breathStats[breathStats.length - 2]['index'];
      int index2 = breathStats[breathStats.length - 1]['index'];
      int breathIntervalSamples = index2 - index1;

      respirationRate = 60 * (300 / breathIntervalSamples);

      double vol = lastBreathStat?['vol'] ?? 0;
      // vol = vol 0;
      minuteVentilation = respirationRate * vol;
    }

    return {
      "volumePeaks": volPeaks,
      "breathStats": breathStats,
      "averageStats": averageStats,
      "lastBreathStat": lastBreathStat,
      "respirationRate": respirationRate,
      "minuteVentilation": minuteVentilation,
    };
  }

  // Step 1: Find volume peaks (max point per breath)
  List<Map<String, dynamic>> getBreathVolumePeaks(List<List<double>> data) {
    List<Map<String, dynamic>> peaks = [];

    if (data.isEmpty || data[0].length <= 3) return peaks;

    bool rising = false;
    double maxVal = -double.infinity;
    int maxIndex = -1;
    const int minSamplesBetweenPeaks = 90;

    for (int i = 1; i < data.length; i++) {
      if (data[i].length <= 3 || data[i - 1].length <= 3) continue;

      double prev = data[i - 1][4];
      double current = data[i][4];

      if (current > prev) {
        if (!rising) {
          rising = true;
          maxVal = current;
          maxIndex = i;
        } else if (current > maxVal) {
          maxVal = current;
          maxIndex = i;
        }
      } else if (rising && current < prev) {
        if (maxVal > 0.1) {
          // Only add peak if far enough from previous one
          if (peaks.isEmpty ||
              (maxIndex - peaks.last['index'] > minSamplesBetweenPeaks)) {
            peaks.add({'index': maxIndex, 'value': maxVal});
          }
        }
        rising = false;
        maxVal = -double.infinity;
        maxIndex = -1;
      }
    }

    return peaks;
  }

  int detectO2Co2DelayFromVolumePeaks(
    List<List<double>> data, {
    int samplingRate = 300,
  }) {
    final peaks = getBreathVolumePeaks(data);

    List<int> delays = [];

    for (var peak in peaks) {
      int volIndex = peak['index'];
      if (volIndex >= data.length) continue;

      int maxLookahead = 150; // 150 samples = 500 ms
      int co2PeakIndex = -1;
      double co2Max = -double.infinity;

      for (
        int i = volIndex + 1;
        i <= volIndex + maxLookahead && i < data.length;
        i++
      ) {
        double co2 = data[i][2]; // CO2 index
        if (co2 > co2Max) {
          co2Max = co2;
          co2PeakIndex = i;
        }
      }

      if (co2PeakIndex != -1) {
        int delay = co2PeakIndex - volIndex;
        delays.add(delay);
      }
    }

    if (delays.isEmpty) return 0;

    int avgDelay = delays.reduce((a, b) => a + b) ~/ delays.length;
    print(
      "Delays: $delays → Avg: $avgDelay samples = ${avgDelay * 1000 / samplingRate} ms",
    );
    return avgDelay;
  }

  // Step 2: Calculate VO2, VCO2, RER at peak index
  List<Map<String, dynamic>> calculateStatsAtPeaks(
    List<List<double>> data,
    List<Map<String, dynamic>> peaks,
  ) {
    List<Map<String, dynamic>> stats = [];

    for (int j = 0; j < peaks.length; j++) {
      int i = peaks[j]['index'];

      if (i < data.length && data[i].length >= 5) {
        double o2 = data[i][1]; // O2 in %
        double co2 = data[i][2]; // CO2 in %
        double vol = data[i][4] / 1000; // vol in liters

        o2 = o2 * 0.00072105;
        double o2Percent = o2Calibrate?.call(o2) ?? 0.0;

        double vo2 = vol * (20.93 - o2Percent) / 100;
        double co2Fraction = co2 / 100;
        double vco2 = vol * co2Fraction;
        double rer = vo2 > 0 ? vco2 / vo2 : 0;

        double? respirationRate;
        double? minuteVentilation;

        if (j >= 1) {
          int prevIndex = peaks[j - 1]['index'];
          int intervalSamples = i - prevIndex;
          if (intervalSamples > 0) {
            respirationRate =
                60 * (300 / intervalSamples); // assuming 300 Hz sampling
            minuteVentilation = respirationRate * vol;
          }
        }

        stats.add({
          'index': i,
          'vo2': vo2,
          'vco2': vco2,
          'rer': rer,
          "vol": vol,
          "respirationRate": respirationRate,
          "minuteVentilation": minuteVentilation,
        });
      }
    }

    return stats;
  }

  // ✅ New Step 3: Calculate average VO2, VCO2, RER
  Map<String, dynamic> calculateAverages(List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) return {'vo2': 0.0, 'vco2': 0.0, 'rer': 0.0, "vol": 0.0};

    double totalVo2 = 0;
    double totalVco2 = 0;
    double totalRer = 0;
    double totalVol = 0;

    for (final stat in stats) {
      totalVo2 += stat['vo2'];
      totalVco2 += stat['vco2'];
      totalRer += stat['rer'];
      totalVol += stat["vol"];
    }

    int count = stats.length;

    return {
      'vo2': totalVo2 / count,
      'vco2': totalVco2 / count,
      'rer': totalRer / count,
      'totalVol': totalVol / count,
    };
  }
}
