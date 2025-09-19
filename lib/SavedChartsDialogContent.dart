import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bluevo2/Widgets/CustomLineChart.dart';
import 'dart:convert';
import 'package:bluevo2/Widgets/ChartsBuilder.dart';

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
                      ChartsBuilder.buildVCO2vsVEChart(context, dataPoints),
                      ChartsBuilder.buildTimeVsVEChart(context, dataPoints),
                      ChartsBuilder.buildTimeVsRERChart(context, dataPoints),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChartsBuilder.buildTimeVsVO2Chart(context, dataPoints),
                      ChartsBuilder.buildVO2vsVCO2Chart(context, dataPoints),
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
