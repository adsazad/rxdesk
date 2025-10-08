import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicore/Pages/GlobalSettings.dart';
import 'package:medicore/Pages/patient/list.dart';
import 'package:medicore/Pages/patient/patientAdd.dart';
import 'package:medicore/Pages/prescription_composer.dart';
import 'package:medicore/data/local/database.dart';
import 'package:medicore/Services/DataSaver.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

enum HomeView { patients, addPatient, prescription }

class _HomeState extends State<Home> {
  HomeView _currentView = HomeView.patients;

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All Data & Reset App'),
          content: Text(
            'Are you sure you want to clear all data and reset the app? This will:\n\n'
            '• Delete all patients and recordings\n'
            '• Clear all stored files\n'
            '• Reset app to first-time setup\n'
            '• Return to setup wizard\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Reset App'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Clear database
        final db = Provider.of<AppDatabase>(context, listen: false);
        await db.delete(db.medicines).go();
        await db.delete(db.prescriptions).go();
        await db.delete(db.recordings).go();
        await db.delete(db.patients).go();
        
        // Clear DataSaver files
        DataSaver().reset();
        final dir = await getApplicationDocumentsDirectory();
        final tempDir = Directory('${dir.path}/HolterSync/Temp');
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }

        // Reset setup completion status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('setup_completed', false);
        
        // Clear any other stored preferences if needed
        await prefs.remove('globalSettings');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('App reset successfully. Redirecting to setup...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to setup wizard after a short delay
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/setup',
            (route) => false, // Remove all routes
          );
        }
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting app: $e'),
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
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.medical_services, size: 40);
              },
            ),
            SizedBox(width: 10),
            Text('Medicore'),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Patients button
          IconButton(
            onPressed: () {
              setState(() {
                _currentView = HomeView.patients;
              });
            },
            icon: Icon(Icons.people),
            tooltip: 'Patients',
            style: IconButton.styleFrom(
              backgroundColor: _currentView == HomeView.patients 
                  ? Colors.white.withOpacity(0.2) 
                  : null,
            ),
          ),
          // Add Patient button
          IconButton(
            onPressed: () {
              setState(() {
                _currentView = HomeView.addPatient;
              });
            },
            icon: Icon(Icons.add_box),
            tooltip: 'Add Patient',
            style: IconButton.styleFrom(
              backgroundColor: _currentView == HomeView.addPatient 
                  ? Colors.white.withOpacity(0.2) 
                  : null,
            ),
          ),
          // Prescription Composer button (main navigation)
          IconButton(
            onPressed: () {
              setState(() {
                _currentView = HomeView.prescription;
              });
            },
            icon: Icon(Icons.receipt_long),
            tooltip: 'Prescription Composer',
            style: IconButton.styleFrom(
              backgroundColor: _currentView == HomeView.prescription 
                  ? Colors.white.withOpacity(0.2) 
                  : null,
            ),
          ),
          // Clear All Data & Reset App button
          IconButton(
            onPressed: _clearAllData,
            icon: Icon(Icons.delete_sweep),
            tooltip: 'Clear All Data & Reset App',
            style: IconButton.styleFrom(
              foregroundColor: Colors.red[100],
            ),
          ),
          // Settings button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GlobalSettings()),
              );
            },
            icon: Icon(Icons.settings),
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
        return _KeepAlive(child: _buildPatientsTab());
      case HomeView.addPatient:
        return _KeepAlive(child: _buildAddPatientTab());
      case HomeView.prescription:
        return _KeepAlive(child: _buildPrescriptionTab());
    }
  }

  Widget _buildPrescriptionTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Prescription Composer',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: PrescriptionComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: PatientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPatientTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Patient',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: PatientAdd(),
          ),
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