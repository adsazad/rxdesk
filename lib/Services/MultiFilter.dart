import 'package:bluevo2/Services/FilterClass.dart';

class MultiFilter {
  List<FilterClass> filters = [];

  static const int _staticSr = 300;
  static const int _staticGain = 2;
  static const int _staticSpeed = 3;
  static const double _staticCountPerMV = 0.65;
  static const double _staticPixels1mmY = 5.0;
  static const int _staticLineFreq = 0;
  static const int _staticRange = 6;
  static const int _staticSRateInd = -1;
  static const bool _staticUseOldSpeeds = false;

  /// Initialize filters with only lpf, hpf, notch (filterOn used externally)
  void init(List<Map<String, dynamic>> configurations) {
    filters.clear();
    for (var config in configurations) {
      filters.add(_generateFilterFromMinimalConfig(config));
    }
  }

  /// Returns filter at index
  FilterClass getFilter(int index) {
    if (index >= 0 && index < filters.length) {
      return filters[index];
    } else {
      throw RangeError("Filter index out of range");
    }
  }

  /// Get all coefficients (for debug/visual)
  List<List<List<double>>> getAllCoefficients() {
    return filters.map((f) => f.Coeff).toList();
  }

  /// STATIC: Creates a FilterClass with minimal config
  static FilterClass _generateFilterFromMinimalConfig(
    Map<String, dynamic> config,
  ) {
    final int lpf = config["lpf"] ?? 3;
    final int hpf = config["hpf"] ?? 5;
    final int notch = config["notch"] ?? 1;

    // Allow overriding defaults via config, else use static defaults
    final int sr = config["sr"] ?? _staticSr;
    final int gain = config["gain"] ?? _staticGain;
    final int speed = config["speed"] ?? _staticSpeed;
    final double countPerMV = config["countPerMV"] ?? _staticCountPerMV;
    final double pixels1mmY = config["pixels1mmY"] ?? _staticPixels1mmY;
    final int lineFreq = config["lineFreq"] ?? _staticLineFreq;
    final int range = config["range"] ?? _staticRange;
    final int sRateInd = config["sRateInd"] ?? _staticSRateInd;
    final bool useOldSpeeds = config["useOldSpeeds"] ?? _staticUseOldSpeeds;

    FilterClass filter = FilterClass();
    filter.init(
      sr,
      lpf,
      hpf,
      notch,
      gain,
      speed,
      countPerMV,
      pixels1mmY,
      lineFreq,
      range,
      sRateInd,
      useOldSpeeds,
    );

    return filter;
  }
}
