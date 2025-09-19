import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bluevo2/Pages/patient/PatientRecords.dart';
import 'package:bluevo2/Pages/patient/patientAdd.dart';
import 'package:bluevo2/ProviderModals/DefaultPatientModal.dart';
import 'package:bluevo2/data/local/database.dart';

class PatientsList extends StatefulWidget {
  const PatientsList({super.key});

  @override
  State<PatientsList> createState() => _PatientsListState();
}

class _PatientsListState extends State<PatientsList> {
  List<Patient> _patients = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final patientsList = await db.select(db.patients).get();
    setState(() {
      _patients = patientsList;
    });
  }

  bool _isDefault(Patient patient, Map<String, dynamic>? defaultPatient) {
    if (defaultPatient == null) return false;
    return patient.mobile == defaultPatient['mobile'] &&
        patient.age.toString() == defaultPatient['age'];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DefaultPatientModal>(
      builder: (context, defaultProvider, child) {
        final defaultPatient = defaultProvider.patient;

        // Filter patients by search query
        final filteredPatients =
            _searchQuery.isEmpty
                ? _patients
                : _patients
                    .where(
                      (p) =>
                          (p.name ?? '').toLowerCase().contains(_searchQuery),
                    )
                    .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(title: const Text("Patients"), centerTitle: true),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by patient name...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              ),
              // Add Patient Button
              Container(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PatientAdd(),
                        ),
                      );
                      _loadPatients(); // Reload list after adding
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Patient"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Patient List
              Expanded(
                child:
                    filteredPatients.isEmpty
                        ? const Center(
                          child: Text(
                            "No patients found.",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPatients.length,
                          itemBuilder: (context, index) {
                            final patient = filteredPatients[index];
                            final isDefault = _isDefault(
                              patient,
                              defaultPatient,
                            );

                            return Card(
                              color:
                                  isDefault ? Colors.green[50] : Colors.white,
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: Colors.blue.shade100,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.blue,
                                            size: 30,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                patient.name ?? 'Unnamed',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isDefault
                                                          ? Colors.green[800]
                                                          : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.transgender,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Gender: ${patient.gender ?? '-'}",
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    Icons.cake,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Age: ${patient.age ?? '-'}",
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.phone,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Mobile: ${patient.mobile ?? '-'}",
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.height,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Height: ${patient.height} cm",
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    Icons.monitor_weight,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Weight: ${patient.weight} kg",
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isDefault
                                              ? Icons.verified
                                              : Icons.arrow_forward_ios_rounded,
                                          color:
                                              isDefault
                                                  ? Colors.green
                                                  : Colors.grey,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              defaultProvider.setDefault({
                                                'id': patient.id,
                                                'name': patient.name,
                                                'gender': patient.gender,
                                                'mobile': patient.mobile,
                                                'age': patient.age.toString(),
                                                'height':
                                                    patient.height.toString(),
                                                'weight':
                                                    patient.weight.toString(),
                                              });

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "${patient.name} set as default patient",
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              Icons.push_pin,
                                              color:
                                                  isDefault
                                                      ? Colors.green
                                                      : Colors.black,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isDefault
                                                  ? "Default Patient"
                                                  : "Set as Default",
                                              style: TextStyle(
                                                color:
                                                    isDefault
                                                        ? Colors.green
                                                        : Colors.black,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color:
                                                    isDefault
                                                        ? Colors.green
                                                        : Colors.black,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          PatientRecordingsPage(
                                                            patientId:
                                                                patient.id,
                                                          ),
                                                ),
                                              );
                                            },
                                            icon: Icon(
                                              Icons.folder_open,
                                              color: Colors.blue,
                                            ),
                                            label: Text(
                                              "Recordings",
                                              style: TextStyle(
                                                color: Colors.blue,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
