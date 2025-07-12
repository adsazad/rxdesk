import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spirobtvo/data/local/database.dart';
import 'package:spirobtvo/ProviderModals/ImportFileProvider.dart';

class PatientRecordingsPage extends StatelessWidget {
  final int patientId;
  const PatientRecordingsPage({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Recordings'),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 2,
      ),
      body: FutureBuilder<Patient?>(
        future:
            (db.select(db.patients)
              ..where((tbl) => tbl.id.equals(patientId))).getSingleOrNull(),
        builder: (context, patientSnapshot) {
          if (patientSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (patientSnapshot.hasError) {
            return Center(child: Text('Error: ${patientSnapshot.error}'));
          }
          final patient = patientSnapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (patient != null)
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.black12,
                          child: Icon(
                            Icons.person,
                            color: Colors.black,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.transgender,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text("Gender: ${patient.gender}"),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.cake,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text("Age: ${patient.age}"),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text("Mobile: ${patient.mobile}"),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.height,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text("Height: ${patient.height} cm"),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.monitor_weight,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text("Weight: ${patient.weight} kg"),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Created: ${patient.createdAt.toLocal().toString().split(".")[0]}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Text(
                  "Recordings",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Recording>>(
                  future:
                      (db.select(
                        db.recordings,
                      )..where((tbl) => tbl.patientId.equals(patientId))).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final recordings = snapshot.data ?? [];
                    if (recordings.isEmpty) {
                      return const Center(
                        child: Text(
                          'No recordings found for this patient.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: recordings.length,
                      itemBuilder: (context, index) {
                        final rec = recordings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.folder, color: Colors.black),
                            title: Text(
                              rec.filePath.split('/').last,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Recorded at: ${rec.recordedAt?.toLocal().toString().split(".")[0] ?? "Unknown"}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.open_in_new,
                                color: Colors.green,
                              ),
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
