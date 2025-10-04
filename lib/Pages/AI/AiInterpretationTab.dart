import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';
import 'package:holtersync/Widgets/MyBigGraphScrollable.dart';
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
  // cursor per condition name to navigate occurrences
  final Map<String, int> _cursorByCondition = {};
  // simple in-memory cache for preview segments: key => samples
  final Map<String, List<double>> _previewCache = {};
  // detail viewer for 1-minute preview around tapped segment
  final GlobalKey<MyBigGraphV2State> _aiDetailGraphKey = GlobalKey();
  List<double> _detailMinuteData = const [];
  int? _detailCenterSample;

  String get _guidKey {
    final f = widget.holter.fileName ?? '';
    return f.isEmpty ? 'current' : p.basename(f);
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
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 300,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final cond in _preds)
                                      _buildConditionCard(context, cond),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_detailMinuteData.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4.0,
                                        bottom: 6.0,
                                      ),
                                      child: Text(
                                        '30-second preview around sample: ${(((_detailCenterSample ?? 0) / widget.holter.sampleRate)).floor()}s',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: MyBigGraphV2(
                                        showLeftConsole: false,
                                        showXAxisLabels: false,
                                        showYAxisLabels: false,
                                        key: _aiDetailGraphKey,
                                        isImported: true,
                                        onCycleComplete: () {},
                                        streamConfig: const [],
                                        onStreamResult: (_) {},
                                        plot: [
                                          {
                                            "name": "ECG (30 s)",
                                            "boxValue": 4096 / 12,
                                            "unit": "mV",
                                            "minDisplay": -(4096 / 12) * 3,
                                            "maxDisplay": (4096 / 12) * 3,
                                            "scale": 3,
                                            "gain": 1.0,
                                            "filterConfig": {
                                              "filterOn": false,
                                              "lpf": 3,
                                              "hpf": 5,
                                              "notch": 1,
                                            },
                                            "meter": {
                                              "decimal": 1,
                                              "unit": "mV",
                                              "convert": null,
                                            },
                                          },
                                        ],
                                        // match data length so full 30s is visible
                                        windowSize: _detailMinuteData.length,
                                        enableHorizontalScroll: false,
                                        pixelsPerSample: 0.5,
                                        verticalLineConfigs: const [
                                          {
                                            'seconds': 0.25,
                                            'stroke': 0.5,
                                            'color': Color(0xFF448AFF),
                                          },
                                          {
                                            'seconds': 0.5,
                                            'stroke': 0.5,
                                            'color': Color(0xFF448AFF),
                                          },
                                          {
                                            'seconds': 1.0,
                                            'stroke': 0.8,
                                            'color': Color(0xFFE53935),
                                          },
                                        ],
                                        horizontalInterval: 4096 / 12,
                                        verticalInterval: 8,
                                        samplingRate: 300,
                                        minY: -(4096 / 12) * 5,
                                        maxY: (4096 / 12) * 25,
                                        chartHeight: 280,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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

  Widget _buildConditionCard(BuildContext context, dynamic cond) {
    final String name =
        cond['name']?.toString() ??
        cond['classification']?.toString() ??
        'Unknown';
    // Occurrence centers (sample indices)
    final List<int> indices = () {
      if (cond['index'] is List) {
        return (cond['index'] as List).map((e) => (e as num).toInt()).toList();
      }
      // Fallback from AI segment shape
      final s = (cond['start'] as num?)?.toInt();
      final e = (cond['end'] as num?)?.toInt();
      if (s != null && e != null) return [((s + e) / 2).round()];
      return <int>[];
    }();

    final int count = indices.length;
    final int cursor = _cursorByCondition[name] ?? 0;
    final int safeCursor = count > 0 ? (cursor.clamp(0, count - 1)) : 0;

    final double cardWidth = 420;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                count > 0 ? 'Occurrences: $count' : 'Occurrences: --',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    (count == 0)
                        ? const Center(child: Text('No sample available'))
                        : FutureBuilder<List<double>>(
                          future: _loadPreviewSegment(
                            name: name,
                            centerSample: indices[safeCursor],
                          ),
                          builder: (_, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            final data = snap.data ?? const <double>[];
                            if (data.isEmpty) {
                              return const Center(
                                child: Text('Preview unavailable'),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap:
                                    () => _openDetailAroundSegment(
                                      centerSample: indices[safeCursor],
                                    ),
                                child: CustomPaint(
                                  painter: _EcgSparklinePainter(data),
                                  size: Size(double.infinity, double.infinity),
                                ),
                              ),
                            );
                          },
                        ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    count == 0 ? '—' : 'Sample ${safeCursor + 1} / $count',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous segment',
                        onPressed:
                            count <= 1
                                ? null
                                : () {
                                  final next = (safeCursor - 1 + count) % count;
                                  setState(() {
                                    _cursorByCondition[name] = next;
                                  });
                                },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next segment',
                        onPressed:
                            count <= 1
                                ? null
                                : () {
                                  final next = (safeCursor + 1) % count;
                                  setState(() {
                                    _cursorByCondition[name] = next;
                                  });
                                },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<double>> _loadPreviewSegment({
    required String name,
    required int centerSample,
  }) async {
    final holter = widget.holter;
    final int fs = holter.sampleRate; // typically 300 Hz
    // 3.0s window around center
    final int half = (1.5 * fs).round();
    final int start = (centerSample - half).clamp(0, 1 << 30);
    final int length = (half * 2);
    final key = '$name@$centerSample:$length';
    final cached = _previewCache[key];
    if (cached != null) return cached;
    try {
      final samples = await holter.getEcgSamples(
        start,
        length,
        // keep original sampling rate for preview (no downsampling)
      );
      _previewCache[key] = samples;
      return samples;
    } catch (_) {
      return <double>[];
    }
  }

  Future<void> _openDetailAroundSegment({required int centerSample}) async {
    final holter = widget.holter;
    final int fs = holter.sampleRate; // e.g., 300 Hz
    final int half = 15 * fs; // 15s on each side (total 30s)
    int start = centerSample - half;
    if (start < 0) start = 0;
    int length = 30 * fs;
    // Clamp length if near end of file
    final total = await holter.getTotalEcgSamples();
    if (start + length > total) {
      length = (total - start).clamp(0, length);
    }
    if (length <= 0) return;
    try {
      final data = await holter.getEcgSamples(start, length);
      if (!mounted) return;
      setState(() {
        _detailCenterSample = centerSample;
        _detailMinuteData = data;
      });
      // render after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _aiDetailGraphKey.currentState?.renderMultiRowPage([_detailMinuteData]);
      });
    } catch (_) {
      // ignore failures silently for now
    }
  }
}

class _EcgSparklinePainter extends CustomPainter {
  final List<double> data;
  _EcgSparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final bg =
        Paint()
          ..color = const Color(0xFFFDFDFD)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      bg,
    );

    // light grid
    final grid =
        Paint()
          ..color = const Color(0xFFEFEFEF)
          ..strokeWidth = 1.0;
    const gridStep = 20.0;
    for (double x = 0; x <= size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (data.isEmpty) return;

    // normalize data into 10%..90% vertical band
    double minV = data.first, maxV = data.first;
    for (final v in data) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final double pad = 0.1;
    final y0 = size.height * pad;
    final y1 = size.height * (1 - pad);
    final double range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    final path = Path();
    final n = data.length;
    for (int i = 0; i < n; i++) {
      final x = size.width * (i / (n - 1));
      final v = data[i];
      final y = y1 - ((v - minV) / range) * (y1 - y0);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final stroke =
        Paint()
          ..color = const Color(0xFF3A6FF7)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _EcgSparklinePainter oldDelegate) {
    return !identical(oldDelegate.data, data);
  }
}
