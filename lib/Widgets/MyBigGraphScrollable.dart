import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
  final double minY;
  final double maxY;
  final List<Map<String, dynamic>> streamConfig;
  final void Function(Map<String, dynamic>)? onStreamResult;
  final void Function()? onCycleComplete;
  final bool isImported;
  final ValueListenable<List<int>>?
  markerIndices; // NEW (global indices of peaks)

  const MyBigGraphV2({
    super.key,
    required this.plot,
    required this.windowSize,
    required this.verticalLineConfigs,
    required this.horizontalInterval,
    required this.verticalInterval,
    required this.samplingRate,
    required this.minY,
    required this.maxY,
    required this.streamConfig,
    required this.isImported,
    this.onStreamResult,
    this.onCycleComplete,
    this.markerIndices, // NEW
  });

  @override
  State<MyBigGraphV2> createState() => MyBigGraphV2State();
}

class MyBigGraphV2State extends State<MyBigGraphV2> {
  late List<List<FlSpot>> allPlotData;
  late List<int> allCurrentIndexes;
  late List<dynamic> plotScales;
  late List<dynamic> plotThresholds;
  late List<double> plotOffsets;
  late List<dynamic> plotGains;
  late MultiFilter multiFilter = MultiFilter();
  int FILT_BUF_SIZE = 3 * 6 + 7;
  int Pos = 0; // Circular buffer position tracker
  late List<List<double>> filterBuffs;
  late Stream<dynamic> stream;
  bool _clearedForImport = false;
  int _cycleCount = 0;

  List<MapEntry<double, String>> _yAxisLabelList = [];

  late ValueNotifier<List<List<FlSpot>>> plotNotifier;

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
    filterPositions = List.generate(
      widget.plot.length,
      (_) => 0,
    ); // <-- Add this
    allPlotData = List.generate(widget.plot.length, (_) => []);
    plotNotifier = ValueNotifier(allPlotData);
    allCurrentIndexes = List.generate(widget.plot.length, (_) => 0);

    plotScales =
        widget.plot.map((e) {
          final boxes = (e["scale"] ?? 5).toDouble();
          final boxValue =
              (e["boxValue"] ?? (4096 / 12)).toDouble(); // fallback
          return boxValue * boxes;
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

    if (widget.markerIndices != null) {
      widget.markerIndices!.addListener(_onMarkerUpdate);
    }
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

  @override
  void didUpdateWidget(covariant MyBigGraphV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markerIndices != widget.markerIndices) {
      oldWidget.markerIndices?.removeListener(_onMarkerUpdate);
      widget.markerIndices?.addListener(_onMarkerUpdate);
    }
  }

  @override
  void dispose() {
    widget.markerIndices?.removeListener(_onMarkerUpdate);
    super.dispose();
  }

  void _onMarkerUpdate() {
    setState(() {}); // trigger rebuild to show new marker lines
  }

  List<VerticalLine> _generateMarkerLines() {
    if (widget.markerIndices == null) return [];
    final markers = widget.markerIndices!.value;
    if (markers.isEmpty) return [];

    // Imported mode: keep existing direct mapping (full timeline)
    if (widget.isImported) {
      return markers.map((g) {
        return VerticalLine(
          x: g.toDouble(),
          color: Colors.orange.withOpacity(0.9),
          strokeWidth: 1.2,
          dashArray: [4, 3],
        );
      }).toList();
    }

    // Cyclic mode:
    // Show only markers belonging to the current cycle.
    // A cycle spans windowSize samples: cycle = globalIndex ~/ windowSize
    // Fixed local X inside cycle = globalIndex % windowSize
    final int currentCycle = _cycleCount;
    final int win = widget.windowSize;

    return markers.where((g) => (g ~/ win) == currentCycle).map((g) {
      final localX = (g % win).toDouble();
      return VerticalLine(
        x: localX,
        color: Colors.orange.withOpacity(0.9),
        strokeWidth: 1.2,
        dashArray: [4, 3],
      );
    }).toList();
  }

  // Modify _generateVerticalLines() call site inside LineChartData -> extraLinesData:
  // Replace:
  // verticalLines: _generateVerticalLines(),
  // With combined:
  // verticalLines: [
  //   ..._generateVerticalLines(),
  //   ..._generateMarkerLines(),
  // ],

  // Find in _chart() method:
  // extraLinesData: ExtraLinesData(
  //   verticalLines: _generateVerticalLines(),
  //   horizontalLines: _generateSeparationLines(),
  // ),

  // Replace that block with:
  // extraLinesData: ExtraLinesData(
  //   verticalLines: [
  //     ..._generateVerticalLines(),
  //     ..._generateMarkerLines(),
  //   ],
  //   horizontalLines: _generateSeparationLines(),
  // ),

  late List<int> filterPositions;

  double applyMultiFilterToChannel(int channelIndex, double val) {
    final filterSettings = widget.plot[channelIndex]["filterConfig"];
    if (filterSettings == null || filterSettings["filterOn"] != true) {
      return val; // No filtering if disabled
    }

    const int StartStageCNo = 0;
    const int MAX_STAGES_MINUS_ONE = FilterClass.MAX_STAGES - 1;

    // Init filter buffers and positions if needed
    if (filterBuffs.isEmpty ||
        filterBuffs.length != multiFilter.filters.length) {
      filterBuffs = List.generate(
        multiFilter.filters.length,
        (_) => List<double>.filled(FILT_BUF_SIZE, 0.0),
      );
      filterPositions = List.generate(
        multiFilter.filters.length,
        (_) => 0,
      ); // <-- Add this
    }

    FilterClass currentFilter = multiFilter.getFilter(channelIndex);
    List<double> currentBuffer = filterBuffs[channelIndex];
    int localPos = filterPositions[channelIndex];

    double localSum = 0;

    currentBuffer[localPos] = val;
    // if (channelIndex == 3) {
    //   print("FL1");
    //   print(val);
    // }

    for (int stage = StartStageCNo; stage <= MAX_STAGES_MINUS_ONE; stage++) {
      localSum = 0;
      for (int c = 0; c < 5; c++) {
        int index = (localPos + FILT_BUF_SIZE - c) % FILT_BUF_SIZE;
        localSum += currentBuffer[index] * currentFilter.Coeff[stage][c];
      }

      localSum *= 2; // default gain

      currentBuffer[(localPos + 1) % FILT_BUF_SIZE] = localSum;
      currentBuffer[(localPos + 6) % FILT_BUF_SIZE] = localSum;

      localPos = (localPos + 6) % FILT_BUF_SIZE;
    }
    // if (channelIndex == 3) {
    //   print("FL2");
    //   print(localSum);
    // }
    if (filterSettings['additionalGainCal'] != null) {
      double addGain =
          filterSettings['additionalGainCal'] is int
              ? (filterSettings['additionalGainCal'] as int).toDouble()
              : (filterSettings['additionalGainCal'] is double
                  ? filterSettings['additionalGainCal'] as double
                  : 1.0);
      localSum *= addGain;
    }

    Pos = (Pos + 2) % FILT_BUF_SIZE;

    return localSum;
  }

  // ValueNotifier<List<FlSpot>> plotNotifier = ValueNotifier([]);
  // Add this near the top of your class
  int _sampleBatchCounter = 0;
  final int _batchThreshold = 5; // 🔁 update graph every 20 samples
  int fullLengthIndex = 0;

  List<double> updateEverythingWithoutGraph(List<double> values) {
    List<double> processedValues = [];

    for (int i = 0; i < values.length; i++) {
      double value = values[i];
      value = applyMultiFilterToChannel(i, value);

      // --- Moving Average ---
      final movingAvgConfig = widget.plot[i]["movingAverage"];
      if (movingAvgConfig != null &&
          movingAvgConfig["enabled"] == true &&
          movingAvgConfig["window"] is int &&
          movingAvgConfig["window"] > 1) {
        int window = movingAvgConfig["window"];
        // Maintain a buffer for moving average per channel
        widget.plot[i]["_maBuffer"] ??= <double>[];
        List<double> maBuffer = widget.plot[i]["_maBuffer"];
        maBuffer.add(value);
        if (maBuffer.length > window) maBuffer.removeAt(0);
        value = maBuffer.reduce((a, b) => a + b) / maBuffer.length;
      }

      processedValues.add(value);
      final converter = widget.plot[i]["valueConverter"];
      if (converter != null && converter is Function) {
        value = converter(value);
      }
      // Do NOT update allPlotData or plotNotifier
      // Only process values
    }

    fullLengthIndex++;
    return processedValues;
  }

  clean() {
    // to reset data to original state of streight lines
    for (int i = 0; i < widget.plot.length; i++) {
      allPlotData[i].clear();
      allCurrentIndexes[i] = 0;
      for (int j = 0; j < widget.windowSize; j++) {
        allPlotData[i].add(FlSpot(j.toDouble(), 0.0));
      }
    }
    // _clearedForImport = false;
  }

  cycleMinus() {
    setState(() {
      _cycleCount--;
    });
  }

  void _autoScalePreset(int channelIndex, double value) {
    final plot = widget.plot[channelIndex];
    final presets = plot["scalePresets"];
    if (presets is! List || presets.isEmpty) return;

    int currentIndex = plot["scalePresetIndex"] ?? 0;
    int newIndex = currentIndex;

    // Upscale: If value exceeds next preset's trigger, go up
    for (int i = currentIndex + 1; i < presets.length; i++) {
      final trigger = presets[i]["rangeTrigger"] ?? 0;
      if (value >= trigger) {
        newIndex = i;
      }
    }

    // Descend: Only if ALL values in window are below previous trigger
    if (newIndex == currentIndex && currentIndex > 0) {
      final prevTrigger = presets[currentIndex]["rangeTrigger"] ?? 0;
      // Get all values in window for this channel
      final List<double> windowValues =
          allPlotData[channelIndex].map((spot) => spot.y).toList();
      if (windowValues.isNotEmpty &&
          windowValues.every((v) => v < prevTrigger)) {
        newIndex = currentIndex - 1;
      }
    }

    if (newIndex != currentIndex) {
      plot["scalePresetIndex"] = newIndex;
      plot["boxValue"] = presets[newIndex]["boxValue"];
      plot["minDisplay"] = presets[newIndex]["minDisplay"];
      plot["maxDisplay"] = presets[newIndex]["maxDisplay"];
      setState(() {});
    }
  }

  List<double> updateEverything(List<double> values) {
    List<double> processedValues = [];
    for (int i = 0; i < values.length; i++) {
      double value = values[i];
      value = applyMultiFilterToChannel(i, value);

      // --- Moving Average ---
      final movingAvgConfig = widget.plot[i]["movingAverage"];
      if (movingAvgConfig != null &&
          movingAvgConfig["enabled"] == true &&
          movingAvgConfig["window"] is int &&
          movingAvgConfig["window"] > 1) {
        int window = movingAvgConfig["window"];
        widget.plot[i]["_maBuffer"] ??= <double>[];
        List<double> maBuffer = widget.plot[i]["_maBuffer"];
        maBuffer.add(value);
        if (maBuffer.length > window) maBuffer.removeAt(0);
        value = maBuffer.reduce((a, b) => a + b) / maBuffer.length;
      }

      // Save the processed value (unflipped)
      processedValues.add(value);

      // --- Flip display if needed (for plotting only) ---
      double displayValue = value;
      if (widget.plot[i]["flipDisplay"] == true) {
        displayValue = -displayValue;
      }

      // --- Automatic scale switching ---
      if (widget.plot[i]["autoScale"] == true) {
        _autoScalePreset(i, value);
      }

      final converter = widget.plot[i]["valueConverter"];
      if (converter != null && converter is Function) {
        displayValue = converter(displayValue);
      }
      if (widget.isImported) {
        if (!_clearedForImport) {
          for (var list in allPlotData) list.clear();
          _clearedForImport = true;
        }

        double x = allPlotData[i].isNotEmpty ? allPlotData[i].last.x + 1 : 0.0;
        allPlotData[i].add(FlSpot(x, displayValue));
      } else {
        if (allCurrentIndexes[i] >= widget.windowSize) {
          widget.onCycleComplete?.call();
          allCurrentIndexes[i] = 0;
          if (i == 0) _cycleCount++;
        }

        allPlotData[i][allCurrentIndexes[i]] = FlSpot(
          allCurrentIndexes[i].toDouble(),
          displayValue,
        );
        allCurrentIndexes[i]++;
      }
    }

    // 🧠 Instead of updating every sample, update every 20 samples
    _sampleBatchCounter++;
    if (_sampleBatchCounter >= _batchThreshold) {
      plotNotifier.value = List.generate(
        allPlotData.length,
        (i) => List.of(allPlotData[i]),
      );
      _sampleBatchCounter = 0;
    }
    fullLengthIndex++;
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
    _yAxisLabelList.clear(); // Ensure labels are rebuilt each time

    double totalHeight = widget.maxY - widget.minY;
    double plotSpacing = totalHeight / widget.plot.length;

    for (int i = 0; i < widget.plot.length; i++) {
      double channelTop = widget.maxY - plotSpacing * i;
      double channelBottom = widget.maxY - plotSpacing * (i + 1);

      // Config values
      double minDisplay = (widget.plot[i]["minDisplay"] ?? 0.0).toDouble();
      double maxDisplay = (widget.plot[i]["maxDisplay"] ?? 100.0).toDouble();
      double boxValue = (widget.plot[i]["boxValue"] ?? 25.0).toDouble();
      String unit = widget.plot[i]["unit"]?.toString() ?? "";

      double range = maxDisplay - minDisplay;
      double pixelsPerUnit = plotSpacing / range;

      for (double val = minDisplay; val <= maxDisplay; val += boxValue) {
        double y = channelBottom + (val - minDisplay) * pixelsPerUnit;

        if (y >= channelBottom && y <= channelTop) {
          lines.add(
            HorizontalLine(
              y: y,
              color: Colors.blue.shade400,
              strokeWidth: (val == 0) ? 0.6 : 0.3,
            ),
          );

          // --- Y-axis label conversion ---
          double displayVal = val;
          String displayUnit = unit;
          final convertFn = widget.plot[i]["yAxisLabelConvert"];
          final labelUnit = widget.plot[i]["yAxisLabelUnit"];
          if (convertFn != null && convertFn is Function) {
            try {
              displayVal = convertFn(val);
              if (labelUnit != null) displayUnit = labelUnit;
            } catch (_) {
              // debugPrint("Y-axis label conversion error for value $val");
            }
          }

          int labelDecimal =
              widget.plot[i]["labelDecimal"] ?? 1; // Default to 1 decimal
          if (widget.plot[i]["flipDisplay"] == true) {
            displayVal = -displayVal;
          }
          _yAxisLabelList.add(
            MapEntry(
              y,
              "${displayVal.toStringAsFixed(labelDecimal)} $displayUnit",
            ),
          );
        }
      }

      if (i != 0) {
        lines.add(
          HorizontalLine(y: channelTop, color: Colors.black, strokeWidth: 0.6),
        );
      }
    }

    return lines;
  }

  String _getLiveValueLabel(int index) {
    final dataList = allPlotData[index];
    if (dataList.isEmpty) return "--";

    final latestPoint =
        widget.isImported
            ? dataList.last
            : dataList[(allCurrentIndexes[index] - 1) % widget.windowSize];

    double raw = latestPoint.y;
    // Unflip if flipDisplay is true
    if (widget.plot[index]["flipDisplay"] == true) {
      raw = -raw;
    }
    double scaled = raw;
    double offsetAdjusted = scaled + plotOffsets[index];

    var meter = widget.plot[index]["meter"];
    double displayValue = offsetAdjusted;

    if (meter != null &&
        meter["convert"] != null &&
        meter["convert"] is Function) {
      try {
        displayValue = meter["convert"](scaled, fullLengthIndex);
      } catch (_) {
        displayValue = scaled;
      }
    }

    if (displayValue.isNaN || displayValue.isInfinite) return "--";

    String unit =
        meter != null && meter["unit"] != null ? meter["unit"].toString() : "";
    if (meter != null && meter["decimal"] != null) {
      return "${displayValue.toStringAsFixed(meter["decimal"])} $unit";
    } else {
      return "${displayValue.toStringAsFixed(2)} $unit";
    }
  }

  Widget _leftConsole() {
    double totalHeight = (250 / 12) * 35;
    double sectionHeight = totalHeight / widget.plot.length;

    return Container(
      width: 120,
      color: Colors.white,
      child: Column(
        children: List.generate(widget.plot.length, (i) {
          final plot = widget.plot[i];
          final customButtons =
              plot["customButtons"] as List<Map<String, dynamic>>?;

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
                              fontSize: 11,
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
                              onPressed: () => _adjustScale(i, increase: false),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _adjustScale(i, increase: true),
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

                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.filter_alt, size: 16),
                      tooltip: "Set Filters",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _openFilterDialog(i),
                    ),
                    // --- Custom Buttons ---
                    if (customButtons != null)
                      Row(
                        children:
                            customButtons.map((btn) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2.0,
                                ),
                                child: IconButton(
                                  icon: Icon(btn["icon"], size: 16),

                                  onPressed: () {
                                    if (btn["onPressed"] != null) {
                                      btn["onPressed"](allPlotData[i]);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(80, 32),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                  ],
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
                  // AutoScale
                  SwitchListTile(
                    title: const Text("Auto Scale"),
                    value: widget.plot[index]["autoScale"] == true,
                    onChanged: (val) {
                      setState(() {
                        widget.plot[index]["autoScale"] = val;
                      });
                    },
                  ),
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
        width: 55,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
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
            AutoSizeText(
              liveValue,
              maxLines: 1,
              minFontSize: 10,
              style: const TextStyle(
                fontSize: 13,
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

  // void _adjustScale(int index, {required bool increase}) {
  //   setState(() {
  //     double minDisplay = (widget.plot[index]["minDisplay"] ?? 0.0).toDouble();
  //     double maxDisplay =
  //         (widget.plot[index]["maxDisplay"] ?? 100.0).toDouble();
  //     double boxValue = (widget.plot[index]["boxValue"] ?? 25.0).toDouble();

  //     if (increase) {
  //       // Zoom in: remove one box from both ends, but keep at least one box
  //       if ((maxDisplay - minDisplay) > 2 * boxValue) {
  //         widget.plot[index]["minDisplay"] = minDisplay + boxValue;
  //         widget.plot[index]["maxDisplay"] = maxDisplay - boxValue;
  //       }
  //     } else {
  //       // Zoom out: add one box to both ends
  //       widget.plot[index]["minDisplay"] = minDisplay - boxValue;
  //       widget.plot[index]["maxDisplay"] = maxDisplay + boxValue;
  //     }
  //   });
  // }

  // void _adjustScale(int index, {required bool increase}) {
  //   setState(() {
  //     double minDisplay = (widget.plot[index]["minDisplay"] ?? 0.0).toDouble();
  //     double maxDisplay =
  //         (widget.plot[index]["maxDisplay"] ?? 100.0).toDouble();
  //     double boxValue = (widget.plot[index]["boxValue"] ?? 25.0).toDouble();

  //     // Keep number of boxes constant
  //     int numBoxes = 5; // Or whatever you want (e.g., 5 boxes always)

  //     // Adjust boxValue to zoom
  //     if (increase) {
  //       boxValue /= 1.5; // Zoom in: smaller value per box
  //     } else {
  //       boxValue *= 1.5; // Zoom out: larger value per box
  //     }

  //     // Prevent boxValue from being too small or too large
  //     if (boxValue < 0.001) boxValue = 0.001;
  //     if (boxValue > 1e6) boxValue = 1e6;

  //     double mid = (maxDisplay + minDisplay) / 2;
  //     double newRange = numBoxes * boxValue;

  //     widget.plot[index]["boxValue"] = boxValue;
  //     widget.plot[index]["minDisplay"] = mid - newRange / 2;
  //     widget.plot[index]["maxDisplay"] = mid + newRange / 2;
  //   });
  // }

  void _adjustScale(int index, {required bool increase}) {
    setState(() {
      // Check for preset scaling config
      final preset = widget.plot[index]["scalePresets"];
      int presetPos = widget.plot[index]["scalePresetIndex"] ?? 0;

      if (preset is List && preset.isNotEmpty) {
        // Use preset scaling
        if (increase) {
          if (presetPos < preset.length - 1) presetPos++;
        } else {
          if (presetPos > 0) presetPos--;
        }
        final presetVal = preset[presetPos];
        // Support both boxValue or min/maxDisplay in preset
        if (presetVal is Map) {
          widget.plot[index]["boxValue"] =
              presetVal["boxValue"] ?? widget.plot[index]["boxValue"];
          widget.plot[index]["minDisplay"] =
              presetVal["minDisplay"] ?? widget.plot[index]["minDisplay"];
          widget.plot[index]["maxDisplay"] =
              presetVal["maxDisplay"] ?? widget.plot[index]["maxDisplay"];
        } else {
          // If preset is just a boxValue list
          widget.plot[index]["boxValue"] = presetVal;
          // Recalculate min/maxDisplay centered
          double minDisplay =
              (widget.plot[index]["minDisplay"] ?? 0.0).toDouble();
          double maxDisplay =
              (widget.plot[index]["maxDisplay"] ?? 100.0).toDouble();
          int numBoxes = 5;
          double mid = (maxDisplay + minDisplay) / 2;
          double newRange = numBoxes * (presetVal as double);
          widget.plot[index]["minDisplay"] = mid - newRange / 2;
          widget.plot[index]["maxDisplay"] = mid + newRange / 2;
        }
        widget.plot[index]["scalePresetIndex"] = presetPos;
      } else {
        // Fallback to original dynamic scaling
        double minDisplay =
            (widget.plot[index]["minDisplay"] ?? 0.0).toDouble();
        double maxDisplay =
            (widget.plot[index]["maxDisplay"] ?? 100.0).toDouble();
        double boxValue = (widget.plot[index]["boxValue"] ?? 25.0).toDouble();

        int numBoxes = 5;

        if (increase) {
          boxValue *= 1.5;
        } else {
          boxValue /= 1.5;
        }

        if (boxValue < 0.001) boxValue = 0.001;
        if (boxValue > 1e6) boxValue = 1e6;

        double mid = (maxDisplay + minDisplay) / 2;
        double newRange = numBoxes * boxValue;

        widget.plot[index]["boxValue"] = boxValue;
        widget.plot[index]["minDisplay"] = mid - newRange / 2;
        widget.plot[index]["maxDisplay"] = mid + newRange / 2;
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
      double boxValue = (widget.plot[index]["boxValue"] ?? 25.0).toDouble();
      if (up) {
        widget.plot[index]["minDisplay"] =
            (widget.plot[index]["minDisplay"] ?? 0.0) + boxValue;
        widget.plot[index]["maxDisplay"] =
            (widget.plot[index]["maxDisplay"] ?? 100.0) + boxValue;
      } else {
        widget.plot[index]["minDisplay"] =
            (widget.plot[index]["minDisplay"] ?? 0.0) - boxValue;
        widget.plot[index]["maxDisplay"] =
            (widget.plot[index]["maxDisplay"] ?? 100.0) - boxValue;
      }
    });
  }

  Widget _buildYAxisLabelSynced(double value) {
    const double tolerance = 1.5;

    for (final entry in _yAxisLabelList) {
      if ((entry.key - value).abs() <= tolerance) {
        return Text(
          entry.value,
          style: const TextStyle(
            fontSize: 8,
            color: Color.fromARGB(255, 117, 117, 117),
          ),
          textAlign: TextAlign.right,
        );
      }
    }

    return const SizedBox.shrink(); // No matching label
  }

  Widget _buildTimeLabel(double sampleIndex) {
    // base time from completed cycles, in seconds:
    final baseSeconds = _cycleCount * widget.windowSize / widget.samplingRate;
    // current sample’s time within this cycle:
    final cycleSeconds = sampleIndex / widget.samplingRate;
    final totalSeconds = baseSeconds + cycleSeconds;

    final minutes = totalSeconds ~/ 60;
    final secs = (totalSeconds % 60).toInt();

    return Text(
      "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}",
      style: const TextStyle(fontSize: 10, color: Colors.black),
      textAlign: TextAlign.center,
    );
  }

  Widget _chart(List<List<FlSpot>> currentData) {
    int gapLength = 25; // Number of points to hide ahead of current index

    return Container(
      height: (250 / 12) * 35,
      child: LineChart(
        duration: const Duration(milliseconds: 0),
        // key: ValueKey(allPlotData[0].last.x), // ✅ forces rebuild
        LineChartData(
          lineTouchData: LineTouchData(
            enabled: false,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 0,
              getTooltipItems: (_) => [],
            ),
            handleBuiltInTouches: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => _buildYAxisLabelSynced(value),
                interval: 1,
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: widget.samplingRate * 1,
                getTitlesWidget: (value, meta) {
                  return _buildTimeLabel(value);
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.blue.shade300, width: 0.2),
          ),
          clipData: FlClipData.all(),
          gridData: FlGridData(
            show: false,
            drawHorizontalLine: true,
            drawVerticalLine: true,
            horizontalInterval: widget.horizontalInterval,
            verticalInterval: widget.verticalInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.blue.shade300, strokeWidth: 0.2);
            },
            getDrawingVerticalLine: (value) {
              if (value % (widget.samplingRate * 1.0) == 0) {
                return FlLine(color: Colors.blue.shade300, strokeWidth: 0.2);
              } else if (value % (widget.samplingRate * 0.2) == 0) {
                return FlLine(color: Colors.blue.shade300, strokeWidth: 0.2);
              } else {
                return FlLine(color: Colors.transparent, strokeWidth: 0);
              }
            },
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              ..._generateVerticalLines(),
              ..._generateMarkerLines(),
            ],
            horizontalLines: _generateSeparationLines(),
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
          lineBarsData:
              List.generate(widget.plot.length, (i) {
                double totalHeight = widget.maxY - widget.minY;
                double plotSpacing = totalHeight / widget.plot.length;

                // Prepare shifted spots
                List<FlSpot> shiftedSpots =
                    allPlotData[i].map((spot) {
                      double channelTop = widget.maxY - plotSpacing * i;
                      double channelBottom =
                          widget.maxY - plotSpacing * (i + 1);

                      final minD =
                          (widget.plot[i]["minDisplay"] ?? 0.0).toDouble();
                      final maxD =
                          (widget.plot[i]["maxDisplay"] ?? 100.0).toDouble();
                      final val = spot.y * plotGains[i];

                      double clampedVal = val.clamp(minD, maxD) as double;
                      double range = maxD - minD;
                      double percent = (clampedVal - minD) / range;
                      double shiftedY = channelBottom + (percent * plotSpacing);

                      if (shiftedY < channelBottom) shiftedY = channelBottom;
                      if (shiftedY > channelTop) shiftedY = channelTop;

                      return FlSpot(spot.x, shiftedY);
                    }).toList();

                int currentIdx = allCurrentIndexes[i] % widget.windowSize;

                // Split into two segments for the gap
                List<FlSpot> segment1 = [];
                List<FlSpot> segment2 = [];

                if (widget.isImported) {
                  segment1 = shiftedSpots;
                } else {
                  // Segment before the gap
                  for (int j = 0; j <= currentIdx; j++) {
                    if (j < shiftedSpots.length) segment1.add(shiftedSpots[j]);
                  }
                  // Segment after the gap
                  for (
                    int j = currentIdx + gapLength + 1;
                    j < shiftedSpots.length;
                    j++
                  ) {
                    segment2.add(shiftedSpots[j]);
                  }
                }

                List<LineChartBarData> bars = [];

                if (segment1.isNotEmpty) {
                  bars.add(
                    LineChartBarData(
                      spots: segment1,
                      isCurved: false,
                      color: Colors.black,
                      barWidth: 1.2,
                      dotData: FlDotData(show: false),
                    ),
                  );
                }
                if (segment2.isNotEmpty) {
                  bars.add(
                    LineChartBarData(
                      spots: segment2,
                      isCurved: false,
                      color: Colors.black,
                      barWidth: 1.2,
                      dotData: FlDotData(show: false),
                    ),
                  );
                }

                return bars;
              }).expand((e) => e).toList(),
        ),
      ),
    );
  }

  double pixelsPerSample = 1; // ✅ Tune this as needed
  ScrollController _scrollController = ScrollController(); // At state level

  void reset() {
    setState(() {
      // Clear all data
      for (int i = 0; i < allPlotData.length; i++) {
        allPlotData[i].clear();

        // Fill cyclic mode data with zeroes if not imported
        if (!widget.isImported) {
          allPlotData[i] = List.generate(
            widget.windowSize,
            (index) => FlSpot(index.toDouble(), 0),
          );
          allCurrentIndexes[i] = 0;
        }
      }

      // Reset all filter buffers
      filterBuffs = List.generate(
        widget.plot.length,
        (_) => List<double>.filled(FILT_BUF_SIZE, 0.0),
      );

      // Reset gains, offsets, and flags
      plotOffsets = List.generate(widget.plot.length, (_) => 0.0);
      _clearedForImport = false;
      Pos = 0;

      // Optionally refresh filters again
      _refreshMultiFilter();

      // Reset cycle count for X axis timer
      _cycleCount = 0;
    });
  }

  // reset only x axis timer
  void resetXAxisTimer() {
    setState(() {
      _cycleCount = 0;
      // fullLengthIndex = 0; // Reset the full length index
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _leftConsole(), // ✅ Left panel with controls
        Expanded(
          child: ValueListenableBuilder<List<List<FlSpot>>>(
            valueListenable: plotNotifier,
            builder: (context, currentData, _) {
              final bool hasData =
                  currentData.isNotEmpty && currentData[0].isNotEmpty;

              final double calculatedWidth =
                  widget.isImported
                      ? (hasData
                          ? currentData[0].last.x * 0.4
                          : widget.windowSize.toDouble())
                      : widget.windowSize.toDouble() * 0.5;

              return SizedBox(
                width: calculatedWidth,
                child: _chart(currentData),
              );
            },
          ),
        ),
      ],
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Row(
  //     children: [
  //       _leftConsole(), // ✅ Left panel with controls
  //       Expanded(
  //         child: Listener(
  //           onPointerSignal: (event) {
  //             if (event is PointerScrollEvent) {
  //               _scrollController.jumpTo(
  //                 _scrollController.offset + event.scrollDelta.dy,
  //               );
  //             }
  //           },
  //           child: Scrollbar(
  //             controller: _scrollController,
  //             thumbVisibility: true,
  //             child: SingleChildScrollView(
  //               controller: _scrollController,
  //               scrollDirection: Axis.horizontal,
  //               child: ValueListenableBuilder<List<List<FlSpot>>>(
  //                 valueListenable: plotNotifier,
  //                 builder: (context, currentData, _) {
  //                   final bool hasData =
  //                       currentData.isNotEmpty && currentData[0].isNotEmpty;

  //                   final double calculatedWidth =
  //                       widget.isImported
  //                           ? (hasData
  //                               ? currentData[0].last.x * 0.4
  //                               : widget.windowSize.toDouble())
  //                           : widget.windowSize.toDouble() * 0.5;

  //                   return SizedBox(
  //                     width: calculatedWidth,
  //                     child: _chart(currentData),
  //                   );
  //                 },
  //               ),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }
}
