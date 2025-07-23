import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spirobtvo/ProviderModals/ImportFileProvider.dart';
import 'package:spirobtvo/data/local/database.dart';
import "package:drift/drift.dart" as drift;

class RecordingsListPage extends StatefulWidget {
  @override
  _RecordingsListPageState createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  late Future<List<Recording>> recordingsFuture;
  late final AppDatabase db;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    db = Provider.of<AppDatabase>(context, listen: false);
    // Order by createdAt descending (latest first)
    recordingsFuture =
        (db.select(db.recordings)..orderBy([
          (tbl) => drift.OrderingTerm(
            expression: tbl.createdAt,
            mode: drift.OrderingMode.desc,
          ),
        ])).get();
  }

  Future<List<Map<String, dynamic>>> getRecordingsWithPatientNames() async {
    final recordings = await recordingsFuture;
    final List<Map<String, dynamic>> result = [];
    for (final rec in recordings) {
      final patient =
          await (db.select(db.patients)
            ..where((tbl) => tbl.id.equals(rec.patientId))).getSingleOrNull();
      result.add({'recording': rec, 'patientName': patient?.name ?? 'Unknown'});
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Saved Recordings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: getRecordingsWithPatientNames(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No recordings found.'));
                }
                var items = snapshot.data!;
                if (searchQuery.isNotEmpty) {
                  items =
                      items
                          .where(
                            (item) => item['patientName']
                                .toLowerCase()
                                .contains(searchQuery),
                          )
                          .toList();
                }
                if (items.isEmpty) {
                  return Center(
                    child: Text('No recordings match your search.'),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final rec = items[index]['recording'] as Recording;
                    final patientName = items[index]['patientName'];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(rec.filePath ?? 'Unknown file'),
                        subtitle: Text(
                          'Patient: $patientName\n'
                          'Created: ${rec.createdAt}\n'
                          'Recorded: ${rec.recordedAt}',
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.home),
                          tooltip: "Load in Home",
                          onPressed: () {
                            Provider.of<ImportFileProvider>(
                              context,
                              listen: false,
                            ).setFilePath(rec.filePath);
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Open recording: ${rec.filePath}'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
