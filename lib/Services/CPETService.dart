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

  // Step 1: Find exhalation ramps (start and end indices)
  List<Map<String, dynamic>> getBreathVolumePeaks(List<List<double>> data) {
    List<Map<String, dynamic>> ramps = [];
    if (data.isEmpty || data[0].length <= 3) return ramps;

    double volThreshold = 0.05; // adjust as needed
    int minSamplesBetweenPeaks = 240;
    int i = 0;
    int lastEnd = -minSamplesBetweenPeaks;

    while (i < data.length) {
      // Find start: volume rises above threshold
      while (i < data.length &&
          (data[i].length < 5 || data[i][4] <= volThreshold)) {
        i++;
      }
      int start = i;

      // Find end: volume drops to threshold or below after rising
      double maxVal = -double.infinity;
      int maxIndex = start;
      while (i < data.length && data[i][4] > volThreshold) {
        if (data[i][4] > maxVal) {
          maxVal = data[i][4];
          maxIndex = i;
        }
        i++;
      }
      int end = i - 1;

      if (end > start && start < data.length && end < data.length) {
        // Only add ramp if far enough from previous one
        if (ramps.isEmpty || (start - lastEnd > minSamplesBetweenPeaks)) {
          ramps.add({
            'start': start,
            'end': end,
            'peak': maxIndex,
            'value': maxVal,
          });
          lastEnd = end;
        }
      }
      // Move to next ramp
      i = end + 1;
    }
    return ramps;
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

  // Step 2: Calculate VO2, VCO2, RER using average O2/CO2 over ramp
  List<Map<String, dynamic>> calculateStatsAtPeaks(
    List<List<double>> data,
    List<Map<String, dynamic>> ramps,
  ) {
    List<Map<String, dynamic>> stats = [];
    int samplingRate = 300;

    for (int j = 0; j < ramps.length; j++) {
      int start = ramps[j]['start'];
      int end = ramps[j]['end'];
      int peak = ramps[j]['peak'];

      if (start < data.length &&
          end < data.length &&
          data[start].length >= 5 &&
          data[end].length >= 5) {
        // Average O2 and CO2 over ramp
        double sumO2 = 0.0;
        double sumCO2 = 0.0;
        double sumVol = 0.0;
        int count = 0;
        for (int k = start; k <= end; k++) {
          sumO2 += data[k][1];
          sumCO2 += data[k][2];
          sumVol += data[k][4] / 1000;
          count++;
        }
        double avgO2 = count > 0 ? sumO2 / count : 0.0;
        double avgCO2 = count > 0 ? sumCO2 / count : 0.0;
        double avgVol = count > 0 ? sumVol / count : 0.0;

        avgO2 = avgO2 * 0.000917;
        double o2Percent = o2Calibrate?.call(avgO2) ?? 0.0;

        double vo2 = avgVol * (20.93 - o2Percent) / 100;
        double co2Fraction = avgCO2 / 100;
        double vco2 = avgVol * co2Fraction;
        double rer = vo2 > 0 ? vco2 / vo2 : 0;

        double? respirationRate;
        double? minuteVentilation;

        if (j >= 1) {
          int prevPeak = ramps[j - 1]['peak'];
          int intervalSamples = peak - prevPeak;
          if (intervalSamples > 0) {
            respirationRate = 60 * (samplingRate / intervalSamples);
            minuteVentilation = respirationRate * avgVol;
          }
        }

        stats.add({
          'index': peak,
          'start': start,
          'end': end,
          'vo2': vo2,
          'vco2': vco2,
          'rer': rer,
          "vol": avgVol,
          "respirationRate": respirationRate,
          "minuteVentilation": minuteVentilation,
          "avgO2": avgO2,
          "avgCO2": avgCO2,
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
