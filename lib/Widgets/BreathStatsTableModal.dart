import 'package:flutter/material.dart';

class BreathStatsTableModal extends StatelessWidget {
  final List<Map<String, dynamic>> breathStats;
  final VoidCallback? onDownload;
  final VoidCallback? onClose;

  const BreathStatsTableModal({
    Key? key,
    required this.breathStats,
    this.onDownload,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final headers = [
      'O%',
      'CO2%',
      'HR',
      'VO2%',
      'VCO2%',
      'VE MINTUE',
      'RER',
      'ESTIMATED CO',
    ];

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Breath Stats Table",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              alignment: Alignment.topRight,
              child: ElevatedButton.icon(
                onPressed: onDownload,
                icon: Icon(Icons.download),
                label: Text("Download Excel"),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Center(
                    child: DataTable(
                      columns: headers
                          .map(
                            (h) => DataColumn(
                              label: Text(
                                h,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                          .toList(),
                      rows: breathStats.map((row) {
                        return DataRow(
                          cells: [
                            DataCell(Text((row['o2'] ?? '').toString())),
                            DataCell(Text((row['co2'] ?? '').toString())),
                            DataCell(Text((row['hr'] ?? '').toString())),
                            DataCell(Text((row['vo2'] ?? 0).toStringAsFixed(2))),
                            DataCell(Text((row['vco2'] ?? 0).toStringAsFixed(2))),
                            DataCell(Text((row['vol'] ?? '').toString())),
                            DataCell(Text((row['rer'] ?? 0).toStringAsFixed(2))),
                            DataCell(Text((row['co'] ?? '').toString())),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: onClose ?? () => Navigator.pop(context),
                child: Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}