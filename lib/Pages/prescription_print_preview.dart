import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:medicore/ProviderModals/GlobalSettingsModal.dart';
import 'package:medicore/data/local/database.dart';

class PrescriptionPrintPreview extends StatefulWidget {
  final int prescriptionId;
  const PrescriptionPrintPreview({super.key, required this.prescriptionId});

  @override
  State<PrescriptionPrintPreview> createState() => _PrescriptionPrintPreviewState();
}

class _PrescriptionPrintPreviewState extends State<PrescriptionPrintPreview> {
  Patient? _patient;
  Prescription? _prescription;
  List<Medicine> _medicines = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final p = await (db.select(db.prescriptions)..where((t) => t.id.equals(widget.prescriptionId))).getSingle();
      final patient = await (db.select(db.patients)..where((t) => t.id.equals(p.patientId))).getSingle();
      final meds = await (db.select(db.medicines)..where((t) => t.prescriptionId.equals(widget.prescriptionId))).get();
      setState(() {
        _prescription = p;
        _patient = patient;
        _medicines = meds;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  pw.Widget _kv(String k, String? v) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 90, child: pw.Text('$k:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Expanded(child: pw.Text((v == null || v.isEmpty) ? '-' : v, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final settings = Provider.of<GlobalSettingsModal>(context, listen: false);
    final pdf = pw.Document();

    final margin = pw.EdgeInsets.fromLTRB(
      PdfPageFormat.mm * settings.marginLeftMm,
      PdfPageFormat.mm * settings.marginTopMm,
      PdfPageFormat.mm * settings.marginRightMm,
      PdfPageFormat.mm * settings.marginBottomMm,
    );

    // Compute page format from settings
    PdfPageFormat pageFmt = settings.paperSize == 'Letter' ? PdfPageFormat.letter : PdfPageFormat.a4;
    if (settings.orientation == 'landscape') {
      pageFmt = pageFmt.landscape;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFmt,
        margin: margin,
        header: settings.printHeader
            ? (ctx) {
                final children = <pw.Widget>[];
                pw.Widget? logo;
                if (settings.logoPath.isNotEmpty) {
                  try {
                    final bytes = File(settings.logoPath).readAsBytesSync();
                    logo = pw.Image(pw.MemoryImage(bytes), width: 60, height: 60, fit: pw.BoxFit.contain);
                  } catch (_) {}
                }
                final infoCol = pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      settings.hospitalName.isNotEmpty ? settings.hospitalName : 'Hospital/Clinic Name',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    if (settings.hospitalAddress.isNotEmpty)
                      pw.Text(settings.hospitalAddress, style: const pw.TextStyle(fontSize: 10)),
                    if (settings.hospitalContact.isNotEmpty)
                      pw.Text('Contact: ${settings.hospitalContact}', style: const pw.TextStyle(fontSize: 10)),
                    if (settings.hospitalEmail.isNotEmpty)
                      pw.Text('Email: ${settings.hospitalEmail}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                );

                pw.MainAxisAlignment align;
                switch (settings.headerLogoAlignment) {
                  case 'center':
                    align = pw.MainAxisAlignment.center;
                    break;
                  case 'right':
                    align = pw.MainAxisAlignment.end;
                    break;
                  default:
                    align = pw.MainAxisAlignment.spaceBetween;
                }

                // Build header row
                final rowChildren = <pw.Widget>[];
                if (settings.headerLogoAlignment == 'left') {
                  if (logo != null) rowChildren.add(logo);
                  rowChildren.add(pw.SizedBox(width: 12));
                  rowChildren.add(pw.Expanded(child: infoCol));
                  rowChildren.add(pw.Text('Prescription', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
                } else if (settings.headerLogoAlignment == 'center') {
                  if (logo != null) rowChildren.add(logo);
                  rowChildren.add(pw.SizedBox(width: 12));
                  rowChildren.add(infoCol);
                } else {
                  // right
                  rowChildren.add(pw.Expanded(child: infoCol));
                  rowChildren.add(pw.SizedBox(width: 12));
                  if (logo != null) rowChildren.add(logo);
                }

                children.add(
                  pw.Row(
                    mainAxisAlignment: align,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: rowChildren,
                  ),
                );
                children.add(pw.SizedBox(height: 6));
                children.add(pw.Divider(color: PdfColors.blue));
                return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
              }
            : null,
        footer: settings.printFooter
            ? (ctx) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(settings.footerText, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                )
            : null,
        build: (context) {
          final body = <pw.Widget>[];

          // Patient + Vitals
          body.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Patient', _patient?.name),
                      _kv('Age', _patient?.age.toString()),
                      _kv('Gender', _patient?.gender),
                      _kv('Mobile', _patient?.mobile),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _kv('Height (cm)', _patient?.height.toString()),
                      _kv('Weight (kg)', _patient?.weight.toString()),
                      _kv('BP', _bpString()),
                      _kv('SpO₂', _prescription?.spo2),
                    ],
                  ),
                ),
              ],
            ),
          );

          body.add(pw.SizedBox(height: 10));
          body.add(pw.Text('Diagnosis', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
          body.add(pw.SizedBox(height: 4));
          body.add(pw.Text(_prescription?.diagnosis ?? '-', style: const pw.TextStyle(fontSize: 11)));

          if ((_prescription?.notes ?? '').isNotEmpty) {
            body.add(pw.SizedBox(height: 8));
            body.add(pw.Text('Clinical Notes', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            body.add(pw.SizedBox(height: 4));
            body.add(pw.Text(_prescription!.notes!, style: const pw.TextStyle(fontSize: 11)));
          }

          // Medicines
          body.add(pw.SizedBox(height: 10));
          body.add(pw.Text('Medicines', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
          body.add(pw.SizedBox(height: 6));
          body.add(_medicinesTable());

          if ((_prescription?.customInstructions ?? '').isNotEmpty) {
            body.add(pw.SizedBox(height: 10));
            body.add(pw.Text('Instructions', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            body.add(pw.SizedBox(height: 4));
            body.add(pw.Text(_prescription!.customInstructions!, style: const pw.TextStyle(fontSize: 11)));
          }

          // Signature block (at end of body)
          if (settings.showSignatureLine || settings.doctorName.isNotEmpty || settings.doctorRegistration.isNotEmpty) {
            body.add(pw.SizedBox(height: 24));
            body.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (settings.showSignatureLine)
                          pw.Container(height: 1, color: PdfColors.grey700),
                        pw.SizedBox(height: 4),
                        if (settings.doctorName.isNotEmpty)
                          pw.Text(settings.doctorName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if (settings.doctorRegistration.isNotEmpty)
                          pw.Text('Reg: ${settings.doctorRegistration}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return body;
        },
      ),
    );

    return pdf.save();
  }

  String _bpString() {
    final s = _prescription?.bpSystolic;
    final d = _prescription?.bpDiastolic;
    if ((s == null || s.isEmpty) && (d == null || d.isEmpty)) return '-';
    return '${s ?? '-'} / ${d ?? '-'}';
  }

  pw.Widget _medicinesTable() {
    if (_medicines.isEmpty) {
      return pw.Text('No medicines prescribed', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700));
    }
    final rows = _medicines.map((m) => [
          m.name,
          m.strength ?? '-',
          m.dose ?? '-',
          m.frequency ?? '-',
          m.duration ?? '-',
          m.route ?? '-',
        ]);
    return pw.Table.fromTextArray(
      headers: const ['Name', 'Strength', 'Dose', 'Freq', 'Duration', 'Route'],
      data: rows.toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      border: null,
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
        4: pw.FlexColumnWidth(2),
        5: pw.FlexColumnWidth(2),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prescription Preview')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Prescription Preview')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription Preview')),
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
