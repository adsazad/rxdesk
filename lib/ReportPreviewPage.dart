import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart' as pvrd;
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/painting.dart';
import 'package:spirobtvo/Widgets/ChartsBuilder.dart';
import 'dart:developer' as developer;

class ReportPreviewPage extends StatefulWidget {
  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> breathStats;
  final Map<String, dynamic>? protocolDetails; // Optional: protocol details
  final List<Map<String, dynamic>>? markers;
  final List<String>?
  graphBase64List; // Optional: List of base64 PNGs for graphs

  const ReportPreviewPage({
    Key? key,
    required this.patient,
    required this.breathStats,
    required this.protocolDetails,
    required this.markers,
    this.graphBase64List,
  }) : super(key: key);

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  late String htmlContent;

  Uint8List? chartImage;

  bool _showChart = false;
  Key pdfPreviewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _showChart = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        chartImage = await _captureChartImage(_veTimeChartKey);
        print("Chart image captured: ${chartImage != null}");
        if (mounted) {
          setState(() {
            // Change the key to force PdfPreview to rebuild with the new image
            pdfPreviewKey = UniqueKey();
          });
        }
        setState(() {
          _showChart = false;
        });
      });
    });
  }

  // Returns a Map with AT point stats and the index at which AT was detected.
  // Also calculates vo2kg and ve at that point.
  Map<String, dynamic>? getATPhaseStats({
    required List<Map<String, dynamic>> breathStats,
    required Map<String, dynamic>? patient,
    required String
    method, // "VO2 max" or "VE/VO₂ increases while VE/VCO₂ remains stable or decreases"
  }) {
    if (breathStats.isEmpty) return null;

    int? atIndex;
    Map<String, dynamic>? atRow;

    if (method == "VO2 max") {
      // AT at 60% of VO2max
      double? weight = double.tryParse((patient?['weight'] ?? '').toString());
      double? height = double.tryParse((patient?['height'] ?? '').toString());
      int? age = int.tryParse((patient?['age'] ?? '').toString());
      String gender = (patient?['gender'] ?? '').toString().toLowerCase();

      double? vo2max;
      if (height != null && weight != null && age != null) {
        if (gender == 'male' || gender == 'm') {
          vo2max = (0.023 * height) - (0.021 * age) + (0.0111 * weight) - 1.40;
        } else if (gender == 'female' || gender == 'f') {
          vo2max = (0.021 * height) - (0.019 * age) + (0.00737 * weight) - 0.60;
        }
      }
      if (vo2max == null) return null;
      double atVo2 = vo2max * 0.6;

      // Find the breathStats entry closest to this VO2
      int minIdx = 0;
      double minDiff = double.infinity;
      for (int i = 0; i < breathStats.length; i++) {
        double diff = ((breathStats[i]['vo2'] ?? 0.0) - atVo2).abs();
        if (diff < minDiff) {
          minDiff = diff;
          minIdx = i;
        }
      }
      atRow = Map<String, dynamic>.from(breathStats[minIdx]);
      atIndex = atRow['index'] ?? minIdx;
    } else if (method ==
        "VE/VO₂ increases while VE/VCO₂ remains stable or decreases") {
      // Find the first index where VE/VO2 increases and VE/VCO2 is stable or decreases
      for (int i = 1; i < breathStats.length; i++) {
        final prev = breathStats[i - 1];
        final curr = breathStats[i];
        final prevVeVo2 =
            prev['ve'] != null && prev['vo2'] != null && prev['vo2'] != 0
                ? prev['ve'] / prev['vo2']
                : null;
        final currVeVo2 =
            curr['ve'] != null && curr['vo2'] != null && curr['vo2'] != 0
                ? curr['ve'] / curr['vo2']
                : null;
        final prevVeVco2 =
            prev['ve'] != null && prev['vco2'] != null && prev['vco2'] != 0
                ? prev['ve'] / prev['vco2']
                : null;
        final currVeVco2 =
            curr['ve'] != null && curr['vco2'] != null && curr['vco2'] != 0
                ? curr['ve'] / curr['vco2']
                : null;
        if (prevVeVo2 != null &&
            currVeVo2 != null &&
            prevVeVco2 != null &&
            currVeVco2 != null) {
          if (currVeVo2 > prevVeVo2 && currVeVco2 <= prevVeVco2) {
            atRow = Map<String, dynamic>.from(curr);
            atIndex = atRow['index'] ?? i;
            break;
          }
        }
      }
    }

    if (atRow == null) return null;

    // Calculate vo2kg and ve at AT point
    double? weight = double.tryParse((patient?['weight'] ?? '').toString());
    double? vo2 = atRow['vo2'] is num ? atRow['vo2'].toDouble() : null;
    double? ve = atRow['ve'] ?? atRow['minuteVentilation'];
    double? vo2kg;
    if (vo2 != null && weight != null && weight > 0) {
      vo2kg = vo2 * 1000 / weight;
    }

    // Calculate time at AT point (assuming 300Hz sampling rate)
    int idx = atIndex ?? 0;
    int seconds = (idx / 300).floor();
    String atTime =
        "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";

    return {
      ...atRow,
      "at_index": atIndex,
      "vo2kg": vo2kg,
      "ve": ve,
      "at_time": atTime,
    };
  }

  // Replace your buildPhaseStatsPdfTable with this version to add the AT column
  pw.Widget buildPhaseStatsPdfTable({
    required List<Map<String, dynamic>> markers,
    required List<Map<String, dynamic>> breathStats,
    required List phases, // protocol['phases']
    Map<String, dynamic>? patient, // Pass patient info for predictions
    String atDetectionMethod =
        "VO2 max", // or "VE/VO₂ increases while VE/VCO₂ remains stable or decreases"
  }) {
    // Calculate absolute start/end for each phase
    List<Map<String, dynamic>> phaseRanges = [];
    for (int i = 0; i < markers.length; i++) {
      final start = i == 0 ? 0 : (markers[i - 1]["length"] ?? 0);
      final end = markers[i]["length"] ?? 0;
      phaseRanges.add({"name": markers[i]["name"], "start": start, "end": end});
    }

    // Helper to get stats for a phase
    Map<String, dynamic> getPhaseStats(int start, int end) {
      final statsInPhase =
          breathStats.where((s) {
            final idx = s["index"] ?? 0;
            return idx >= start && idx <= end;
          }).toList();
      if (statsInPhase.isEmpty) return {};

      double avgVo2 =
          statsInPhase.map((s) => s["vo2"] ?? 0.0).reduce((a, b) => a + b) /
          statsInPhase.length;
      double avgVco2 =
          statsInPhase.map((s) => s["vco2"] ?? 0.0).reduce((a, b) => a + b) /
          statsInPhase.length;
      double avgRer =
          statsInPhase.map((s) => s["rer"] ?? 0.0).reduce((a, b) => a + b) /
          statsInPhase.length;
      double avgVe =
          statsInPhase
              .map((s) => s["minuteVentilation"] ?? 0.0)
              .reduce((a, b) => a + b) /
          statsInPhase.length;
      double avgHr =
          statsInPhase.map((s) => s["hr"] ?? 0.0).reduce((a, b) => a + b) /
          statsInPhase.length;

      // Calculate avgVo2kg if possible
      double? avgVo2kg;
      double? weight = double.tryParse((patient?['weight'] ?? '').toString());
      if (weight != null && weight > 0) {
        avgVo2kg = avgVo2 * 1000 / weight;
      }

      // Calculate avgTime in mm:ss for the phase
      String? avgTime;
      if (statsInPhase.isNotEmpty && statsInPhase.first.containsKey('index')) {
        int avgIdx =
            (statsInPhase.map((s) => s["index"] ?? 0).reduce((a, b) => a + b) /
                    statsInPhase.length)
                .round();
        int seconds = (avgIdx / 300).floor(); // assuming 300Hz sampling rate
        avgTime =
            "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";
      }

      return {
        "time": avgTime,
        "vo2": avgVo2,
        "vo2kg": avgVo2kg,
        "vco2": avgVco2,
        "rer": avgRer,
        "ve": avgVe,
        "hr": avgHr,
      };
    }

    // --- Prediction formulas ---
    double? height = double.tryParse((patient?['height'] ?? '').toString());
    double? weight = double.tryParse((patient?['weight'] ?? '').toString());
    int? age = int.tryParse((patient?['age'] ?? '').toString());
    String gender = (patient?['gender'] ?? '').toString().toLowerCase();

    double? vo2max;
    if (height != null && weight != null && age != null) {
      if (gender == 'male' || gender == 'm') {
        vo2max = (0.023 * height) - (0.021 * age) + (0.0111 * weight) - 1.40;
      } else if (gender == 'female' || gender == 'f') {
        vo2max = (0.021 * height) - (0.019 * age) + (0.00737 * weight) - 0.60;
      }
    }

    double? vo2kgPred =
        (vo2max != null && weight != null && weight > 0)
            ? vo2max * 1000 / weight
            : null;
    double? vePred = vo2max != null ? vo2max * 27 : null;
    double? vco2Pred = vo2max != null ? vo2max * 1.10 : null;
    double? rerPred = 1.10; // at peak
    double? reePred =
        (weight != null && height != null && age != null)
            ? (10 * weight +
                6.25 * height -
                5 * age +
                5) // +5 for men, -161 for women (Mifflin-St Jeor)
            : null;
    if (gender == 'female' || gender == 'f') {
      if (reePred != null) reePred = reePred - 166;
    }

    // Stat names and display labels
    final statKeys = [
      {"key": "time", "label": "Time (mm:ss)", "pred": "-"},
      {"key": "vo2", "label": "VO2max (L/min)", "pred": vo2max},
      {"key": "vo2kg", "label": "VO2/kg (mL/min/kg)", "pred": vo2kgPred},
      {"key": "ve", "label": "VE (L/min)", "pred": vePred},
      {"key": "vco2", "label": "V'CO2 (L/min)", "pred": vco2Pred},
      {"key": "rer", "label": "RER", "pred": rerPred},
      {"key": "ree", "label": "REE (kcal/day)", "pred": reePred},
      {"key": "hr", "label": "HR", "pred": "-"},
    ];

    // Phase names for columns (add AT)
    final phaseNames = [
      for (int i = 0; i < phaseRanges.length; i++)
        (() {
          final phase = phases.firstWhere(
            (p) => p['id'] == phaseRanges[i]["name"],
            orElse: () => <String, dynamic>{},
          );
          return phase['name'] ?? phaseRanges[i]["name"];
        })(),
      "AT",
      "% Pred",
    ];

    // Get AT stats using selected method
    final atStats = getATPhaseStats(
      breathStats: breathStats,
      patient: patient,
      method: atDetectionMethod,
    );

    // Build rows: each stat, with prediction and value for each phase and AT
    final data = [
      for (final stat in statKeys)
        [
          stat["label"],
          stat["pred"] is double
              ? (stat["pred"] as double).toStringAsFixed(2)
              : (stat["pred"]?.toString() ?? "-"),
          ...[
            for (int i = 0; i < phaseRanges.length; i++)
              (() {
                final stats = getPhaseStats(
                  phaseRanges[i]["start"],
                  phaseRanges[i]["end"],
                );
                final val = stats[stat["key"]];
                if (val == null) return "-";
                if (stat["key"] == "hr") return val.toStringAsFixed(0);
                if (stat["key"] == "time") return val.toString();
                if (val is double) return val.toStringAsFixed(2);
                return val.toString();
              })(),
            // AT column
            (() {
              final atVal =
                  stat["key"] == "time"
                      ? atStats!["at_time"]
                      : atStats![stat["key"]];
              if (atVal == null) return "-";
              if (stat["key"] == "hr") return atVal.toStringAsFixed(0);
              if (stat["key"] == "time") return atVal.toString();
              if (atVal is double) return atVal.toStringAsFixed(2);
              return atVal.toString();
            })(),
            // % Pred column (after AT)
            (() {
              // Only show % for numeric stats with a prediction
              final pred = stat["pred"];
              final atVal =
                  stat["key"] == "time" ? null : atStats?[stat["key"]];
              if (pred is double && atVal is double && pred != 0) {
                return "${((atVal / pred) * 100).toStringAsFixed(0)} %";
              }
              return "-";
            })(),
          ],
        ],
    ];

    return pw.Table.fromTextArray(
      headers: ["Parameter", "Pred", ...phaseNames],
      data: data,
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      headerDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
        ),
      ),
      cellStyle: pw.TextStyle(fontSize: 7),
      cellHeight: 16,
      border: null,
      columnWidths: {
        for (var i = 0; i < phaseNames.length + 2; i++)
          i: const pw.FlexColumnWidth(),
      },
    );
  }

  List<String> getBreathStatsHeaders(List<Map<String, dynamic>> breathStats) {
    if (breathStats.isEmpty) return [];
    return breathStats.first.keys.toList();
  }

  List<List<String>> getBreathStatsRows(
    List<Map<String, dynamic>> breathStats,
    List<String> headers,
  ) {
    return breathStats.map((row) {
      return headers.map((h) {
        final val = row[h];
        if (val == null) return '-';
        if (val is double) return val.toStringAsFixed(3);
        return val.toString();
      }).toList();
    }).toList();
  }

  List<Map<String, dynamic>> getAveragedBreathStats(
    List<Map<String, dynamic>> breathStats,
    int samplingRate,
    int intervalSeconds,
  ) {
    int samplesPerInterval = samplingRate * intervalSeconds;
    List<Map<String, dynamic>> averagedStats = [];

    for (int i = 0; i < breathStats.length; i += samplesPerInterval) {
      final group = breathStats.sublist(
        i,
        (i + samplesPerInterval).clamp(0, breathStats.length),
      );

      if (group.isEmpty) continue;

      Map<String, dynamic> avgRow = {};
      // Calculate time string for this interval
      int seconds = ((i + samplesPerInterval) / samplingRate).floor();
      avgRow['time'] =
          "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";

      // Average numeric columns
      final keys = group.first.keys.where((k) => k != 'index');
      for (var key in keys) {
        final values = group.map((row) => row[key]).whereType<num>().toList();
        avgRow[key] =
            values.isNotEmpty
                ? values.reduce((a, b) => a + b) / values.length
                : '-';
      }
      averagedStats.add(avgRow);
    }
    return averagedStats;
  }

  final GlobalKey _veTimeChartKey = GlobalKey();

  Future<Uint8List?> _captureChartImage(GlobalKey key) async {
    RenderRepaintBoundary? boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    var image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    // global settings from provider
    final globalSettings = pvrd.Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );

    print('Building PDF with format: $format');

    print(widget.breathStats);
    final pdf = pw.Document();

    final patientName = widget.patient['name'] ?? '';
    final patientAge = widget.patient['age']?.toString() ?? '';
    final patientGender = widget.patient['gender'] ?? '';
    final patientWeight = widget.patient['weight']?.toString() ?? '';
    final reportDate = DateTime.now().toString().split(' ').first;

    // Dynamically get headers and rows
    final samplingRate = 300;
    final timeRows = convertIndexToTimeRows(widget.breathStats, samplingRate);

    final headers = ['time', ...timeRows.first.keys.where((k) => k != 'time')];
    final rows =
        timeRows.map((row) {
          return headers.map((h) {
            final val = row[h];
            if (val == null) return '-';
            if (val is double) return val.toStringAsFixed(3);
            return val.toString();
          }).toList();
        }).toList();

    print('Headers: $headers');
    print('Rows: $rows');

    // Load logo image bytes before building PDF widgets
    final logoBytes =
        (await rootBundle.load('assets/logo.png')).buffer.asUint8List();

    // First page (existing content)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build:
            (context) => [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        globalSettings.hospitalName ?? 'Hospital Name',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (globalSettings.hospitalAddress != null &&
                          globalSettings.hospitalAddress!.isNotEmpty)
                        pw.Text(
                          globalSettings.hospitalAddress!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                  pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(color: PdfColors.blue),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Patient Name: $patientName',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'Age: $patientAge',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'Gender: $patientGender',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Height: ${widget.patient['height']?.toString() ?? '-'} cm',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'Weight: $patientWeight kg',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          'Date: $reportDate',
                          style: pw.TextStyle(
                            color: PdfColors.grey700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.graphBase64List != null &&
                  widget.graphBase64List!.isNotEmpty)
                ...widget.graphBase64List!.map(
                  (base64String) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Image(
                      pw.MemoryImage(
                        base64Decode(base64String.split(',').last),
                      ),
                    ),
                  ),
                ),
              pw.Divider(color: PdfColors.blue),
              // pw.Text(
              //   'Breath Stats:',
              //   style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              // ),
              buildPhaseStatsPdfTable(
                markers: widget.markers!,
                breathStats: widget.breathStats,
                phases: widget.protocolDetails!['phases'] ?? [],
                patient: widget.patient,
                atDetectionMethod:
                    globalSettings.atDetectionMethod ??
                    "VO2 max", // Use global settings for AT detection method
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: headers,
                data: rows,
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 5,
                ),
                headerDecoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
                  ),
                ),
                cellStyle: pw.TextStyle(fontSize: 5),
                cellHeight: 10,
                border: null,
                columnWidths: {
                  for (var i = 0; i < headers.length; i++)
                    i: const pw.FlexColumnWidth(),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Generated by SpiroBT | $reportDate',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
      ),
    );

    // // Capture chart image
    // Uint8List? chartImage;
    // try {
    //   // Ensure the chart is painted before capturing
    //   await Future.delayed(const Duration(milliseconds: 100));
    //   chartImage = await _captureChartImage(_rerChartKey);
    // } catch (e) {
    //   // Use dart:developer log instead of print
    //   developer.log(
    //     "Error capturing chart image: $e",
    //     name: 'ReportPreviewPage',
    //   );
    //   print("Error capturing chart image: $e");
    //   chartImage = null;
    // }

    // Add last page with chart image
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RER vs Time Chart',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                if (chartImage != null)
                  pw.Image(pw.MemoryImage(chartImage!), width: 500, height: 250)
                else
                  pw.Text('Chart image not available.'),
              ],
            ),
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: const Text('Report Preview'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          PdfPreview(
            key: pdfPreviewKey,
            build: _buildPdf,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: false,
            allowSharing: false,
          ),
          Offstage(
            offstage: !_showChart,
            child: RepaintBoundary(
              key: _veTimeChartKey,
              child: ChartsBuilder.buildTimeVsVEChart(
                context,
                widget.breathStats,
                width: 600,
                height: 300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<File> generateBreathStatsPdf({
  required String filePath,
  required Map<String, dynamic> patient,
  required List<Map<String, dynamic>> breathStats,
  List<File>? chartImages, // Optional: chart images as File
}) async {
  final pdf = pw.Document();

  // Prepare patient info
  final patientName = patient['name'] ?? '';
  final patientAge = patient['age']?.toString() ?? '';
  final patientGender = patient['gender'] ?? '';
  final patientWeight = patient['weight']?.toString() ?? '';
  final reportDate = DateTime.now().toString().split(' ').first;

  // Prepare table headers and rows
  final headers = [
    "V'O2 [L/min]",
    "V'O2/kg [mL/min/kg]",
    "V'CO2 [L/min]",
    "RER []",
    "V'E [L/min]",
    "VT [L]",
    "HR [1/min]",
  ];
  final rows =
      breathStats
          .map(
            (row) => [
              row['vo2']?.toString() ?? '',
              row['vo2kg']?.toString() ?? '',
              row['vco2']?.toString() ?? '',
              row['rer']?.toString() ?? '',
              row['minuteVentilation']?.toString() ?? '',
              row['vt']?.toString() ?? '',
              row['hr']?.toString() ?? '',
            ],
          )
          .toList();

  pdf.addPage(
    pw.Page(
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Breath Stats Report',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Patient Name: $patientName'),
              pw.Text('Age: $patientAge'),
              pw.Text('Gender: $patientGender'),
              pw.Text('Weight: $patientWeight kg'),
              pw.Text('Date: $reportDate'),
              pw.Divider(color: PdfColors.blue),
              if (chartImages != null && chartImages.isNotEmpty)
                ...chartImages.map(
                  (imgFile) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Image(pw.MemoryImage(imgFile.readAsBytesSync())),
                  ),
                ),
              pw.Text(
                'Breath Stats:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Table.fromTextArray(
                headers: headers,
                data: rows,
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Generated by SpiroBT | $reportDate',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
    ),
  );

  final file = File(filePath);
  await file.writeAsBytes(await pdf.save());
  return file;
}

List<Map<String, dynamic>> convertIndexToTimeRows(
  List<Map<String, dynamic>> breathStats,
  int samplingRate,
) {
  return breathStats.map((row) {
    final idx = row['index'] ?? 0;
    final seconds = (idx / samplingRate).floor();
    final timeStr =
        "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}";
    final newRow = Map<String, dynamic>.from(row);
    newRow['time'] = timeStr;
    newRow.remove('index');
    return newRow;
  }).toList();
}
