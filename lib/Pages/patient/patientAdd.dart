import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spirobtvo/ProviderModals/DefaultPatientModal.dart';
import 'package:spirobtvo/data/local/database.dart';
import 'package:drift/drift.dart' as drift;

class PatientAdd extends StatefulWidget {
  const PatientAdd({super.key});

  @override
  State<PatientAdd> createState() => _PatientAddState();
}

class _PatientAddState extends State<PatientAdd> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  String _name = '';
  String _mobile = '';
  String _age = '';
  String _height = '';
  String _weight = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(
      context,
      listen: false,
    ); // Provide AppDatabase via Provider

    return Consumer<DefaultPatientModal>(
      builder: (context, defaultProvider, child) {
        return Scaffold(
          appBar: AppBar(title: Text("Add Patient"), centerTitle: true),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Patient Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        "Name",
                        Icons.person,
                        (val) => _name = val,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.transgender),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: _selectedGender,
                        items:
                            ['Male', 'Female', 'Other']
                                .map(
                                  (gender) => DropdownMenuItem(
                                    value: gender,
                                    child: Text(gender),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator:
                            (value) =>
                                value == null ? 'Please select gender' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        "Mobile",
                        Icons.phone,
                        (val) => _mobile = val,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        "Age",
                        Icons.calendar_today,
                        (val) => _age = val,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        "Height (cm)",
                        Icons.height,
                        (val) => _height = val,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        "Weight (kg)",
                        Icons.monitor_weight,
                        (val) => _weight = val,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text("Save Patient"),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Saving patient...")),
                              );
                              // Insert patient into Drift database
                              final patientCompanion = PatientsCompanion(
                                name: drift.Value(_name),
                                gender: drift.Value(_selectedGender ?? ''),
                                mobile: drift.Value(_mobile),
                                age: drift.Value(int.tryParse(_age) ?? 0),
                                height: drift.Value(
                                  double.tryParse(_height) ?? 0.0,
                                ),
                                weight: drift.Value(
                                  double.tryParse(_weight) ?? 0.0,
                                ),
                                // createdAt will use default value
                              );
                              final id = await db
                                  .into(db.patients)
                                  .insert(patientCompanion);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Patient saved successfully"),
                                ),
                              );

                              // Optionally set default patient in your provider
                              defaultProvider.setDefault({
                                'id': id,
                                'name': _name,
                                'gender': _selectedGender ?? '',
                                'mobile': _mobile,
                                'age': _age,
                                'height': _height,
                                'weight': _weight,
                              });

                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    Function(String) onChanged,
  ) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,
      validator:
          (value) =>
              value == null || value.isEmpty ? 'Please enter $label' : null,
    );
  }
}
