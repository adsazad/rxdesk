import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PreviewSegment extends StatefulWidget {
  final dynamic segment;
  final dynamic ecgData;

  const PreviewSegment({super.key, required this.segment, required this.ecgData});

  @override
  State<PreviewSegment> createState() => _PreviewSegmentState();
}

class _PreviewSegmentState extends State<PreviewSegment> {
  List<double> record = [];
  int sampleRate = 300;

  int windowSize = 400;
  List<double> windowEcgData = [];
  List<FlSpot> plotData = [];
  List<FlSpot> plotDot = [FlSpot(0, 0)];

  List<VerticalLine> twohundredMsLines = [];

  double graphWidth = 200;
  String time = "";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }


  init() {
    print("SEG");
    print(widget.segment);
    int start =widget.segment["segment"]["start"] ;
    int end = widget.segment["segment"]["end"];



    // start = start - 100;
    // end = end + 100;
    print(start);
    print(end);
    record = widget.ecgData.sublist(start, end);

    // record = widget.segment["segment"]["segment"];

    windowEcgData = record;

    // record = widget.segment;
    // windowEcgData = widget.segment;
    // print(windowEcgData.length);
    int fiveSecondsDataPoints = 5 * 300;
    windowSize = record.length;
    print("Record Length: ${windowSize}");
    if (windowSize > fiveSecondsDataPoints) {
      // windowSize = windowSize - fiveSecondsDataPoints;
    }
    print("window size");
    print(windowSize);

    double vlinex = 60;
    for (int i = 0; i <= 25; i++) {
      twohundredMsLines.add(VerticalLine(
        x: vlinex,
        color: Colors.blue.shade200,
        strokeWidth: 0.2,
      ));
      vlinex += 60;
    }
    double vDlinex = 300;
    // double vDlinex = sampleRate.toDouble();
    for (int i = 0; i <= 5; i++) {
      twohundredMsLines.add(VerticalLine(
        x: vDlinex,
        color: Colors.blue,
        strokeWidth: 0.6,
      ));
      vDlinex += 300;
      // vDlinex += sampleRate.toDouble();
    }

    for(int i = 0; i < windowEcgData.length; i++){
      plotData.add(FlSpot(i.toDouble(), windowEcgData[i]));
    }
    setState(() {
      plotData = plotData;
    });

  }

  _chart() {
    if (windowEcgData.length > 900 * 300) {
      return Container(
        child: Text("Data is too large to plot"),
      );
    }
    return Container(
        padding: EdgeInsets.all(10.0),
        width: graphWidth,
        height: 600,
        child: Container(
          child: Stack(
            children: [
              Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    child: Text("25mm/s    10mm/mV"),
                  ),
                ],
              ),
              LineChart(
                // swapAnimationDuration: Duration(milliseconds: 0),
                duration: Duration(milliseconds: 0),
                LineChartData(
                  titlesData: FlTitlesData(
                    show: false,
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(
                      showTitles: false,
                    )),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      top: BorderSide(color: Colors.blue.shade500, width: 0.6),
                      bottom:
                          BorderSide(color: Colors.blue.shade500, width: 0.6),
                      left: BorderSide(color: Colors.blue.shade500, width: 0.6),
                      right:
                          BorderSide(color: Colors.blue.shade500, width: 0.6),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: twohundredMsLines,
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    horizontalInterval: 4096 / 12,
                    verticalInterval: 8,
                    //    make it non dotted
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.blue.shade200,
                        strokeWidth: 0.2,
                      );
                    },

                    // getDrawingVerticalLine: (value) {
                    //   print(value);
                    //   if (value % 256 == 0) {
                    //     return FlLine(
                    //       color: Colors.red,
                    //       strokeWidth: 1,
                    //     );
                    //   } else {
                    //     // if(value > 51 <21)
                    //     return FlLine(
                    //       color: Colors.red.shade100,
                    //       strokeWidth: 0.5,
                    //     );
                    //   }
                    //   // return FlLine(
                    //   //   color: Colors.blue.shade100,
                    //   //   strokeWidth: 1,
                    //   // );
                    // },
                  ),
                  lineTouchData: LineTouchData(enabled: false),
                  // gridData: FlGridData(show: false),
                  // borderData: FlBorderData(show: false),

                  minX: 0,
                  maxX: plotData.length.toDouble() - 1,
                  minY: -(4096 / 12) * 6,
                  // minY:  300,
                  maxY: (4096 / 12) * 6,
                  // minY: 100,
                  // maxY: 300,
                  lineBarsData: getLineBarData(),
                ),
              ),
            ],
          ),
        ));
  }

  getLineBarData() {
    var linebar = [
      // LineChartBarData(
      //   dotData: FlDotData(show: false),
      //   barWidth: 1,
      //   color: Colors.blue,
      //   spots: dataFinal1.asMap().entries.map((entry) {
      //     return FlSpot(entry.key.toDouble(), entry.value);
      //   }).toList(),
      // ),
      LineChartBarData(
        dotData: FlDotData(
          show: true,
        ),
        barWidth: 0.5,
        color: Colors.black,
        spots: plotDot,
      ),
      LineChartBarData(
        dotData: FlDotData(show: false),
        barWidth: 1,
        color: Colors.black,
        spots: plotData,
      ),
    ];


    return linebar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Preview Segment"),
      ),
      body: Container(
          child: Column(
        children: [
          Text("StartIndex: ${widget.segment["segment"]["start"]}, EndIndex: ${widget.segment["segment"]["end"]}"),
          Center(
              child: _chart()
          ),
        ],
      )),
    );
  }
}
