import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CustomLineChart extends StatelessWidget {
  final List<double> xValues;
  final List<double> yValues;
  final String lineLabel;
  final Color lineColor;

  const CustomLineChart({
    Key? key,
    required this.xValues,
    required this.yValues,
    required this.lineLabel,
    this.lineColor = Colors.blue,
  })  : assert(xValues.length == yValues.length, "X and Y arrays must have the same length"),
        super(key: key);



  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = List.generate(
      xValues.length,
          (index) => FlSpot(xValues[index], yValues[index]),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lineLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: constraints.maxWidth,
              height: constraints.maxWidth * 0.6, // maintain a 3:2 ratio
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50, // ← increase this to prevent label cutoff
                        interval: _calculateInterval(yValues),
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 4), // Optional spacing
                          child: Text(
                            value.toStringAsFixed(2), // keeps label width consistent
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),

                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: lineColor,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                      spots: spots,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
double _calculateInterval(List<double> values) {
  if (values.isEmpty) return 1.0;
  final max = values.reduce((a, b) => a > b ? a : b);
  final min = values.reduce((a, b) => a < b ? a : b);
  final range = max - min;
  return (range / 5).clamp(1, double.infinity);
}
