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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lineLabel,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.7,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true),
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
  }
}
