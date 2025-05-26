import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChartGenerator extends StatefulWidget {
  final dynamic cp;
  const ChartGenerator({super.key, required this.cp});

  @override
  State<ChartGenerator> createState() => _ChartGeneratorState();
}

class _ChartGeneratorState extends State<ChartGenerator> {
  List<String> options = [];
  String name = '';
  String xaxis = '';
  String yaxis = '';

  List<String> getAvailableKeys() {
    List<String> keys = widget.cp['breathStats'].first.keys.where((key) => key != 'index').toList();
    keys.add('time_series');
    return keys;
  }

  Widget buildDropdownField({
    required String label,
    required String selectedValue,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: options.contains(selectedValue) ? selectedValue : null,
          hint: Text(label),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            onChanged(newValue!);
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    options = getAvailableKeys();
  }
  Future<List<Map<String, dynamic>>> loadSavedCharts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('saved_charts');

    if (saved != null) {
      List<dynamic> list = jsonDecode(saved);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chart Generator'),
        centerTitle: true,
        // backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Create New Chart",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Chart Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (newValue) => name = newValue,
                  ),
                  SizedBox(height: 20),
                  buildDropdownField(
                    label: "Choose X-axis",
                    selectedValue: xaxis,
                    onChanged: (val) => setState(() => xaxis = val),
                  ),
                  SizedBox(height: 20),
                  buildDropdownField(
                    label: "Choose Y-axis",
                    selectedValue: yaxis,
                    onChanged: (val) => setState(() => yaxis = val),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: Colors.deepPurple,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    label: Text("Save Chart", style: TextStyle(fontSize: 16)),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();

                      Map<String, dynamic> newChart = {
                        'name': name,
                        'xaxis': xaxis,
                        'yaxis': yaxis,
                      };

                      final String? existing = prefs.getString('saved_charts');
                      List<Map<String, dynamic>> charts = [];

                      if (existing != null) {
                        List<dynamic> decoded = jsonDecode(existing);
                        charts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
                      }

                      charts.add(newChart);
                      await prefs.setString('saved_charts', jsonEncode(charts));

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Chart added to saved list")),
                      );
                    },
                  ),
                  SizedBox(height: 40),
                  Text("Saved Charts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: loadSavedCharts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Text("No charts saved yet.");
                      } else {
                        List<Map<String, dynamic>> charts = snapshot.data!;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: charts.length,
                          itemBuilder: (context, index) {
                            final chart = charts[index];
                            return ListTile(
                              leading: Icon(Icons.insert_chart),
                              title: Text(chart['name'] ?? 'Untitled'),
                              subtitle: Text("X: ${chart['xaxis']}  |  Y: ${chart['yaxis']}"),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                // Optional: Implement chart preview here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Tapped: ${chart['name']}")),
                                );
                              },
                            );
                          },
                        );
                      }
                    },
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
