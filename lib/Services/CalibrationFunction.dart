typedef CalibrationFunction = double Function(double voltage);

class TwoPointCalibration {
  final double slope;
  final double offset;

  TwoPointCalibration({
    required this.slope,
    required this.offset,
  });

  /// Factory constructor to generate slope and offset from two points
  factory TwoPointCalibration.fromPoints({
    required double v1,
    required double o1,
    required double v2,
    required double o2,
  }) {
    if (v2 == v1) {
      throw ArgumentError('Voltage points must be different to calculate slope.');
    }

    final slope = (o2 - o1) / (v2 - v1);
    final offset = o1 - slope * v1;

    return TwoPointCalibration(slope: slope, offset: offset);
  }

  /// Converts a voltage to calibrated output using the slope and offset
  double convert(double voltage) {
    return slope * voltage + offset;
  }
}

/// Functional wrapper using TwoPointCalibration internally
CalibrationFunction generateCalibrationFunction({
  required double voltage1,
  required double value1,
  required double voltage2,
  required double value2,
}) {
  final calibration = TwoPointCalibration.fromPoints(
    v1: voltage1,
    o1: value1,
    v2: voltage2,
    o2: value2,
  );

  return calibration.convert;
}

