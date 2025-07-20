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
  final List<String>?
  graphBase64List; // Optional: List of base64 PNGs for graphs

  const ReportPreviewPage({
    Key? key,
    required this.patient,
    required this.breathStats,
    this.graphBase64List,
  }) : super(key: key);

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  late String htmlContent;

  Uint8List? chartImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      chartImage = await _captureChartImage(_rerChartKey);
      setState(() {}); // Now chartImage is ready for PDF
    });
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

  final GlobalKey _rerChartKey = GlobalKey();

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
              pw.Divider(),
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
              pw.Divider(),
              // pw.Text(
              //   'Breath Stats:',
              //   style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              // ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                cellAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellStyle: pw.TextStyle(fontSize: 8),
                cellHeight: 18,
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
            build: _buildPdf,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: false,
            allowSharing: false,
          ),
          Offstage(
            offstage: true,
            child: RepaintBoundary(
              key: _rerChartKey,
              child: ChartsBuilder.buildTimeVsRERChart(
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
    "V'O₂ [L/min]",
    "V'O₂/kg [mL/min/kg]",
    "V'CO₂ [L/min]",
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
              pw.Divider(),
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
