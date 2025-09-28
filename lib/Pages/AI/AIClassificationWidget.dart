import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:holtersync/Pages/AI/ECGClassV1.dart';
import 'package:holtersync/Pages/AI/previewSegment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIClassificationWidget extends StatefulWidget {
  final dynamic ecgData;
  final bool? openNew;

  final dynamic rrIndex;
  final dynamic guid;
  final dynamic preDetection;

  const AIClassificationWidget({
    super.key,
    this.guid,
    required this.ecgData,
    this.openNew = false,
    this.preDetection,
    this.rrIndex,
  });

  @override
  State<AIClassificationWidget> createState() => _AIClassificationWidgetState();
}

class _AIClassificationWidgetState extends State<AIClassificationWidget> {
  ECGClassv1? aiclass1;

  var preds = [];
  bool isLoading = true;

  String consolidatedReport = "";

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }

  init() async {
    aiclass1 = await ECGClassv1.create();
    aiclass1!.init();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("aireport-c-${widget.guid}") != null &&
        prefs.getString("aireport-a-${widget.guid}") != null) {
      print("Picked");
      print(prefs.getString("aireport-a-${widget.guid}"));
      print('preds');

      setState(() {
        consolidatedReport =
            prefs.getString("aireport-c-${widget.guid}").toString();
        var jsn = prefs.getString("aireport-a-${widget.guid}");
        print('preds');
        print(jsn);
        preds = jsonDecode(jsn!);
        isLoading = false;
      });
      return;
    }
    var predictions = await aiclass1!.predict(widget.ecgData, widget.rrIndex);
    String cReport = aiclass1!.consolidateAIResult(predictions);
    print("CREPORT");
    print(cReport);
    print("AIPREDS");
    print(predictions);
    prefs.setString("aireport-c-${widget.guid}", cReport);
    var jsn = jsonEncode(predictions);
    prefs.setString("aireport-a-${widget.guid}", jsn);
    setState(() {
      preds = predictions;
      consolidatedReport = cReport;
      isLoading = false;
    });
  }

  _aiIntWarningLabel() {
    if (consolidatedReport == "Normal Sinus Rhythm") {
      return Container();
    }
    return Text(
      "This is an AI interpretation please contact your physician.",
      style: TextStyle(fontSize: 9),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (widget.preDetection.length > 0 &&
        consolidatedReport == "Normal Sinus Rhythm") {
      return Container(
        child: Column(
          children: [
            Text("AI Classification"),
            Text(
              "Abnormal ECG",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _aiIntWarningLabel(),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ListPreds(preds: preds, ecgData: widget.ecgData),
                  ),
                );
              },
              child: Text("View"),
            ),
          ],
        ),
      );
    }
    if (widget.openNew == true) {
      return Container(
        child: Column(
          children: [
            Text("AI Classification"),
            Text(
              "$consolidatedReport",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _aiIntWarningLabel(),
            Text("Detected Classifications: ${preds.length}"),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ListPreds(preds: preds, ecgData: widget.ecgData),
                  ),
                );
              },
              child: Text("View"),
            ),
          ],
        ),
      );
    }
    return Expanded(
      child: ListView.builder(
        itemCount: preds.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => PreviewSegment(
                        segment: preds[index],
                        ecgData: widget.ecgData,
                      ),
                ),
              );
            },
            child: Card(
              child: ListTile(
                title: Text("${preds[index]["classification"]} Detected"),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ListPreds extends StatefulWidget {
  final dynamic preds;
  final dynamic ecgData;

  const ListPreds({super.key, required this.preds, required this.ecgData});

  @override
  State<ListPreds> createState() => _ListPredsState();
}

class _ListPredsState extends State<ListPreds> {
  _time(start) {
    int startSeconds = (start / 300).floor();
    int startMinutes = (startSeconds / 60).floor();
    int startHours = (startMinutes / 60).floor();
    int startMinutesRem = startMinutes % 60;
    String time = "${startHours}:${startMinutesRem}:${startSeconds % 60}";
    return Text(time);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Detections")),
      body: ListView.builder(
        itemCount: widget.preds.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => PreviewSegment(
                        segment: widget.preds[index],
                        ecgData: widget.ecgData,
                      ),
                ),
              );
            },
            child: Card(
              child: ListTile(
                trailing: Text(
                  "${widget.preds[index]["confidence"].toString()} C, ${widget.preds[index]["aoiConfidence"].toString()} A",
                ),
                title: Text(
                  "${widget.preds[index]["classification"]} Detected",
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
