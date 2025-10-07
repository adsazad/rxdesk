import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart' as pvrd;
import 'package:holtersync/ProviderModals/GlobalSettingsModal.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';

/// A minimal report preview page that renders only headers/infos.
/// Graphs/tables can be added later.
class ReportPreviewPageLite extends StatefulWidget {
  final Map<String, dynamic> patient;
  final String title;
  final DateTime? recordedAt;
  final Map<String, dynamic>? recordingInfo; // optional extra info (e.g., file path)
  // Holter analyzer with computed metrics and RR intervals
  final HolterReportGenerator holter;

  const ReportPreviewPageLite({
    super.key,
    required this.patient,
    this.title = 'ECG Report',
    this.recordedAt,
    this.recordingInfo,
    required this.holter,
  });

  @override
  State<ReportPreviewPageLite> createState() => _ReportPreviewPageLiteState();
}

class _ReportPreviewPageLiteState extends State<ReportPreviewPageLite> {
  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final settings = pvrd.Provider.of<GlobalSettingsModal>(context, listen: false);
    final pdf = pw.Document();

    final logoBytes = await _loadLogoBytes();

    // Pull metrics from the Holter analyzer
    final holter = widget.holter;
    final double? avgBpm = (holter.avrBpm > 0) ? holter.avrBpm : null;
    final double? minBpm = (holter.minBpm > 0) ? holter.minBpm : null;
    final double? maxBpm = (holter.maxBpm > 0) ? holter.maxBpm : null;

    // Compute HRV metrics from RR intervals (seconds) if available
    final List<double> rr = (holter.allRrIntervals);
    double? sdnnMs;
    double? rmssdMs;
    double? pnn50;
    double? nn50;
    if (rr.isNotEmpty) {
      final rrMs = rr.map((s) => s * 1000.0).toList();
      // SDNN: standard deviation of NN intervals (ms)
      if (rrMs.length >= 2) {
        final m = rrMs.reduce((a, b) => a + b) / rrMs.length;
        final varSum = rrMs.fold<double>(0.0, (sum, v) => sum + (v - m) * (v - m));
        final v = (varSum / (rrMs.length - 1));
        sdnnMs = math.sqrt(v < 0 ? 0 : v);
      }
      // RMSSD: sqrt(mean of squared successive differences)
      if (rrMs.length >= 2) {
        double ss = 0.0;
        for (int i = 1; i < rrMs.length; i++) {
          final d = rrMs[i] - rrMs[i - 1];
          ss += d * d;
        }
        final v = (ss / (rrMs.length - 1));
        rmssdMs = math.sqrt(v < 0 ? 0 : v);
      }
      // NN50/pNN50
      if (rrMs.length >= 2) {
        int count = 0;
        for (int i = 1; i < rrMs.length; i++) {
          if ((rrMs[i] - rrMs[i - 1]).abs() > 50.0) count++;
        }
        nn50 = count.toDouble();
        pnn50 = (count / (rrMs.length - 1)) * 100.0;
      }
    }

    final patientName = (widget.patient['name'] ?? '').toString();
    final patientAge = (widget.patient['age'] ?? '').toString();
    final patientGender = (widget.patient['gender'] ?? '').toString();
    final patientWeight = (widget.patient['weight'] ?? '').toString();
    final patientHeight = (widget.patient['height'] ?? '').toString();
    final reportDate = DateTime.now().toString().split(' ').first;
    final recordedAt = widget.recordedAt?.toString() ?? '-';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) => [
          // Header with hospital info and logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    settings.hospitalName.isNotEmpty
                        ? settings.hospitalName
                        : 'Hospital/Clinic Name',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  if (settings.hospitalAddress.isNotEmpty)
                    pw.Text(settings.hospitalAddress, style: const pw.TextStyle(fontSize: 10)),
                  if (settings.hospitalContact.isNotEmpty)
                    pw.Text('Contact: ${settings.hospitalContact}', style: const pw.TextStyle(fontSize: 10)),
                  if (settings.hospitalEmail.isNotEmpty)
                    pw.Text('Email: ${settings.hospitalEmail}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60, fit: pw.BoxFit.contain),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.blue),
          // Report title + date
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(widget.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: $reportDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 8),
          // Patient and recording information
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kv('Patient Name', patientName),
                    _kv('Age', patientAge),
                    _kv('Gender', patientGender),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kv('Height (cm)', patientHeight),
                    _kv('Weight (kg)', patientWeight),
                    _kv('Recorded At', recordedAt),
                  ],
                ),
              ),
            ],
          ),
          if (widget.recordingInfo != null && widget.recordingInfo!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Recording Info', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _infoTable(widget.recordingInfo!),
          ],
          if (avgBpm != null || minBpm != null || maxBpm != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('ECG Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _summaryTable({
              if (avgBpm != null) 'Average BPM': avgBpm.toStringAsFixed(0),
              if (minBpm != null) 'Min BPM': minBpm.toStringAsFixed(0),
              if (maxBpm != null) 'Max BPM': maxBpm.toStringAsFixed(0),
            }),
          ],
          if (sdnnMs != null || rmssdMs != null || pnn50 != null || nn50 != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('HRV Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            _summaryTable({
              if (sdnnMs != null) 'SDNN (ms)': sdnnMs.toStringAsFixed(0),
              if (rmssdMs != null) 'RMSSD (ms)': rmssdMs.toStringAsFixed(0),
              if (pnn50 != null) 'pNN50 (%)': pnn50.toStringAsFixed(1),
              if (nn50 != null) 'NN50 (#)': nn50.toStringAsFixed(0),
            }),
          ],
          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          pw.Text('Graphs and analysis will appear here in future versions.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List?> _loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  pw.Widget _kv(String k, String v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 90, child: pw.Text('$k:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(child: pw.Text(v.isEmpty ? '-' : v, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  pw.Widget _infoTable(Map<String, dynamic> info) {
    final rows = info.entries
        .map((e) => [e.key, (e.value is num) ? e.value.toString() : (e.value?.toString() ?? '-')])
        .toList();
    return pw.Table.fromTextArray(
      headers: const ['Key', 'Value'],
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      border: null,
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
    );
  }

  pw.Widget _summaryTable(Map<String, String> summary) {
    if (summary.isEmpty) return pw.Container();
    final rows = summary.entries.map((e) => [e.key, e.value]).toList();
    return pw.Table.fromTextArray(
      headers: const ['Metric', 'Value'],
      data: rows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      border: null,
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Preview'),
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(format),
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
