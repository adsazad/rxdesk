import 'package:flutter/material.dart';
import 'package:spirobtvo/Widgets/CustomLineChart.dart';

class ChartsBuilder {
  static Widget buildVCO2vsVEChart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints, {
    double width = 400,
    double? height,
  }) {
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
          width: width,
          height: height ?? MediaQuery.of(context).size.height / 2,
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
          ),
        ),
      ],
    );
  }

  static Widget buildTimeVsVEChart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints, {
    double width = 400,
    double? height,
  }) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final ve = dataPoints[i]['minuteVentilation'];
      if (ve != null) {
        xValues.add(i.toDouble());
        yValues.add(ve.toDouble());
      }
    }

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
          width: width,
          height: height ?? MediaQuery.of(context).size.height / 2,
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
            barWidth: 2,
            showDots: false,
          ),
        ),
      ],
    );
  }

  static Widget buildTimeVsRERChart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints, {
    double width = 400,
    double? height,
  }) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final rer = dataPoints[i]['rer'];
      if (rer != null) {
        xValues.add(i.toDouble());
        yValues.add(rer.toDouble());
      }
    }

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
          width: width,
          height: height ?? MediaQuery.of(context).size.height / 2,
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

  static Widget buildTimeVsVO2Chart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints, {
    double width = 400,
    double? height,
  }) {
    final List<double> xValues = [];
    final List<double> yValues = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final vo2 = dataPoints[i]['vo2'];
      if (vo2 != null) {
        xValues.add(i.toDouble());
        yValues.add(vo2.toDouble());
      }
    }

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
          width: width,
          height: height ?? MediaQuery.of(context).size.height / 2,
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

  static Widget buildVO2vsVCO2Chart(
    BuildContext context,
    List<Map<String, dynamic>> dataPoints, {
    double width = 400,
    double? height,
  }) {
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
          width: width,
          height: height ?? MediaQuery.of(context).size.height / 2,
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
            barWidth: 0,
            showDots: true,
          ),
        ),
      ],
    );
  }
}
