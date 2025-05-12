import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/Pages/patient/patientAdd.dart';
import 'package:provider/provider.dart';
import 'package:spirobtvo/ProviderModals/DefaultPatientModal.dart';

class Patients extends StatefulWidget {
  const Patients({super.key});

  @override
  State<Patients> createState() => _PatientsState();
}

class _PatientsState extends State<Patients> {
  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic>? _defaultPatient;

  bool _isDefault(Map<String, dynamic> patient,
      Map<String, dynamic>? defaultPatient) {
    if (defaultPatient == null) return false;
    return patient['mobile'] == defaultPatient['mobile'] && patient['age'] == defaultPatient['age'];
  }

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('patients');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _patients = List<Map<String, dynamic>>.from(decoded);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DefaultPatientModal>(
      builder: (context, defaultProvider, child) {
        final defaultPatient = defaultProvider.patient;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(title: const Text("Patients"), centerTitle: true),
          body: Column(
            children: [
              // Add Patient Button
              Container(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (
                            context) => const PatientAdd()),
                      );
                      _loadPatients(); // Reload list
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Patient"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
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
                child: _patients.isEmpty
                    ? const Center(
                  child: Text("No patients found.",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _patients.length,
                  itemBuilder: (context, index) {
                    final patient = _patients[index];
                    final isDefault = _isDefault(patient, defaultPatient);

                    return Card(
                      color: isDefault ? Colors.green[50] : Colors.white,
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius
                          .circular(12)),
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
                                  child: const Icon(
                                      Icons.person, color: Colors.blue,
                                      size: 30),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        patient['name'] ?? 'Unnamed',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDefault
                                              ? Colors.green[800]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Gender: ${patient['gender'] ??
                                            '-'} • Age: ${patient['age'] ??
                                            '-'}",
                                        style: TextStyle(
                                            color: Colors.grey[700]),
                                      ),
                                      Text(
                                        "Mobile: ${patient['mobile'] ?? '-'}",
                                        style: TextStyle(
                                            color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isDefault ? Icons.verified : Icons
                                      .arrow_forward_ios_rounded,
                                  color: isDefault ? Colors.green : Colors.grey,
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final prefs = await SharedPreferences
                                      .getInstance();
                                  prefs.setString(
                                      'default_patient', jsonEncode(patient));
                                  defaultProvider.setDefault(patient);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(
                                        "${patient['name']} set as default patient")),
                                  );
                                },
                                icon: Icon(Icons.push_pin,
                                    color: isDefault ? Colors.green : Colors
                                        .black, size: 18),
                                label: Text(
                                  isDefault
                                      ? "Default Patient"
                                      : "Set as Default",
                                  style: TextStyle(
                                      color: isDefault ? Colors.green : Colors
                                          .black),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: isDefault ? Colors.green : Colors
                                          .black),
                                ),
                              ),
                            )
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
