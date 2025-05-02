import 'package:spirobtvo/Services/FilterClass.dart';

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
  static FilterClass _generateFilterFromMinimalConfig(Map<String, dynamic> config) {
    final int lpf = config["lpf"] ?? 3;
    final int hpf = config["hpf"] ?? 5;
    final int notch = config["notch"] ?? 1;

    FilterClass filter = FilterClass();
    filter.init(
      _staticSr,
      lpf,
      hpf,
      notch,
      _staticGain,
      _staticSpeed,
      _staticCountPerMV,
      _staticPixels1mmY,
      _staticLineFreq,
      _staticRange,
      _staticSRateInd,
      _staticUseOldSpeeds,
    );

    return filter;
  }
}
