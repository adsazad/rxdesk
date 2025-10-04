import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:holtersync/Services/EcgBPMCalculator.dart';
import 'package:holtersync/Services/FFTProcessor.dart';
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

  // Frequency-domain (FFT/PSD) state
  bool _fftReady = false;
  double vlfPower = 0, lfPower = 0, hfPower = 0;
  double vlfPct = 0, lfPct = 0, hfPct = 0;
  double lfHfRatio = 0, lfNu = 0, hfNu = 0;

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

    // Frequency domain: compute PSD + band powers
    try {
      if (rr.length < 8) {
        // Not enough RR intervals for a meaningful PSD
        _fftReady = false;
      } else {
        final fft = FFTProcessor();
        // meanRR is in seconds; FFTProcessor expects RRMean in seconds (converts inside)
        // init is async, returns a map of results
        fft.init(rr, meanRR).then((res) {
          if (res is Map) {
            setState(() {
              vlfPower = (res['vlfPower'] as num).toDouble();
              lfPower = (res['lfPower'] as num).toDouble();
              hfPower = (res['hfPower'] as num).toDouble();
              vlfPct = (res['vlfPercentage'] as num).toDouble();
              lfPct = (res['lfPercentage'] as num).toDouble();
              hfPct = (res['hfPercentage'] as num).toDouble();
              lfHfRatio = (res['lfHfRatio'] as num).toDouble();
              lfNu = (res['lfNu'] as num).toDouble();
              hfNu = (res['hfNu'] as num).toDouble();
              _fftReady = true;
            });
          }
        });
      }
    } catch (_) {
      // Ignore FFT failures silently for now
    }
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

  // Removed _statTile: metrics are now shown in tables

  Widget _rrSeriesChart() {
    if (rr.isEmpty) return const SizedBox.shrink();
    final spots =
        rr
            .asMap()
            .entries
            .map((e) => FlSpot(e.key.toDouble(), (e.value * 1000)))
            .toList();
    // Clamp Y-axis to "normal" HR range to avoid long pauses shrinking detail
    // Normal HR range assumed 40–180 bpm => RR range ~1500ms to ~333ms
    const double hrMin = 40.0; // bpm
    const double hrMax = 180.0; // bpm
    final double rrMsMin = 60000.0 / hrMax; // ~333ms
    final double rrMsMax = 60000.0 / hrMin; // ~1500ms

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.isNotEmpty) ? spots.length.toDouble() - 1 : 1,
          minY: rrMsMin,
          maxY: rrMsMax,
          clipData: const FlClipData(
            left: true,
            top: true,
            right: true,
            bottom: true,
          ),
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
      spots.add(
        ScatterSpot(
          xs[i] * 1000,
          ys[i] * 1000,
          dotPainter: FlDotCirclePainter(
            radius: 2,
            color: Colors.red,
            strokeColor: Colors.red,
            strokeWidth: 0,
          ),
        ),
      );
    }
    // Clamp axes to normal HR-derived RR range (ms) like the tachogram
    const double hrMin = 40.0; // bpm
    const double hrMax = 180.0; // bpm
    final double rrMsMin = 60000.0 / hrMax; // ~333ms
    final double rrMsMax = 60000.0 / hrMin; // ~1500ms
    return SizedBox(
      height: 240,
      child: ScatterChart(
        ScatterChartData(
          minX: rrMsMin,
          maxX: rrMsMax,
          minY: rrMsMin,
          maxY: rrMsMax,
          clipData: const FlClipData(
            left: true,
            top: true,
            right: true,
            bottom: true,
          ),
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

  // PSD chart intentionally removed per request – metrics only
  Widget _timeMetricsDataTable() {
    final numericStyle = const TextStyle(
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return DataTable(
      headingRowHeight: 36,
      columns: const [
        DataColumn(label: Text('Metric')),
        DataColumn(label: Text('Value'), numeric: true),
      ],
      rows: [
        DataRow(
          cells: [
            const DataCell(Text('Avg BPM')),
            DataCell(Text(bpmAvg.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('Min BPM')),
            DataCell(Text(bpmMin.toStringAsFixed(0), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('Max BPM')),
            DataCell(Text(bpmMax.toStringAsFixed(0), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('Mean RR (ms)')),
            DataCell(
              Text((meanRR * 1000).toStringAsFixed(0), style: numericStyle),
            ),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('SDNN (ms)')),
            DataCell(
              Text((stdRR * 1000).toStringAsFixed(0), style: numericStyle),
            ),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('RMSSD (ms)')),
            DataCell(Text(rmssd.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('pNN50 (%)')),
            DataCell(
              Text(nn50['pnn50']!.toStringAsFixed(1), style: numericStyle),
            ),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('RR Triangular Index')),
            DataCell(Text(rrti.toStringAsFixed(2), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('SD1 (ms)')),
            DataCell(Text(sd1.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('SD2 (ms)')),
            DataCell(Text(sd2.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('Stress Index')),
            DataCell(Text(stressIndex.toStringAsFixed(0), style: numericStyle)),
          ],
        ),
      ],
    );
  }

  Widget _freqMetricsDataTable() {
    final numericStyle = const TextStyle(
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return DataTable(
      headingRowHeight: 36,
      columns: const [
        DataColumn(label: Text('Metric')),
        DataColumn(label: Text('Value'), numeric: true),
      ],
      rows: [
        DataRow(
          cells: [
            const DataCell(Text('VLF power')),
            DataCell(Text(vlfPower.toStringAsFixed(2), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('LF power')),
            DataCell(Text(lfPower.toStringAsFixed(2), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('HF power')),
            DataCell(Text(hfPower.toStringAsFixed(2), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('VLF %')),
            DataCell(Text(vlfPct.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('LF %')),
            DataCell(Text(lfPct.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('HF %')),
            DataCell(Text(hfPct.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('LF/HF')),
            DataCell(Text(lfHfRatio.toStringAsFixed(2), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('LFnu')),
            DataCell(Text(lfNu.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
        DataRow(
          cells: [
            const DataCell(Text('HFnu')),
            DataCell(Text(hfNu.toStringAsFixed(1), style: numericStyle)),
          ],
        ),
      ],
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
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'RR tachogram (ms)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Poincaré plot (ms vs ms)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _rrSeriesChart()),
                        const SizedBox(width: 12),
                        Expanded(child: _poincareChart()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Time-domain metrics',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: _timeMetricsDataTable(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Frequency-domain metrics',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _fftReady
                                      ? SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: _freqMetricsDataTable(),
                                      )
                                      : const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8.0,
                                        ),
                                        child: Text(
                                          'Not enough data for frequency analysis',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
