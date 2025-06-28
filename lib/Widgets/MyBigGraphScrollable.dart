import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:spirobtvo/Services/FilterClass.dart';
import 'package:spirobtvo/Services/MultiFilter.dart';

class MyBigGraphV2 extends StatefulWidget {
  final dynamic plot;
  final int windowSize;
  final List<Map<String, dynamic>> verticalLineConfigs;
  final double horizontalInterval;
  final double verticalInterval;
  final double samplingRate;
  final double minY; // NEW ✅
  final double maxY; // NEW ✅
  final List<Map<String, dynamic>> streamConfig;
  final void Function(Map<String, dynamic>)? onStreamResult;
  final void Function()? onCycleComplete;
  final bool isImported; // ✅ new

  const MyBigGraphV2({
    super.key,
    required this.plot,
    required this.windowSize,
    required this.verticalLineConfigs,
    required this.horizontalInterval,
    required this.verticalInterval,
    required this.samplingRate,
    required this.minY, // NEW ✅
    required this.maxY, // NEW ✅
    required this.streamConfig,
    this.onStreamResult, // ✅ new
    this.onCycleComplete,
    required this.isImported, // ✅ new
  });

  @override
  State<MyBigGraphV2> createState() => MyBigGraphV2State();
}

class MyBigGraphV2State extends State<MyBigGraphV2> {
  late List<List<FlSpot>> allPlotData;
  late List<int> allCurrentIndexes;
  late List<dynamic> plotScales; // ✅ This line
  late List<dynamic> plotThresholds;
  late List<double> plotOffsets; // ✅ New
  late List<dynamic> plotGains;
  late MultiFilter multiFilter = MultiFilter();
  int FILT_BUF_SIZE = 3 * 6 + 7;
  int Pos = 0; // Circular buffer position tracker
  late List<List<double>> filterBuffs;
  late Stream<dynamic> stream;
  bool _clearedForImport = false;

  void streamHandler(List<double> values) {
    Map<String, dynamic> resultMap = {};

    for (var map in widget.streamConfig) {
      map.forEach((key, config) {
        if (config["fun"] != null && config["fun"] is Function) {
          try {
            var result = config["fun"](values);
            resultMap[key] = result;
          } catch (e) {
            debugPrint("Stream function error on [$key]: $e");
          }
        }
      });
    }

    if (resultMap.isNotEmpty && widget.onStreamResult != null) {
      widget.onStreamResult!(resultMap); // ✅ Send to parent
    }
  }

  @override
  void initState() {
    super.initState();
    filterBuffs = List.generate(
      widget.plot.length,
      (_) => List<double>.filled(FILT_BUF_SIZE, 0.0),
    );
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
    _refreshMultiFilter();
  }

  void _refreshMultiFilter() {
    List<Map<String, dynamic>> config = [];

    for (int i = 0; i < widget.plot.length; i++) {
      if (widget.plot[i]["filterConfig"] == null) {
        widget.plot[i]["filterConfig"] = {
          "filterOn": false,
          "lpf": 3,
          "hpf": 5,
          "notch": 1,
        };
      }

      config.add(widget.plot[i]["filterConfig"]);
    }

    multiFilter.init(config);
  }

  double applyMultiFilterToChannel(int channelIndex, double val) {
    final filterSettings = widget.plot[channelIndex]["filterConfig"];
    if (filterSettings == null || filterSettings["filterOn"] != true) {
      return val; // No filtering if disabled
    }

    const int StartStageCNo = 0;
    const int MAX_STAGES_MINUS_ONE = FilterClass.MAX_STAGES - 1;

    // Init filter buffers if needed
    if (filterBuffs.isEmpty ||
        filterBuffs.length != multiFilter.filters.length) {
      filterBuffs = List.generate(
        multiFilter.filters.length,
        (_) => List<double>.filled(FILT_BUF_SIZE, 0.0),
      );
    }

    FilterClass currentFilter = multiFilter.getFilter(channelIndex);
    List<double> currentBuffer = filterBuffs[channelIndex];

    double localSum = 0;
    int localPos = Pos;

    currentBuffer[localPos] = val;

    for (int stage = StartStageCNo; stage <= MAX_STAGES_MINUS_ONE; stage++) {
      localSum = 0;
      for (int c = 0; c < 5; c++) {
        int index = (localPos + FILT_BUF_SIZE - c) % FILT_BUF_SIZE;
        localSum += currentBuffer[index] * currentFilter.Coeff[stage][c];
      }

      localSum *= 2;
      currentBuffer[(localPos + 1) % FILT_BUF_SIZE] = localSum;
      currentBuffer[(localPos + 6) % FILT_BUF_SIZE] = localSum;

      localPos = (localPos + 6) % FILT_BUF_SIZE;
    }

    Pos = (Pos + 2) % FILT_BUF_SIZE;

    return localSum;
  }

  List<double> updateEverything(List<double> values) {
    List<double> processedValues = [];

    setState(() {
      for (int i = 0; i < values.length; i++) {
        streamHandler(values); // 🔁 You may want this once per full sample set

        double value = values[i];
        value = applyMultiFilterToChannel(i, value);
        processedValues.add(value);

        if (widget.isImported) {
          if (!_clearedForImport) {
            for (var list in allPlotData) {
              list.clear();
            }
            _clearedForImport = true;
            print(
              "🧹 Cleared previous data for all channels in imported mode.",
            );
          }

          // print("Imported value for channel $i: $value");
          // ✅ Append in scrollable mode
          double x =
              allPlotData[i].isNotEmpty ? allPlotData[i].last.x + 1 : 0.0;
          // print("Appending value $value at x=$x for channel $i");
          allPlotData[i].add(FlSpot(x, value));
        } else {
          // 🔄 Cyclic mode
          if (allCurrentIndexes[i] >= widget.windowSize) {
            widget.onCycleComplete?.call();
            allCurrentIndexes[i] = 0;
          }

          allPlotData[i][allCurrentIndexes[i]] = FlSpot(
            allCurrentIndexes[i].toDouble(),
            value,
          );
          allCurrentIndexes[i]++;
        }
      }
    });

    return processedValues;
  }

  List<VerticalLine> _generateVerticalLines() {
    List<VerticalLine> allLines = [];

    // ✅ Dynamic max X: depends on mode
    double maxX =
        widget.isImported
            ? (allPlotData.isNotEmpty && allPlotData[0].isNotEmpty
                ? allPlotData[0].last.x
                : widget.windowSize.toDouble())
            : widget.windowSize.toDouble();

    for (var config in widget.verticalLineConfigs) {
      double seconds = config['seconds'] ?? 0.0;
      double stroke = config['stroke'] ?? 0.5;
      double xInterval = seconds * widget.samplingRate;
      Color color = config['color'] ?? Colors.red;

      if (xInterval > 0) {
        for (double x = 0; x <= maxX; x += xInterval) {
          allLines.add(VerticalLine(x: x, color: color, strokeWidth: stroke));
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
              color: Colors.blue.shade500,
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

    final latestPoint =
        allPlotData[index][(allCurrentIndexes[index] - 1) % widget.windowSize];

    double raw = latestPoint.y;
    double scaled = raw * plotGains[index];
    double offsetAdjusted = scaled + plotOffsets[index];

    // Apply unit conversion if available
    var meter = widget.plot[index]["meter"];
    double displayValue = offsetAdjusted;

    if (meter != null &&
        meter["convert"] != null &&
        meter["convert"] is Function) {
      try {
        displayValue = meter["convert"](
          scaled,
        ); // Optional: use raw or scaled here
      } catch (_) {
        displayValue = scaled;
      }
    }

    String unit =
        meter != null && meter["unit"] != null ? meter["unit"].toString() : "";
    if (meter["decimal"] != null) {
      return "${displayValue.toStringAsFixed(meter["decimal"])} $unit";
    } else {
      return "${displayValue.toStringAsFixed(2)} $unit";
    }
  }

  Widget _leftConsole() {
    double totalHeight = (250 / 12) * 35;
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
                IconButton(
                  icon: const Icon(Icons.filter_alt, size: 16),
                  tooltip: "Set Filters",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _openFilterDialog(i),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _openFilterDialog(int index) {
    final filter = FilterClass();

    final config = Map<String, dynamic>.from(
      widget.plot[index]["filterConfig"] ??
          {
            "filterOn": true,
            "lpf": 3, // default: 35Hz
            "hpf": 5, // default: 0.6Hz
            "notch": 1,
          },
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filters', textAlign: TextAlign.center),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text("Filter"),
                    value: config["filterOn"] ?? true,
                    onChanged:
                        (val) => setState(() => config["filterOn"] = val),
                    activeColor: Colors.deepPurple,
                  ),
                  if (config["filterOn"] == true) ...[
                    const SizedBox(height: 8),
                    const Text("Low Pass"),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: config["lpf"],
                      items: List.generate(filter.mLPFCaptions.length, (i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(filter.mLPFCaptions[i]),
                        );
                      }),
                      onChanged:
                          (val) => setState(() => config["lpf"] = val ?? 0),
                    ),
                    const SizedBox(height: 8),
                    const Text("High Pass"),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: config["hpf"],
                      items: List.generate(filter.mHPFCaptions.length, (i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(filter.mHPFCaptions[i]),
                        );
                      }),
                      onChanged:
                          (val) => setState(() => config["hpf"] = val ?? 0),
                    ),
                    SwitchListTile(
                      title: const Text("Notch"),
                      value: config["notch"] == 1,
                      onChanged:
                          (val) =>
                              setState(() => config["notch"] = val ? 1 : 0),
                      activeColor: Colors.deepPurple,
                    ),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.plot[index]["filterConfig"] = config;
                  _refreshMultiFilter();
                });
                print(widget.plot);
                Navigator.pop(context);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Widget _filterDropdown(
    String label,
    Map config,
    String key,
    List<dynamic> options,
  ) {
    return DropdownButtonFormField(
      decoration: InputDecoration(labelText: label),
      value: config[key],
      items:
          options.map<DropdownMenuItem>((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option.toString()),
            );
          }).toList(),
      onChanged: (val) => config[key] = val,
    );
  }

  Widget _filterDropdownWithCaptions(
    String label,
    Map config,
    String key,
    List<String> captions,
  ) {
    return DropdownButtonFormField(
      decoration: InputDecoration(labelText: label),
      value: config[key],
      items: List.generate(captions.length, (i) {
        return DropdownMenuItem(value: i, child: Text(captions[i]));
      }),
      onChanged: (val) => config[key] = val,
    );
  }

  Widget _filterTextField(String label, Map config, String key) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      initialValue: config[key].toString(),
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        double? parsed = double.tryParse(val);
        if (parsed != null) config[key] = parsed;
      },
    );
  }

  _meter(i) {
    if (widget.plot[i]["meter"] == null) {
      return Container();
    }

    final name = widget.plot[i]["name"] ?? "Channel ${i + 1}";
    final liveValue = _getLiveValueLabel(i);

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            AutoSizeText(
              liveValue,
              maxLines: 1,
              minFontSize: 14,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _adjustScale(int index, {required bool increase}) {
    setState(() {
      double factor = 1.2; // 20% zoom per click
      if (increase) {
        plotScales[index] /= factor; // zoom in (magnify)
      } else {
        plotScales[index] *= factor; // zoom out (compress)
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
      height: (250 / 12) * 35,
      child: LineChart(
        duration: const Duration(milliseconds: 0),
        key: ValueKey(allPlotData[0].last.x), // ✅ forces rebuild
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: false, // disables all touch
            touchTooltipData: LineTouchTooltipData(
              // tooltipBgColor: Colors.transparent,
              tooltipRoundedRadius: 0,
              getTooltipItems: (_) => [],
            ),
            handleBuiltInTouches: false,
          ),
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
              return FlLine(color: Colors.blue.shade500, strokeWidth: 0.2);
            },
            getDrawingVerticalLine: (value) {
              if (value % (widget.samplingRate * 1.0) == 0) {
                return FlLine(color: Colors.blue.shade500, strokeWidth: 0.2);
              } else if (value % (widget.samplingRate * 0.2) == 0) {
                return FlLine(color: Colors.blue.shade500, strokeWidth: 0.2);
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
          maxX:
              widget.isImported
                  ? (allPlotData.isNotEmpty && allPlotData[0].isNotEmpty
                      ? allPlotData[0].last.x
                      : widget.windowSize.toDouble())
                  : widget.windowSize.toDouble(),
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

  double pixelsPerSample = 1; // ✅ Tune this as needed
  ScrollController _scrollController = ScrollController(); // At state level

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _leftConsole(),
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _scrollController.jumpTo(
                  _scrollController.offset + event.scrollDelta.dy,
                );
              }
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width:
                      widget.isImported
                          ? ((allPlotData.isNotEmpty &&
                                  allPlotData[0].isNotEmpty)
                              ? allPlotData[0].last.x * 0.4
                              : widget.windowSize.toDouble())
                          : widget.windowSize.toDouble() * 0.5,
                  child: _chart(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
