import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:holtersync/Services/EcgBPMCalculator.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HrvAnalysisTab extends StatefulWidget {
  final HolterReportGenerator holter;
  const HrvAnalysisTab({super.key, required this.holter});

  @override
  State<HrvAnalysisTab> createState() => _HrvAnalysisTabState();
}

class _HrvAnalysisTabState extends State<HrvAnalysisTab> {
  final EcgBPMCalculator _calc = EcgBPMCalculator();

  List<double> rr = [];
  Map<String, dynamic> poincare = const {"x": <double>[], "y": <double>[]};

  double bpmAvg = 0;
  double bpmMin = 0;
  double bpmMax = 0;
  double meanRR = 0;
  double stdRR = 0;
  double meanHR = 0;
  double stdHR = 0;
  double rmssd = 0;
  Map<String, double> nn50 = const {"nn50": 0, "pnn50": 0};
  double rrti = 0;
  double sd1 = 0;
  double sd2 = 0;
  double stressIndex = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    // Prefer prepared RR intervals from holter; otherwise derive from indexes
    rr =
        (widget.holter.allRrIntervals.isNotEmpty)
            ? widget.holter.allRrIntervals
            : _calc.convertRRIndexesToInterval(
              widget.holter.allRrIndexes,
              sampleRate: widget.holter.sampleRate,
            );
    print(rr);

    if (rr.isEmpty) return;

    bpmAvg = _calc.getAverageBPM(rr, sampleRate: widget.holter.sampleRate);
    bpmMax = _calc.getMaxBPM(rr);
    bpmMin = _calc.getMinBPM(rr);
    meanRR = _calc.getMeanRR(rr);
    stdRR = _calc.getSTDRR(rr);
    meanHR = _calc.getMeanHeartRate(rr);
    stdHR = _calc.getSTDHeartRate(rr);
    rmssd = _calc.getRMSSD(rr);
    final nn = _calc.getNN50(rr);
    nn50 = {
      "nn50": (nn["nn50"] as num).toDouble(),
      "pnn50": (nn["pnn50"] as num).toDouble(),
    };
    rrti = _calc.calculateRRTriangularIndex(rr);
    final pc = _calc.getPoincarePlotData(rr);
    poincare = {
      "x": List<double>.from(pc["x"]),
      "y": List<double>.from(pc["y"]),
    };
    final sd = _calc.calculateSD1SD2(poincare);
    sd1 = (sd["sd1"] as num).toDouble();
    sd2 = (sd["sd2"] as num).toDouble();
    stressIndex = _calc.calculateStressIndex(rr);
    setState(() {});
  }

  Future<void> _exportRrTxt() async {
    if (rr.isEmpty) return;
    // export in milliseconds, one per line
    final rrMs = rr.map((e) => (e * 1000).toStringAsFixed(0)).join("\n");
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/rr_intervals.txt');
    await file.writeAsString(rrMs);
    await Share.shareXFiles([XFile(file.path)], text: 'RR intervals (ms)');
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _rrSeriesChart() {
    if (rr.isEmpty) return const SizedBox.shrink();
    final spots =
        rr
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), (e.value * 1000)))
            .toList();
    final minY = (spots.map((e) => e.y).reduce((a, b) => a < b ? a : b));
    final maxY = (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b));
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.isNotEmpty) ? spots.length.toDouble() - 1 : 1,
          minY: minY * 0.95,
          maxY: maxY * 1.05,
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget:
                    (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: (spots.length / 6).clamp(1, 999).toDouble(),
                getTitlesWidget:
                    (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 1,
              color: Colors.blueGrey,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poincareChart() {
    final xs = (poincare["x"] as List).cast<double>();
    final ys = (poincare["y"] as List).cast<double>();
    if (xs.isEmpty || ys.isEmpty) return const SizedBox.shrink();
    final spots = <ScatterSpot>[];
    for (int i = 0; i < xs.length; i++) {
      spots.add(ScatterSpot(xs[i] * 1000, ys[i] * 1000));
    }
    final all = spots.map((e) => e.x).toList() + spots.map((e) => e.y).toList();
    final minVal = all.reduce((a, b) => a < b ? a : b) * 0.95;
    final maxVal = all.reduce((a, b) => a > b ? a : b) * 1.05;
    return SizedBox(
      height: 220,
      child: ScatterChart(
        ScatterChartData(
          minX: minVal,
          maxX: maxVal,
          minY: minVal,
          maxY: maxVal,
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget:
                    (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                getTitlesWidget:
                    (v, _) => Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          scatterSpots: spots,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = rr.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child:
          hasData
              ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _exportRrTxt,
                          icon: const Icon(Icons.sim_card_download),
                          label: const Text('Export RR (ms)'),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Samples: ${rr.length}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _statTile('Avg BPM', bpmAvg.toStringAsFixed(1)),
                        _statTile('Min BPM', bpmMin.toStringAsFixed(0)),
                        _statTile('Max BPM', bpmMax.toStringAsFixed(0)),
                        _statTile(
                          'Mean RR (ms)',
                          (meanRR * 1000).toStringAsFixed(0),
                        ),
                        _statTile(
                          'SDNN (ms)',
                          (stdRR * 1000).toStringAsFixed(0),
                        ),
                        _statTile('RMSSD', rmssd.toStringAsFixed(1)),
                        _statTile(
                          'pNN50 (%)',
                          nn50['pnn50']!.toStringAsFixed(1),
                        ),
                        _statTile(
                          'RR Triangular Index',
                          rrti.toStringAsFixed(2),
                        ),
                        _statTile('SD1 (ms)', sd1.toStringAsFixed(1)),
                        _statTile('SD2 (ms)', sd2.toStringAsFixed(1)),
                        _statTile(
                          "Stress Index",
                          stressIndex.toStringAsFixed(0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'RR series (ms)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _rrSeriesChart(),
                    const SizedBox(height: 12),
                    const Text(
                      'Poincaré plot (ms vs ms)',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    _poincareChart(),
                    const SizedBox(height: 24),
                    // Optional frequency domain section can be wired if FFT utilities are added.
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Frequency-domain (PSD, LF/HF) can be shown if you add your FFT utilities. See notes below.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(height: 6),
                    Text('Load a recording first to see HRV analysis'),
                  ],
                ),
              ),
    );
  }
}
