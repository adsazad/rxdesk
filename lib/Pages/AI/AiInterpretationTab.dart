import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class AiInterpretationTab extends StatefulWidget {
  final HolterReportGenerator holter;

  const AiInterpretationTab({super.key, required this.holter});

  @override
  State<AiInterpretationTab> createState() => _AiInterpretationTabState();
}

class _AiInterpretationTabState extends State<AiInterpretationTab> {
  bool _isRunning = false;
  String _consolidatedReport = '';
  List<dynamic> _preds = [];

  String get _guidKey {
    final f = widget.holter.fileName ?? '';
    return f.isEmpty ? 'current' : p.basename(f);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load cached consolidated report and predictions if available
    // final prefs = await SharedPreferences.getInstance();
    // final cKey = 'aireport-c-$_guidKey';
    // final aKey = 'aireport-a-$_guidKey';
    // final c = prefs.getString(cKey);
    // final a = prefs.getString(aKey);
    // if (!mounted) return;
    // if (c != null && a != null) {
    //   setState(() {
    //     _consolidatedReport = c;
    //     _preds = jsonDecode(a);
    //   });
    //   return;
    // }
    // // If nothing cached, try to show current holter conditions (if any)
    // if (widget.holter.conditions is List &&
    //     (widget.holter.conditions as List).isNotEmpty) {
    //   setState(() {
    //     _preds = (widget.holter.conditions as List);
    //     _consolidatedReport =
    //         _preds.isEmpty ? 'Normal Sinus Rhythm' : 'Abnormal ECG';
    //   });
    // }
  }

  Future<void> _runAiInterpretation() async {
    if (_isRunning) return;
    if (widget.holter.fileName == null ||
        (widget.holter.fileName?.isEmpty ?? true))
      return;
    setState(() => _isRunning = true);
    print("running ai");
    try {
      await widget.holter.aiReporter();
      // Extract predictions from holter after run
      List<dynamic> predictions = [];
      if (widget.holter.conditions is List) {
        predictions = (widget.holter.conditions as List);
      }
      final consolidated =
          predictions.isEmpty ? 'Normal Sinus Rhythm' : 'Abnormal ECG';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'aiInterpretationStatus:${widget.holter.fileName}',
        'yes',
      );
      await prefs.setString('aireport-c-$_guidKey', consolidated);
      await prefs.setString('aireport-a-$_guidKey', jsonEncode(predictions));

      if (!mounted) return;
      setState(() {
        _consolidatedReport = consolidated;
        _preds = predictions;
      });
    } catch (_) {
      // ignore for now
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Widget _statBox(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final holter = widget.holter;
    final hasData =
        (holter.fileName?.isNotEmpty ?? false) ||
        holter.allRrIndexes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: hasData && !_isRunning ? _runAiInterpretation : null,
                icon: const Icon(Icons.bolt),
                label: Text(_isRunning ? 'Running…' : 'Run AI interpretation'),
              ),
              const SizedBox(width: 12),
              if (_isRunning)
                ValueListenableBuilder<String>(
                  valueListenable: holter.progress,
                  builder: (_, value, __) => Text('Progress: $value'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statBox(
                'Avg BPM',
                (holter.avrBpm > 0) ? holter.avrBpm.toStringAsFixed(1) : '--',
              ),
              _statBox(
                'Min BPM',
                (holter.minBpm > 0) ? holter.minBpm.toStringAsFixed(1) : '--',
              ),
              _statBox(
                'Max BPM',
                (holter.maxBpm > 0) ? holter.maxBpm.toStringAsFixed(1) : '--',
              ),
              _statBox(
                'R-peaks',
                holter.allRrIndexes.isNotEmpty
                    ? holter.allRrIndexes.length.toString()
                    : '--',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _consolidatedReport.isEmpty
                ? 'Detected conditions'
                : _consolidatedReport,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                hasData
                    ? (_preds.isNotEmpty)
                        ? ListView.builder(
                          itemCount: _preds.length,
                          itemBuilder: (_, idx) {
                            final cond = _preds[idx];
                            final name =
                                cond['name']?.toString() ??
                                cond['classification']?.toString() ??
                                'Unknown';
                            final count =
                                (cond['index'] is List)
                                    ? (cond['index'] as List).length
                                    : (cond['confidence'] != null ? 1 : 0);
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.analytics),
                                title: Text(name),
                                subtitle: Text(
                                  count > 0 ? 'Occurrences: $count' : '',
                                ),
                              ),
                            );
                          },
                        )
                        : const Center(
                          child: Text(
                            'No conditions detected yet. Run AI interpretation.',
                          ),
                        )
                    : const Center(child: Text('Load a recording first.')),
          ),
        ],
      ),
    );
  }
}
