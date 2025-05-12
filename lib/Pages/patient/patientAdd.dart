import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Patient"),
        centerTitle: true,
        // backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Patient Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField("Name", Icons.person, (val) => _name = val),
                  const SizedBox(height: 12),
                  // 🔽 Gender Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.transgender),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    value: _selectedGender,
                    items: ['Male', 'Female', 'Other']
                        .map((gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? 'Please select gender' : null,
                  ),
                  const SizedBox(height: 12),

                  _buildTextField("Mobile", Icons.phone, (val) => _mobile = val),
                  const SizedBox(height: 12),
                  _buildTextField("Age", Icons.calendar_today, (val)=> _age = val),
                  const SizedBox(height: 12),
                  _buildTextField("Height (cm)", Icons.height, (val) => _height = val),
                  const SizedBox(height: 12),
                  _buildTextField("Weight (kg)", Icons.monitor_weight, (val) => _weight = val),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.save),
                      label: Text("Save Patient"),
                      style: ElevatedButton.styleFrom(
                        // backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: ()async {
                        if (_formKey.currentState!.validate()) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Saving patient...")),

                          );
                          final prefs = await SharedPreferences.getInstance();
                          final patient = {
                            'name': _name,
                            'gender': _selectedGender ?? '',
                            'mobile': _mobile,
                            'age': _age,
                            'height': _height,
                            'weight': _weight,
                          };
                          // Load existing patients list from SharedPreferences
                          final String? existing = prefs.getString('patients');
                          List<dynamic> patientsList = [];
                          if (existing != null) {
                            patientsList = jsonDecode(existing);
                          }
                          // Add new patient
                          patientsList.add(patient);

                          // Save updated list
                          await prefs.setString('patients', jsonEncode(patientsList));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Patient saved successfully")),
                          );
                          Navigator.of(context).push(new MaterialPageRoute(builder: (context) => PatientAdd()));
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
  }

  Widget _buildTextField(String label, IconData icon,Function(String) onChanged) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: onChanged,

      validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
    );
  }
}
