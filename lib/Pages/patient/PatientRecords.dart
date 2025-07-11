// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:spirobtvo/data/local/database.dart';

// class PatientRecordingsPage extends StatelessWidget {
//   final int patientId;
//   const PatientRecordingsPage({super.key, required this.patientId});

//   @override
//   Widget build(BuildContext context) {
//     final db = Provider.of<AppDatabase>(context, listen: false);

//     return Scaffold(
//       appBar: AppBar(title: Text('Patient Recordings'), centerTitle: true),
//       body: FutureBuilder<List<Recording>>(
//         future: db.select(db.recordings)
//           ..where((tbl) => tbl.patientId.equals(patientId)).get(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }
//           if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }
//           final recordings = snapshot.data ?? [];
//           if (recordings.isEmpty) {
//             return const Center(
//               child: Text('No recordings found for this patient.'),
//             );
//           }
//           return ListView.builder(
//             itemCount: recordings.length,
//             itemBuilder: (context, index) {
//               final rec = recordings[index];
//               return Card(
//                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: ListTile(
//                   leading: Icon(Icons.folder),
//                   title: Text(rec.filePath),
//                   subtitle: Text(
//                     'Recorded at: ${rec.recordedAt?.toLocal().toString().split(".")[0] ?? "Unknown"}',
//                   ),
//                   trailing: IconButton(
//                     icon: Icon(Icons.open_in_new),
//                     onPressed: () {
//                       // TODO: Implement file open/view logic
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         SnackBar(content: Text('File path: ${rec.filePath}')),
//                       );
//                     },
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
