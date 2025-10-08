import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicore/Pages/GlobalSettings.dart';
import 'package:medicore/Pages/patient/list.dart';
import 'package:medicore/Pages/patient/patientAdd.dart';
import 'package:medicore/Pages/patient/PatientRecords.dart';
import 'package:medicore/Pages/prescription_composer.dart';
import 'package:medicore/data/local/database.dart';
import 'package:medicore/Services/DataSaver.dart';
import 'package:path_provider/path_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

enum HomeView { patients, addPatient, prescription }

class _HomeState extends State<Home> {
  HomeView _currentView = HomeView.patients;
  final TextEditingController _mobileSearchController = TextEditingController();

  @override
  void dispose() {
    _mobileSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchByMobile(String mobile) async {
    final query = mobile.trim();
    if (query.isEmpty) return;
    try {
      final db = Provider.of<AppDatabase>(context, listen: false);
      final patient = await (db.select(db.patients)..where((t) => t.mobile.equals(query))).getSingleOrNull();
      if (!mounted) return;
      if (patient != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PatientRecordingsPage(patientId: patient.id)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No patient found. Creating new with mobile $query')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PatientAdd(prefillMobile: query)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Data & Reset App'),
          content: const Text(
            'Are you sure you want to clear all data and reset the app? This will:\n\n'
            '� Delete all patients and recordings\n'
            '� Clear all stored files\n'
            '� Reset app to first-time setup\n'
            '� Return to setup wizard\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reset App'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final db = Provider.of<AppDatabase>(context, listen: false);
        await db.delete(db.medicines).go();
        await db.delete(db.prescriptions).go();
        await db.delete(db.recordings).go();
        await db.delete(db.patients).go();

        DataSaver().reset();
        final dir = await getApplicationDocumentsDirectory();
        final tempDir = Directory('${dir.path}/HolterSync/Temp');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('setup_completed', false);
        await prefs.remove('globalSettings');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App reset successfully. Redirecting to setup...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/setup', (route) => false);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting app: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Medicore'),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () { setState(() { _currentView = HomeView.patients; }); },
              icon: const Icon(Icons.people, size: 18),
              label: const Text('Patients'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _currentView == HomeView.patients ? Colors.white.withOpacity(0.16) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () { setState(() { _currentView = HomeView.addPatient; }); },
              icon: const Icon(Icons.add_box, size: 18),
              label: const Text('Add Patient'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _currentView == HomeView.addPatient ? Colors.white.withOpacity(0.16) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () { setState(() { _currentView = HomeView.prescription; }); },
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('Composer'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _currentView == HomeView.prescription ? Colors.white.withOpacity(0.16) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _clearAllData,
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[100],
                backgroundColor: Colors.red.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          SizedBox(
            width: 280,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: _mobileSearchController,
                onSubmitted: _searchByMobile,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Search by mobile',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GlobalSettings()),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildCurrentView(),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case HomeView.patients:
        return const _KeepAlive(child: PatientsList());
      case HomeView.addPatient:
        return const _KeepAlive(child: PatientAdd());
      case HomeView.prescription:
        return _KeepAlive(child: _buildPrescriptionTab());
    }
  }

  Widget _buildPrescriptionTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Prescription Composer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Expanded(child: PrescriptionComposer()),
        ],
      ),
    );
  }

  Widget _buildPatientsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Patient Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Expanded(child: PatientsList()),
        ],
      ),
    );
  }

  Widget _buildAddPatientTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Add New Patient', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Expanded(child: PatientAdd()),
        ],
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  _KeepAliveState createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
