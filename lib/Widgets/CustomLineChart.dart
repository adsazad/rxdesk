import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> xValues;
  final List<double> yValues;
  final String lineLabel;
  final Color lineColor;
  final String xLabel;
  final String yLabel;

  // Optional parameters with defaults
  final double? xMin;
  final double? xMax;
  final double? xInterval;
  final double? yMin;
  final double? yMax;
  final double? yInterval;
  final bool showGrid;
  final double barWidth;
  final bool showDots;
  final bool isCurved;

  const CustomLineChart({
    Key? key,
    required this.xValues,
    required this.yValues,
    required this.lineLabel,
    this.lineColor = Colors.blue,
    this.xLabel = 'X-axis',
    this.yLabel = 'Y-axis',
    this.xMin,
    this.xMax,
    this.xInterval,
    this.yMin,
    this.yMax,
    this.yInterval,
    this.showGrid = true,
    this.barWidth = 2,
    this.showDots = false,
    this.isCurved = false,
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

    final double computedXMin =
        xMin ?? (xValues.isEmpty ? 0 : xValues.reduce((a, b) => a < b ? a : b));
    final double computedXMax =
        xMax ?? (xValues.isEmpty ? 1 : xValues.reduce((a, b) => a > b ? a : b));
    final double computedYMin =
        yMin ?? (yValues.isEmpty ? 0 : yValues.reduce((a, b) => a < b ? a : b));
    final double computedYMax =
        yMax ?? (yValues.isEmpty ? 1 : yValues.reduce((a, b) => a > b ? a : b));
    final double computedXInterval = xInterval ?? _calculateInterval(xValues);
    final double computedYInterval = yInterval ?? _calculateInterval(yValues);

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
                            minX: computedXMin,
                            maxX: computedXMax,
                            minY: computedYMin,
                            maxY: computedYMax,
                            gridData: FlGridData(show: showGrid),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: computedYInterval,
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
                                  interval: computedXInterval,
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
                                isCurved: isCurved,
                                show: true,
                                barWidth: barWidth,
                                color: lineColor,
                                dotData: FlDotData(
                                  show: showDots,
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
