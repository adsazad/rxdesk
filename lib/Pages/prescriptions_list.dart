import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:medicore/data/local/database.dart';
import 'package:medicore/Pages/prescription_composer.dart' hide Medicine;
import 'package:medicore/Pages/prescription_print_preview.dart';

class PrescriptionsList extends StatefulWidget {
  final int? patientId;
  final Patient? patient;

  const PrescriptionsList({super.key, this.patientId, this.patient});

  @override
  State<PrescriptionsList> createState() => _PrescriptionsListState();
}

class _PrescriptionsListState extends State<PrescriptionsList> {
  List<Prescription> _prescriptions = [];
  Map<int, List<Medicine>> _meds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    final query = db.select(db.prescriptions);
    if (widget.patientId != null) {
      query.where((p) => p.patientId.equals(widget.patientId!));
    }
    query.orderBy([(p) => drift.OrderingTerm(expression: p.createdAt, mode: drift.OrderingMode.desc)]);
    final list = await query.get();
    final medsBy = <int, List<Medicine>>{};
    for (final p in list) {
      medsBy[p.id] = await (db.select(db.medicines)..where((m) => m.prescriptionId.equals(p.id))).get();
    }
    setState(() {
      _prescriptions = list;
      _meds = medsBy;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.patient != null ? 'Prescriptions - ${widget.patient!.name}' : 'All Prescriptions';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (widget.patient != null)
            IconButton(
              tooltip: 'New Prescription',
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrescriptionComposer(patientId: widget.patientId, patient: widget.patient),
                  ),
                );
                _load();
              },
            ),
        ],
      ),
      body: _prescriptions.isEmpty
          ? _emptyView()
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _prescriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _tile(_prescriptions[i], _meds[_prescriptions[i].id] ?? const []),
            ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No prescriptions found', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          if (widget.patient != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrescriptionComposer(patientId: widget.patientId, patient: widget.patient),
                  ),
                );
                _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create First Prescription'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile(Prescription p, List<Medicine> meds) {
    final subtle = Colors.grey[650];
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Rx #${p.id}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue)),
                ),
                Text(_date(p.createdAt), style: TextStyle(fontSize: 11, color: subtle)),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Print',
                  icon: const Icon(Icons.print, size: 16),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PrescriptionPrintPreview(prescriptionId: p.id)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            _kv('Diagnosis', p.diagnosis),
            if ((p.notes ?? '').isNotEmpty) _kv('Notes', p.notes!, maxLines: 2),
                        if (meds.isNotEmpty) ...[
              const SizedBox(height: 4),
              _medsCompact(meds),
            ],
            if ((p.customInstructions ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Instructions: ${p.customInstructions!}', style: TextStyle(fontSize: 11, color: subtle)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {int? maxLines}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$k: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            v,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _vitals(Prescription p) {
    final parts = <String>[];
    if (p.bpSystolic != null && p.bpDiastolic != null) parts.add('BP ${p.bpSystolic}/${p.bpDiastolic}');
    if (p.heartRate != null) parts.add('HR ${p.heartRate}');
    if (p.temperature != null) parts.add('Temp ${p.temperature}\u00B0F');
    if (p.spo2 != null) parts.add('SpO\u2082 ${p.spo2}%');
    return Text(parts.join('  •  '), style: TextStyle(fontSize: 11, color: Colors.grey[650]));
  }

  Widget _medsCompact(List<Medicine> meds) {
    final shown = meds.take(3).toList();
    final rest = meds.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Expanded(
                  child: Text(
                    _medLine(m),
                    style: TextStyle(fontSize: 12, color: Colors.grey[650]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (rest > 0) Text('+$rest more', style: TextStyle(fontSize: 11, color: Colors.grey[650])),
      ],
    );
  }

  String _medLine(Medicine m) {
    final parts = <String>[];
    parts.add(m.name);
    if ((m.strength ?? '').isNotEmpty) parts.add(m.strength!);
    if ((m.dose ?? '').isNotEmpty) parts.add(m.dose!);
    if ((m.frequency ?? '').isNotEmpty) parts.add(m.frequency!);
    if ((m.duration ?? '').isNotEmpty) parts.add('for ${m.duration!}');
    if ((m.route ?? '').isNotEmpty) parts.add('(${m.route!})');
    return parts.join(' • ');
  }

  bool _hasVitals(Prescription p) {
    return p.bpSystolic != null || p.bpDiastolic != null || p.heartRate != null || p.temperature != null || p.spo2 != null;
  }

  String _date(DateTime d) {
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} ${d.hour}:$mm';
  }
}
