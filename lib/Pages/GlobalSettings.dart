import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicore/ProviderModals/GlobalSettingsModal.dart';

class GlobalSettings extends StatefulWidget {
  const GlobalSettings({super.key});

  @override
  State<GlobalSettings> createState() => _GlobalSettingsState();
}

class _GlobalSettingsState extends State<GlobalSettings> {
  TextEditingController hospitalNameController = TextEditingController();
  TextEditingController hospitalAddressController = TextEditingController();
  TextEditingController hospitalContactController = TextEditingController();
  TextEditingController hospitalEmailController = TextEditingController();

  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    hospitalNameController.dispose();
    hospitalAddressController.dispose();
    hospitalContactController.dispose();
    hospitalEmailController.dispose();
    super.dispose();
  }

  _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    hospitalNameController.text = globalSettings.hospitalName;
    hospitalAddressController.text = globalSettings.hospitalAddress;
    hospitalContactController.text = globalSettings.hospitalContact;
    hospitalEmailController.text = globalSettings.hospitalEmail;
  }

  saveHospitalInfo() {
    final globalSettings = Provider.of<GlobalSettingsModal>(
      context,
      listen: false,
    );
    globalSettings.setHospitalName(hospitalNameController.text.trim());
    globalSettings.setHospitalAddress(hospitalAddressController.text.trim());
    globalSettings.setHospitalContact(hospitalContactController.text.trim());
    globalSettings.setHospitalEmail(hospitalEmailController.text.trim());
    prefs?.setString("globalSettings", globalSettings.toJson());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                "Hospital Information",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: hospitalNameController,
                decoration: InputDecoration(
                  labelText: "Hospital Name",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: hospitalAddressController,
                decoration: InputDecoration(
                  labelText: "Address",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: hospitalContactController,
                decoration: InputDecoration(
                  labelText: "Contact Number",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: hospitalEmailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  saveHospitalInfo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Hospital info saved!")),
                  );
                },
                child: Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}