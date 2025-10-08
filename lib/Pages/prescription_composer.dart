import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:medicore/data/local/database.dart';

class PrescriptionComposer extends StatefulWidget {
  final int? patientId;
  final Patient? patient;
  
  const PrescriptionComposer({super.key, this.patientId, this.patient});

  @override
  State<PrescriptionComposer> createState() => _PrescriptionComposerState();
}

class _PrescriptionComposerState extends State<PrescriptionComposer> {
  final _formKey = GlobalKey<FormState>();
  
  // Diagnosis / Notes
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  
  // Vitals
  final _bpSystolicController = TextEditingController();
  final _bpDiastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _spo2Controller = TextEditingController();
  
  // Custom Instructions
  final _customInstructionsController = TextEditingController();
  
  // Medicines list
  List<Medicine> _medicines = [];

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _bpSystolicController.dispose();
    _bpDiastolicController.dispose();
    _heartRateController.dispose();
    _temperatureController.dispose();
    _spo2Controller.dispose();
    _customInstructionsController.dispose();
    super.dispose();
  }

  void _addMedicine() {
    setState(() {
      _medicines.add(Medicine());
    });
  }

  void _removeMedicine(int index) {
    setState(() {
      _medicines.removeAt(index);
    });
  }

  Future<void> _savePrescription() async {
    if (_formKey.currentState!.validate()) {
      if (widget.patientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No patient selected for prescription'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final db = Provider.of<AppDatabase>(context, listen: false);

        // Create prescription record
        final prescriptionCompanion = PrescriptionsCompanion.insert(
          patientId: widget.patientId!,
          diagnosis: _diagnosisController.text,
          notes: drift.Value(_notesController.text.isNotEmpty ? _notesController.text : null),
          bpSystolic: drift.Value(_bpSystolicController.text.isNotEmpty ? _bpSystolicController.text : null),
          bpDiastolic: drift.Value(_bpDiastolicController.text.isNotEmpty ? _bpDiastolicController.text : null),
          heartRate: drift.Value(_heartRateController.text.isNotEmpty ? _heartRateController.text : null),
          temperature: drift.Value(_temperatureController.text.isNotEmpty ? _temperatureController.text : null),
          spo2: drift.Value(_spo2Controller.text.isNotEmpty ? _spo2Controller.text : null),
          customInstructions: drift.Value(_customInstructionsController.text.isNotEmpty ? _customInstructionsController.text : null),
        );

        final prescriptionId = await db.into(db.prescriptions).insert(prescriptionCompanion);

        // Save medicines
        for (final medicine in _medicines) {
          if (medicine.nameController.text.isNotEmpty) {
            final medicineCompanion = MedicinesCompanion.insert(
              prescriptionId: prescriptionId,
              name: medicine.nameController.text,
              strength: drift.Value(medicine.strengthController.text.isNotEmpty ? medicine.strengthController.text : null),
              dose: drift.Value(medicine.doseController.text.isNotEmpty ? medicine.doseController.text : null),
              frequency: drift.Value(medicine.frequencyController.text.isNotEmpty ? medicine.frequencyController.text : null),
              duration: drift.Value(medicine.durationController.text.isNotEmpty ? medicine.durationController.text : null),
              route: drift.Value(medicine.routeController.text.isNotEmpty ? medicine.routeController.text : null),
            );
            await db.into(db.medicines).insert(medicineCompanion);
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving prescription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prescription Composer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _savePrescription,
            icon: Icon(Icons.save),
            tooltip: 'Save Prescription',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Section (if patient provided)
              if (widget.patient != null) ...[
                _buildSectionTitle('Patient Information'),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name: ${widget.patient!.name}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('Age: ${widget.patient!.age} years'),
                        Text('Gender: ${widget.patient!.gender}'),
                        Text('Mobile: ${widget.patient!.mobile}'),
                        Text('Height: ${widget.patient!.height} cm'),
                        Text('Weight: ${widget.patient!.weight} kg'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Vitals Section
              _buildSectionTitle('Vitals'),
              _buildVitalsSection(),
              SizedBox(height: 20),

              // Diagnosis Section
              _buildSectionTitle('Diagnosis & Notes'),
              _buildDiagnosisSection(),
              SizedBox(height: 20),

              // Medicines Section
              _buildSectionTitle('Medicines'),
              _buildMedicinesSection(),
              SizedBox(height: 20),

              // Custom Instructions Section
              _buildSectionTitle('Custom Instructions'),
              _buildCustomInstructionsSection(),
              SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savePrescription,
                  icon: Icon(Icons.save),
                  label: Text('Save Prescription'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildVitalsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _bpSystolicController,
                    decoration: InputDecoration(
                      labelText: 'BP Systolic (mmHg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 10),
                Text('/', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _bpDiastolicController,
                    decoration: InputDecoration(
                      labelText: 'BP Diastolic (mmHg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heartRateController,
                    decoration: InputDecoration(
                      labelText: 'Heart Rate (bpm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _temperatureController,
                    decoration: InputDecoration(
                      labelText: 'Temperature (°F)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _spo2Controller,
              decoration: InputDecoration(
                labelText: 'SpO₂ (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _diagnosisController,
              decoration: InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(),
                hintText: 'Enter primary diagnosis',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a diagnosis';
                }
                return null;
              },
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Clinical Notes',
                border: OutlineInputBorder(),
                hintText: 'Additional notes, observations, recommendations...',
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicinesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prescribed Medicines',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _addMedicine,
                  icon: Icon(Icons.add),
                  label: Text('Add Medicine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (_medicines.isEmpty)
              Container(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No medicines added yet.\nClick "Add Medicine" to start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _medicines.length,
                itemBuilder: (context, index) {
                  return _buildMedicineCard(index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(int index) {
    final medicine = _medicines[index];
    
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medicine ${index + 1}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => _removeMedicine(index),
                  icon: Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove Medicine',
                ),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: medicine.nameController,
              decoration: InputDecoration(
                labelText: 'Generic Name *',
                border: OutlineInputBorder(),
                hintText: 'e.g., Paracetamol',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Medicine name is required';
                }
                return null;
              },
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medicine.strengthController,
                    decoration: InputDecoration(
                      labelText: 'Strength',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 500mg',
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: medicine.doseController,
                    decoration: InputDecoration(
                      labelText: 'Dose',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 1 tablet',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medicine.frequencyController,
                    decoration: InputDecoration(
                      labelText: 'Frequency',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., TID (3 times daily)',
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: medicine.durationController,
                    decoration: InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 7 days',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: medicine.routeController,
              decoration: InputDecoration(
                labelText: 'Route',
                border: OutlineInputBorder(),
                hintText: 'e.g., Oral, IV, IM',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInstructionsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: TextFormField(
          controller: _customInstructionsController,
          decoration: InputDecoration(
            labelText: 'Custom Instructions',
            border: OutlineInputBorder(),
            hintText: 'Additional instructions for the patient...\n'
                     'e.g., Take after meals, Avoid alcohol, Follow-up in 1 week',
          ),
          maxLines: 4,
        ),
      ),
    );
  }
}

class Medicine {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController strengthController = TextEditingController();
  final TextEditingController doseController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController routeController = TextEditingController();

  void dispose() {
    nameController.dispose();
    strengthController.dispose();
    doseController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    routeController.dispose();
  }
}