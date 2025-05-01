import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyBigGraph extends StatefulWidget {
  final dynamic plot;
  final int windowSize;
  final List<Map<String, dynamic>> verticalLineConfigs;
  final double horizontalInterval;
  final double verticalInterval;
  final double samplingRate;
  final double minY; // NEW ✅
  final double maxY; // NEW ✅

  const MyBigGraph({
    super.key,
    required this.plot,
    required this.windowSize,
    required this.verticalLineConfigs,
    required this.horizontalInterval,
    required this.verticalInterval,
    required this.samplingRate,
    required this.minY, // NEW ✅
    required this.maxY, // NEW ✅
  });

  @override
  State<MyBigGraph> createState() => MyBigGraphState();
}

class MyBigGraphState extends State<MyBigGraph> {
  late List<List<FlSpot>> allPlotData;
  late List<int> allCurrentIndexes;
  late List<dynamic> plotScales; // ✅ This line
  late List<dynamic> plotThresholds;
  late List<double> plotOffsets; // ✅ New
  late List<dynamic> plotGains;

  @override
  void initState() {
    super.initState();

    allPlotData = List.generate(widget.plot.length, (_) => []);
    allCurrentIndexes = List.generate(widget.plot.length, (_) => 0);

    plotScales =
        widget.plot.map((e) {
          final scaleBoxes = (e["scale"] ?? 5);
          double scaleValue =
              (scaleBoxes is int || scaleBoxes is double)
                  ? scaleBoxes.toDouble()
                  : 5.0;
          return (4096 / 12) * scaleValue; // total Y range for this channel
        }).toList();

    plotThresholds =
        widget.plot.map((e) => (e["threshold"] ?? 1000.0) as double).toList();

    // ✅ New: Gain
    plotGains =
        widget.plot.map((e) {
          final gainValue = (e["gain"] ?? 1.0);
          return (gainValue is int || gainValue is double)
              ? gainValue.toDouble()
              : 1.0;
        }).toList();

    plotOffsets = List.generate(widget.plot.length, (_) => 0.0);

    plotThresholds =
        widget.plot.map((e) => (e["threshold"] ?? 1000.0) as double).toList();

    for (int i = 0; i < widget.plot.length; i++) {
      allPlotData[i] = List.generate(
        widget.windowSize,
        (index) => FlSpot(index.toDouble(), 0),
      );
    }
  }

  void updateEverything(List<double> values) {
    setState(() {
      for (int i = 0; i < values.length; i++) {
        if (allCurrentIndexes[i] >= widget.windowSize) {
          allCurrentIndexes[i] = 0;
        }

        double value = values[i];

        // ❌ NO CLIPPING HERE!
        allPlotData[i][allCurrentIndexes[i]] = FlSpot(
          allCurrentIndexes[i].toDouble(),
          value,
        );
        allCurrentIndexes[i]++;
      }
    });
  }

  List<VerticalLine> _generateVerticalLines() {
    List<VerticalLine> allLines = [];

    for (var config in widget.verticalLineConfigs) {
      double seconds = config['seconds'] ?? 0.0;
      double stroke = config['stroke'] ?? 0.5;
      double xInterval = seconds * widget.samplingRate;
      Color color = config['color'] ?? Colors.red; // NEW: get color from config

      if (xInterval > 0) {
        for (double x = 0; x <= widget.windowSize.toDouble(); x += xInterval) {
          allLines.add(
            VerticalLine(
              x: x,
              color: color, // NEW: use config color
              strokeWidth: stroke,
            ),
          );
        }
      }
    }

    return allLines;
  }

  List<HorizontalLine> _generateSeparationLines() {
    List<HorizontalLine> lines = [];

    double totalHeight = widget.maxY - widget.minY;
    double plotSpacing = totalHeight / widget.plot.length;

    for (int i = 0; i < widget.plot.length; i++) {
      double channelTop = widget.maxY - plotSpacing * i;
      double channelBottom = widget.maxY - plotSpacing * (i + 1);
      double channelCenter = (channelTop + channelBottom) / 2;

      double pixelPerVolt = plotSpacing / (widget.plot[i]["scale"] ?? 5);

      // ➡ Create lines at every 0.5V step
      int numberOfLines =
          ((widget.plot[i]["scale"] ?? 5) * 2); // 2 lines per volt (500mV each)

      for (int j = -numberOfLines ~/ 2; j <= numberOfLines ~/ 2; j++) {
        double y = channelCenter - (j * pixelPerVolt * 0.5);

        if (y <= channelTop && y >= channelBottom) {
          lines.add(
            HorizontalLine(
              y: y,
              color: Colors.grey.shade600,
              strokeWidth: (j == 0) ? 0.6 : 0.3, // Make center 0V line darker
            ),
          );
        }
      }

      // Solid black separation line between channels
      if (i != 0) {
        lines.add(
          HorizontalLine(y: channelTop, color: Colors.black, strokeWidth: 0.8),
        );
      }
    }

    return lines;
  }

  String _getLiveValueLabel(int index) {
    if (allPlotData[index].isEmpty) return "--";

    final latestPoint = allPlotData[index][(allCurrentIndexes[index] - 1) % widget.windowSize];

    double raw = latestPoint.y;
    double scaled = raw * plotGains[index];
    double offsetAdjusted = scaled + plotOffsets[index];

    // Apply unit conversion if available
    var meter = widget.plot[index]["meter"];
    double displayValue = offsetAdjusted;

    if (meter != null && meter["convert"] != null && meter["convert"] is Function) {
      try {
        displayValue = meter["convert"](scaled); // Optional: use raw or scaled here
      } catch (_) {
        displayValue = scaled;
      }
    }

    String unit = meter != null && meter["unit"] != null ? meter["unit"].toString() : "";

    return "${displayValue.toStringAsFixed(2)} $unit";
  }


  Widget _leftConsole() {
    double totalHeight = (320 / 12) * 30;
    double sectionHeight = totalHeight / widget.plot.length;

    return Container(
      width: 120, // ⬅️ Increased width a little for buttons
      color: Colors.white,
      child: Column(
        children: List.generate(widget.plot.length, (i) {
          return Container(
            height: sectionHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    i != widget.plot.length - 1
                        ? BorderSide(color: Colors.grey.shade400, width: 0.5)
                        : BorderSide.none,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.plot[i]["name"] ?? "Channel ${i + 1}",
                            // 🧠 Show Channel Name
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _adjustScale(i, increase: true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _adjustScale(i, increase: false),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.center_focus_strong,
                                size: 16,
                              ),
                              // ✅ Auto-center icon
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _autoCenterOffset(i),
                              // ✅ NEW FUNCTION
                              tooltip: "Auto-Center",
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _adjustOffset(i, up: true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _adjustOffset(i, up: false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                _meter(i),
              ],
            ),
          );
        }),
      ),
    );
  }

  _meter(i){
    if(widget.plot[i]["meter"] == null){
      return Container();
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.plot[i]["name"] ?? "Channel ${i + 1}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _getLiveValueLabel(i), // 🔥 This shows the dynamic label
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ],
      ),
    );
  }


  void _adjustScale(int index, {required bool increase}) {
    setState(() {
      double changeFactor = (4096 / 12) * 0.5; // half box change per click

      if (increase) {
        plotScales[index] -= changeFactor; // ✅ Decrease scale to magnify
        if (plotScales[index] < changeFactor) {
          plotScales[index] = changeFactor; // Avoid negative/zero scale
        }
      } else {
        plotScales[index] += changeFactor; // ✅ Increase scale to compress
      }
    });
  }

  void _autoCenterOffset(int index) {
    final plot = allPlotData[index];
    if (plot.isEmpty) return;

    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (final spot in plot) {
      final val = spot.y * plotGains[index];
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }

    final midVal = (maxVal + minVal) / 2;

    double totalHeight = widget.maxY - widget.minY;
    double plotSpacing = totalHeight / widget.plot.length;
    double verticalCenter = widget.maxY - plotSpacing * (index + 0.5);

    double normalizedY = (midVal / plotScales[index]) * (plotSpacing / 2);
    double newOffset = verticalCenter - (verticalCenter + normalizedY);

    setState(() {
      plotOffsets[index] = newOffset;
    });
  }

  void _adjustOffset(int index, {required bool up}) {
    setState(() {
      double moveFactor = (4096 / 12) * 0.5; // Same movement as 0.5 box
      if (up) {
        plotOffsets[index] += moveFactor;
      } else {
        plotOffsets[index] -= moveFactor;
      }
    });
  }

  Widget _buildYAxisLabelSynced(double value) {
    double totalHeight = widget.maxY - widget.minY;
    double plotSpacing = totalHeight / widget.plot.length;

    // Find which channel section this value belongs to
    int sectionIndex = ((widget.maxY - value) / plotSpacing).floor();

    if (sectionIndex < 0 || sectionIndex >= widget.plot.length) {
      return const SizedBox.shrink(); // Out of range
    }

    // Center line of this channel
    double sectionTop = widget.maxY - plotSpacing * sectionIndex;
    double sectionBottom = widget.maxY - plotSpacing * (sectionIndex + 1);
    double sectionCenter = (sectionTop + sectionBottom) / 2;

    // Each full box is 1V
    double pixelPerBox =
        plotSpacing / (widget.plot[sectionIndex]["scale"] ?? 5);

    // Calculate how far this value is from center
    double offsetFromCenter = value - sectionCenter;
    double volts = -offsetFromCenter / pixelPerBox; // volt per box

    // Check if this is exactly 0.5V step
    double roundedVolts = (volts * 2).round() / 2.0;

    // Allow tiny floating-point error margin
    if ((volts - roundedVolts).abs() > 0.01) {
      return const SizedBox.shrink();
    }

    String label =
        '${roundedVolts >= 0 ? '+' : ''}${roundedVolts.toStringAsFixed(1)} V';

    return Text(
      label,
      style: const TextStyle(color: Colors.black, fontSize: 10),
      textAlign: TextAlign.right,
    );
  }

  Widget _chart() {
    return Container(
      // padding: const EdgeInsets.all(5),
      height: (320 / 12) * 30,
      child: LineChart(
        duration: const Duration(milliseconds: 0),
        LineChartData(
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40, // enough space for labels
                getTitlesWidget: (value, meta) {
                  return _buildYAxisLabelSynced(value);
                },
                interval:
                    (widget.maxY - widget.minY) /
                    (widget.plot.length * 4), // 🔥 interval dynamically
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.blue.shade500, width: 0.6),
          ),
          clipData: FlClipData.all(),
          gridData: FlGridData(
            show: false,
            drawHorizontalLine: true,
            drawVerticalLine: true,
            horizontalInterval: widget.horizontalInterval,
            verticalInterval: widget.verticalInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.blue.shade200, strokeWidth: 0.2);
            },
            getDrawingVerticalLine: (value) {
              if (value % (widget.samplingRate * 1.0) == 0) {
                return FlLine(color: Colors.blue.shade600, strokeWidth: 0.6);
              } else if (value % (widget.samplingRate * 0.2) == 0) {
                return FlLine(color: Colors.blue.shade200, strokeWidth: 0.2);
              } else {
                return FlLine(color: Colors.transparent, strokeWidth: 0);
              }
            },
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: _generateVerticalLines(),
            horizontalLines:
                _generateSeparationLines(), // ✅ New separation lines
          ),
          minX: 0,
          maxX: widget.windowSize.toDouble(),
          minY: widget.minY,
          maxY: widget.maxY,
          lineBarsData: List.generate(widget.plot.length, (i) {
            double totalHeight = widget.maxY - widget.minY;
            double plotSpacing = totalHeight / widget.plot.length;
            double verticalCenter =
                widget.maxY - plotSpacing * (i + 0.5); // ✅ Corrected

            return LineChartBarData(
              spots:
                  allPlotData[i]
                      .map((spot) {
                        double totalHeight = widget.maxY - widget.minY;
                        double plotSpacing = totalHeight / widget.plot.length;
                        double verticalCenter =
                            widget.maxY - plotSpacing * (i + 0.5);

                        // Channel boundaries
                        double channelMaxY = widget.maxY - plotSpacing * i;
                        double channelMinY =
                            widget.maxY - plotSpacing * (i + 1);

                        double normalizedY =
                            ((spot.y * plotGains[i]) / plotScales[i]) *
                            (plotSpacing / 2);

                        // Apply offset
                        double shiftedY =
                            verticalCenter + normalizedY + plotOffsets[i];

                        // 💥 If shiftedY is outside the channel, discard point
                        if (shiftedY > channelMaxY || shiftedY < channelMinY) {
                          return null; // ✅ Ignore this point
                        }

                        return FlSpot(spot.x, shiftedY);
                      })
                      .whereType<FlSpot>()
                      .toList(),

              // ✅ Important: remove nulls
              isCurved: false,
              color: Colors.black,
              barWidth: 1.5,
              dotData: FlDotData(show: false),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _leftConsole(),
        Expanded(child: _chart()), // your big graph here
      ],
    );
  }
}
