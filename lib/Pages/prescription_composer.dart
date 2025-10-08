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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 700 ? 2 : 1;
            final gap = 12.0;
            final tileWidth = columns == 1 ? width : (width - gap) / columns;

            if (columns == 1) {
              final tiles = <Widget>[];
              if (widget.patient != null) {
                tiles.add(
                  SizedBox(
                    width: tileWidth,
                    child: _Section(
                      title: 'Patient Information',
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${widget.patient!.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Age: ${widget.patient!.age} years'),
                            Text('Gender: ${widget.patient!.gender}'),
                            Text('Mobile: ${widget.patient!.mobile}'),
                            Text('Height: ${widget.patient!.height} cm'),
                            Text('Weight: ${widget.patient!.weight} kg'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              tiles.addAll([
                SizedBox(width: tileWidth, child: _Section(title: 'Vitals', child: _buildVitalsSectionBody())),
                SizedBox(width: tileWidth, child: _Section(title: 'Diagnosis & Notes', child: _buildDiagnosisSectionBody())),
                SizedBox(width: tileWidth, child: _Section(title: 'Custom Instructions', child: _buildCustomInstructionsBody())),
                SizedBox(width: tileWidth, child: _buildMedicinesSectionCompact()),
              ]);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < tiles.length; i++) ...[
                      tiles[i],
                      if (i != tiles.length - 1) SizedBox(height: gap),
                    ],
                  ],
                ),
              );
            }

            // Two-column: keep Medicines on the right side
            final leftCol = <Widget>[];
            if (widget.patient != null) {
              leftCol.add(
                SizedBox(
                  width: tileWidth,
                  child: _Section(
                    title: 'Patient Information',
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: ${widget.patient!.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Age: ${widget.patient!.age} years'),
                          Text('Gender: ${widget.patient!.gender}'),
                          Text('Mobile: ${widget.patient!.mobile}'),
                          Text('Height: ${widget.patient!.height} cm'),
                          Text('Weight: ${widget.patient!.weight} kg'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            leftCol.addAll([
              SizedBox(width: tileWidth, child: _Section(title: 'Vitals', child: _buildVitalsSectionBody())),
              SizedBox(width: tileWidth, child: _Section(title: 'Diagnosis & Notes', child: _buildDiagnosisSectionBody())),
              SizedBox(width: tileWidth, child: _Section(title: 'Custom Instructions', child: _buildCustomInstructionsBody())),
            ]);

            final rightCol = <Widget>[
              SizedBox(width: tileWidth, child: _buildMedicinesSectionCompact()),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < leftCol.length; i++) ...[
                          leftCol[i],
                          if (i != leftCol.length - 1) SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < rightCol.length; i++) ...[
                          rightCol[i],
                          if (i != rightCol.length - 1) SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

  // Compact input style used across fields to reduce vertical space
  InputDecoration _compactDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  // Vitals content (used inside a section card)
  Widget _buildVitalsSectionBody() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bpSystolicController,
                  decoration: _compactDecoration('BP Systolic (mmHg)'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              const Text('/', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _bpDiastolicController,
                  decoration: _compactDecoration('BP Diastolic (mmHg)'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heartRateController,
                  decoration: _compactDecoration('Heart Rate (bpm)'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _temperatureController,
                  decoration: _compactDecoration('Temperature (°F)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _spo2Controller,
            decoration: _compactDecoration('SpO₂ (%)'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  // Diagnosis & notes content
  Widget _buildDiagnosisSectionBody() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextFormField(
            controller: _diagnosisController,
            decoration: _compactDecoration('Diagnosis', hint: 'Enter primary diagnosis'),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a diagnosis';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesController,
            decoration: _compactDecoration('Clinical Notes', hint: 'Additional notes, observations, recommendations...'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // Custom instructions content
  Widget _buildCustomInstructionsBody() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextFormField(
        controller: _customInstructionsController,
        decoration: _compactDecoration(
          'Custom Instructions',
          hint: 'Additional instructions... e.g., Take after meals',
        ),
        maxLines: 3,
      ),
    );
  }

  // Compact medicines section (header + list/add)
  Widget _buildMedicinesSectionCompact() {
    return _Section(
      title: 'Medicines',
      trailing: TextButton.icon(
        onPressed: _addMedicine,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _medicines.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'No medicines added yet. Tap Add to start.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _medicines.length,
                itemBuilder: (context, index) {
                  return _buildMedicineCard(index);
                },
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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Medicine ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: () => _removeMedicine(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove Medicine',
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: medicine.nameController,
              decoration: _compactDecoration('Generic Name *', hint: 'e.g., Paracetamol'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Medicine name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medicine.strengthController,
                    decoration: _compactDecoration('Strength', hint: 'e.g., 500mg'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    controller: medicine.doseController,
                    decoration: _compactDecoration('Dose', hint: 'e.g., 1 tablet'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medicine.frequencyController,
                    decoration: _compactDecoration('Frequency', hint: 'e.g., TID'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    controller: medicine.durationController,
                    decoration: _compactDecoration('Duration', hint: 'e.g., 7 days'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: medicine.routeController,
              decoration: _compactDecoration('Route', hint: 'e.g., Oral, IV, IM'),
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

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.blue.withOpacity(0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blue)),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          child,
        ],
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
