import 'package:spirobtvo/Services/FilterClass.dart';

class MultiFilter {
  List<FilterClass> filters = [];

  void init(List<Map<String, dynamic>> configurations) {
    filters.clear();

    for (var config in configurations) {
      FilterClass filter = FilterClass();
      filter.init(
          config["sr"],
          config["lpf"],
          config["hpf"],
          config["notch"],
          config["gain"],
          config["speed"],
          config["countPermV"],
          config["pixels1mmY"],
          config["lineFreq"],
          config["range"],
          config.containsKey("sRateInd") ? config["sRateInd"] : -1,
          config.containsKey("useOldSpeeds") ? config["useOldSpeeds"] : false
      );
      filters.add(filter);
    }
  }

  FilterClass getFilter(int index) {
    if (index >= 0 && index < filters.length) {
      return filters[index];
    } else {
      throw RangeError("Filter index out of range");
    }
  }

  List<List<List<double>>> getAllCoefficients() {
    return filters.map((f) => f.Coeff).toList();
  }
}
