import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/Widgets/CustomLineChart.dart';
import 'dart:convert';

class SavedChartsDialogContent extends StatefulWidget {
  final dynamic cp; // cp is passed from the parent widget

  const SavedChartsDialogContent({Key? key, required this.cp})
    : super(key: key);

  @override
  State<SavedChartsDialogContent> createState() =>
      _SavedChartsDialogContentState();
}

class _SavedChartsDialogContentState extends State<SavedChartsDialogContent> {
  Future<List<Widget>> buildChartsFromSavedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('saved_charts');

    if (saved == null) return [const Text('No saved chart found.')];

    List<dynamic> charts = jsonDecode(saved);
    if (charts.isEmpty) return [const Text('Chart list is empty.')];

    List<Map<String, dynamic>> dataPoints = List<Map<String, dynamic>>.from(
      widget.cp?['breathStats'] ?? [],
    );

    List<Widget> chartWidgets = [];

    for (Map<String, dynamic> chart in charts) {
      String xKey = chart['xaxis'];
      String yKey = chart['yaxis'];
      String name = chart['name'];

      List<double> xValues = [];
      List<double> yValues = [];

      for (int i = 0; i < dataPoints.length; i++) {
        var point = dataPoints[i];

        // Handle x-axis
        double x;
        if (xKey == 'time_series') {
          x = i.toDouble();
        } else if (point[xKey] != null) {
          x = point[xKey].toDouble();
        } else {
          continue;
        }

        // Handle y-axis
        double y;
        if (yKey == 'time_series') {
          y = i.toDouble();
        } else if (point[yKey] != null) {
          y = point[yKey].toDouble();
        } else {
          continue;
        }

        xValues.add(x);
        yValues.add(y);
      }

      chartWidgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('$name ($yKey vs $xKey)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: 400,
              height: MediaQuery.of(context).size.height / 2,
              child: CustomLineChart(
                xLabel: xKey,
                yLabel: yKey,
                xValues: xValues,
                yValues: yValues,
                lineLabel: '$yKey vs $xKey',
              ),
            ),
          ],
        ),
      );
    }

    return chartWidgets;
  }

  Widget buildVCO2vsVEChart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints,
  ) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (final point in dataPoints) {
      final vco2 = point['vco2'];
      final ve = point['minuteVentilation'];
      if (vco2 != null && ve != null) {
        xValues.add(vco2.toDouble());
        yValues.add(ve.toDouble());
      }
    }

    // Set axis ranges and intervals similar to your reference image
    final double xMin = 0;
    final double xMax = 3;
    final double xInterval = 0.5;
    final double yMin = 0;
    final double yMax = 100;
    final double yInterval = 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VE vs VCO₂',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          height: MediaQuery.of(context).size.height / 2,
          child: CustomLineChart(
            lineColor: Colors.blue,
            xLabel: 'VCO₂ [L/min]',
            yLabel: 'VE [L/min]',
            xValues: xValues,
            yValues: yValues,
            lineLabel: 'VE vs VCO₂',
            xMin: xMin,
            xMax: xMax,
            xInterval: xInterval,
            yMin: yMin,
            yMax: yMax,
            yInterval: yInterval,
            showGrid: true,
            // Optionally, add regression line and annotation if supported:
            // showRegressionLine: true,
            // regressionLineColor: Colors.black,
            // regressionLineWidth: 2,
            // showSlopeIntercept: true,
          ),
        ),
      ],
    );
  }

  Widget buildTimeVsVEChart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints,
  ) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final ve = dataPoints[i]['minuteVentilation'];
      if (ve != null) {
        xValues.add(i.toDouble()); // Time domain as breath index
        yValues.add(ve.toDouble());
      }
    }

    // Set axis ranges and intervals
    final double xMin = 0;
    final double xMax = xValues.isNotEmpty ? xValues.last : 10;
    final double xInterval = (xMax / 5).clamp(1, 20);
    final double yMin = 0;
    final double yMax =
        yValues.isNotEmpty
            ? (yValues.reduce((a, b) => a > b ? a : b) * 1.1)
            : 100;
    final double yInterval = (yMax / 5).clamp(1, 50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VE vs Time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          height: MediaQuery.of(context).size.height / 2,
          child: CustomLineChart(
            lineColor: Colors.brown,
            xLabel: 'Time (breath index)',
            yLabel: 'VE [L/min]',
            xValues: xValues,
            yValues: yValues,
            lineLabel: 'VE vs Time',
            xMin: xMin,
            xMax: xMax,
            xInterval: xInterval,
            yMin: yMin,
            yMax: yMax,
            yInterval: yInterval,
            showGrid: true,
            barWidth: 2, // <-- Add this
            showDots: false, // <-- Add this
          ),
        ),
      ],
    );
  }

  Widget buildTimeVsRERChart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints,
  ) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final rer = dataPoints[i]['rer'];
      if (rer != null) {
        xValues.add(i.toDouble()); // Time domain as breath index
        yValues.add(rer.toDouble());
      }
    }

    // Set axis ranges and intervals
    final double xMin = 0;
    final double xMax = xValues.isNotEmpty ? xValues.last : 10;
    final double xInterval = (xMax / 5).clamp(1, 20);
    final double yMin = 0;
    final double yMax =
        yValues.isNotEmpty
            ? (yValues.reduce((a, b) => a > b ? a : b) * 1.1)
            : 1.5;
    final double yInterval = (yMax / 5).clamp(0.1, 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RER vs Time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          height: MediaQuery.of(context).size.height / 2,
          child: CustomLineChart(
            lineColor: Colors.pink,
            xLabel: 'Time (breath index)',
            yLabel: 'RER',
            xValues: xValues,
            yValues: yValues,
            lineLabel: 'RER vs Time',
            xMin: xMin,
            xMax: xMax,
            xInterval: xInterval,
            yMin: yMin,
            yMax: yMax,
            yInterval: yInterval,
            showGrid: true,
            barWidth: 2,
            showDots: false,
          ),
        ),
      ],
    );
  }

  Widget buildTimeVsVO2Chart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints,
  ) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final vo2 = dataPoints[i]['vo2'];
      if (vo2 != null) {
        xValues.add(i.toDouble()); // Time domain as breath index
        yValues.add(vo2.toDouble());
      }
    }

    // Set axis ranges and intervals
    final double xMin = 0;
    final double xMax = xValues.isNotEmpty ? xValues.last : 10;
    final double xInterval = (xMax / 5).clamp(1, 20);
    final double yMin = 0;
    final double yMax =
        yValues.isNotEmpty
            ? (yValues.reduce((a, b) => a > b ? a : b) * 1.1)
            : 3;
    final double yInterval = (yMax / 5).clamp(0.1, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VO₂ vs Time',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          height: MediaQuery.of(context).size.height / 2,
          child: CustomLineChart(
            lineColor: Colors.indigo,
            xLabel: 'Time (breath index)',
            yLabel: 'VO₂ [L/min]',
            xValues: xValues,
            yValues: yValues,
            lineLabel: 'VO₂ vs Time',
            xMin: xMin,
            xMax: xMax,
            xInterval: xInterval,
            yMin: yMin,
            yMax: yMax,
            yInterval: yInterval,
            showGrid: true,
            barWidth: 2,
            showDots: false,
          ),
        ),
      ],
    );
  }

  Widget buildVO2vsVCO2Chart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints,
  ) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (final point in dataPoints) {
      final vo2 = point['vo2'];
      final vco2 = point['vco2'];
      if (vo2 != null && vco2 != null) {
        xValues.add(vo2.toDouble());
        yValues.add(vco2.toDouble());
      }
    }

    // Set axis ranges and intervals
    final double xMin = 0;
    final double xMax =
        xValues.isNotEmpty
            ? (xValues.reduce((a, b) => a > b ? a : b) * 1.1)
            : 3;
    final double xInterval = (xMax / 5).clamp(0.1, 1.0);
    final double yMin = 0;
    final double yMax =
        yValues.isNotEmpty
            ? (yValues.reduce((a, b) => a > b ? a : b) * 1.1)
            : 3;
    final double yInterval = (yMax / 5).clamp(0.1, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VCO₂ vs VO₂',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: 400,
          height: MediaQuery.of(context).size.height / 2,
          child: CustomLineChart(
            lineColor: Colors.deepOrange,
            xLabel: 'VO₂ [L/min]',
            yLabel: 'VCO₂ [L/min]',
            xValues: xValues,
            yValues: yValues,
            lineLabel: 'VCO₂ vs VO₂',
            xMin: xMin,
            xMax: xMax,
            xInterval: xInterval,
            yMin: yMin,
            yMax: yMax,
            yInterval: yInterval,
            showGrid: true,
            barWidth: 0, // <-- No line
            showDots: true, // <-- Only dots
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> dataPoints =
        List<Map<String, dynamic>>.from(widget.cp?['breathStats'] ?? []);

    return Container(
      width: MediaQuery.of(context).size.width / 1.2,
      // Remove or increase the fixed height if you want more space:
      // height: MediaQuery.of(context).size.height / 1.9,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Make the whole chart area vertically scrollable:
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  Row(
                    children: [
                      buildVCO2vsVEChart(context, dataPoints),
                      buildTimeVsVEChart(context, dataPoints),
                      buildTimeVsRERChart(context, dataPoints),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      buildTimeVsVO2Chart(context, dataPoints),
                      buildVO2vsVCO2Chart(context, dataPoints),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // const SizedBox(height: 16),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
