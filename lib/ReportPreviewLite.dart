import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart' as pvrd;
import 'package:holtersync/ProviderModals/GlobalSettingsModal.dart';

/// A minimal report preview page that renders only headers/infos.
/// Graphs/tables can be added later.
class ReportPreviewPageLite extends StatefulWidget {
  final Map<String, dynamic> patient;
  final String title;
  final DateTime? recordedAt;
  final Map<String, dynamic>? recordingInfo; // optional extra info (e.g., file path)

  const ReportPreviewPageLite({
    super.key,
    required this.patient,
    this.title = 'ECG Report',
    this.recordedAt,
    this.recordingInfo,
  });

  @override
  State<ReportPreviewPageLite> createState() => _ReportPreviewPageLiteState();
}

class _ReportPreviewPageLiteState extends State<ReportPreviewPageLite> {
  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final settings = pvrd.Provider.of<GlobalSettingsModal>(context, listen: false);
    final pdf = pw.Document();

    final logoBytes = await _loadLogoBytes();

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
