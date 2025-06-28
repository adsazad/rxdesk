import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> xValues;
  final List<double> yValues;
  final String lineLabel;
  final Color lineColor;
  final String xLabel;
  final String yLabel;

  const CustomLineChart({
    Key? key,
    required this.xValues,
    required this.yValues,
    required this.lineLabel,
    this.lineColor = Colors.blue,
    this.xLabel = 'X-axis',
    this.yLabel = 'Y-axis',
  }) : assert(
         xValues.length == yValues.length,
         "X and Y arrays must have the same length",
       ),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = List.generate(
      xValues.length,
      (index) => FlSpot(xValues[index], yValues[index]),
    );

    final xInterval = _calculateInterval(xValues);
    final yInterval = _calculateInterval(yValues);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth * 0.6;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              lineLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RotatedBox(
                  quarterTurns: -1,
                  child: Text(
                    yLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: chartHeight,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: yInterval,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black87,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: xInterval,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black87,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: false,
                                show: true,
                                barWidth: 0,
                                color: Colors.transparent,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (
                                    spot,
                                    percent,
                                    barData,
                                    index,
                                  ) {
                                    return FlDotCirclePainter(
                                      radius: 3,
                                      color: lineColor,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        xLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  double _calculateInterval(List<double> values) {
    if (values.isEmpty) return 1.0;

    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final range = max - min;

    // Prevent interval from being 0
    if (range == 0) return max == 0 ? 1.0 : max / 4;

    final rawInterval = (range / 4).abs();

    // Clamp to avoid 0
    return rawInterval == 0
        ? 1.0
        : double.parse(rawInterval.toStringAsFixed(2));
  }
}
