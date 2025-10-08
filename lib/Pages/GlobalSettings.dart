import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicore/ProviderModals/GlobalSettingsModal.dart';
import 'package:file_picker/file_picker.dart';

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
  // Print settings controllers
  TextEditingController marginTopController = TextEditingController();
  TextEditingController marginBottomController = TextEditingController();
  TextEditingController marginLeftController = TextEditingController();
  TextEditingController marginRightController = TextEditingController();
  TextEditingController footerTextController = TextEditingController();
  bool printHeader = true;
  bool printFooter = false;
  // Logo & doctor & paper
  String logoPath = '';
  String headerLogoAlignment = 'left';
  TextEditingController doctorNameController = TextEditingController();
  TextEditingController doctorRegistrationController = TextEditingController();
  bool showSignatureLine = true;
  String paperSize = 'A4';
  String orientation = 'portrait';

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
    marginTopController.dispose();
    marginBottomController.dispose();
    marginLeftController.dispose();
    marginRightController.dispose();
    footerTextController.dispose();
    doctorNameController.dispose();
    doctorRegistrationController.dispose();
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
    // Load print settings
    printHeader = globalSettings.printHeader;
    printFooter = globalSettings.printFooter;
    footerTextController.text = globalSettings.footerText;
    marginTopController.text = globalSettings.marginTopMm.toStringAsFixed(0);
    marginBottomController.text = globalSettings.marginBottomMm.toStringAsFixed(0);
    marginLeftController.text = globalSettings.marginLeftMm.toStringAsFixed(0);
    marginRightController.text = globalSettings.marginRightMm.toStringAsFixed(0);
    logoPath = globalSettings.logoPath;
    headerLogoAlignment = globalSettings.headerLogoAlignment;
    doctorNameController.text = globalSettings.doctorName;
    doctorRegistrationController.text = globalSettings.doctorRegistration;
    showSignatureLine = globalSettings.showSignatureLine;
    paperSize = globalSettings.paperSize;
    orientation = globalSettings.orientation;
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
    // Save print settings
    globalSettings.setPrintHeader(printHeader);
    globalSettings.setPrintFooter(printFooter);
    globalSettings.setFooterText(footerTextController.text.trim());
    double parse(String s, double def) {
      final v = double.tryParse(s.trim());
      return (v == null || v < 0) ? def : v;
    }
    globalSettings.setMargins(
      topMm: parse(marginTopController.text, 15),
      bottomMm: parse(marginBottomController.text, 15),
      leftMm: parse(marginLeftController.text, 12),
      rightMm: parse(marginRightController.text, 12),
    );
    globalSettings.setLogoPath(logoPath);
    globalSettings.setHeaderLogoAlignment(headerLogoAlignment);
    globalSettings.setDoctorName(doctorNameController.text.trim());
    globalSettings.setDoctorRegistration(doctorRegistrationController.text.trim());
    globalSettings.setShowSignatureLine(showSignatureLine);
    globalSettings.setPaperSize(paperSize);
    globalSettings.setOrientation(orientation);
    prefs?.setString("globalSettings", globalSettings.toJson());
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        logoPath = result.files.single.path!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Hospital'),
                Tab(text: 'Prescription Print'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Hospital tab
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            "Hospital Information",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: hospitalNameController,
                            decoration: const InputDecoration(labelText: "Hospital Name", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: hospitalAddressController,
                            decoration: const InputDecoration(labelText: "Address", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: hospitalContactController,
                            decoration: const InputDecoration(labelText: "Contact Number", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: hospitalEmailController,
                            decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text("Header Logo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.image),
                                label: const Text('Choose Logo'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  logoPath.isEmpty ? 'No logo selected' : logoPath,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (logoPath.isNotEmpty)
                            SizedBox(
                              height: 80,
                              child: Image(
                                image: FileImage(File(logoPath)),
                                errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Logo alignment:'),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: headerLogoAlignment,
                                items: const [
                                  DropdownMenuItem(value: 'left', child: Text('Left')),
                                  DropdownMenuItem(value: 'center', child: Text('Center')),
                                  DropdownMenuItem(value: 'right', child: Text('Right')),
                                ],
                                onChanged: (v) => setState(() => headerLogoAlignment = v ?? 'left'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              saveHospitalInfo();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings saved!")));
                            },
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Prescription Print tab
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text("Prescription Print Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: printHeader,
                            onChanged: (v) => setState(() => printHeader = v),
                            title: const Text("Show header (hospital info)"),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: marginTopController,
                                  decoration: const InputDecoration(labelText: "Top margin (mm)", border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: marginBottomController,
                                  decoration: const InputDecoration(labelText: "Bottom margin (mm)", border: OutlineInputBorder()),
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
                                  controller: marginLeftController,
                                  decoration: const InputDecoration(labelText: "Left margin (mm)", border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: marginRightController,
                                  decoration: const InputDecoration(labelText: "Right margin (mm)", border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Paper size:'),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: paperSize,
                                items: const [
                                  DropdownMenuItem(value: 'A4', child: Text('A4')),
                                  DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                                ],
                                onChanged: (v) => setState(() => paperSize = v ?? 'A4'),
                              ),
                              const SizedBox(width: 24),
                              const Text('Orientation:'),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: orientation,
                                items: const [
                                  DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                                  DropdownMenuItem(value: 'landscape', child: Text('Landscape')),
                                ],
                                onChanged: (v) => setState(() => orientation = v ?? 'portrait'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: doctorNameController,
                            decoration: const InputDecoration(labelText: "Doctor name", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: doctorRegistrationController,
                            decoration: const InputDecoration(labelText: "Registration / License No.", border: OutlineInputBorder()),
                          ),
                          SwitchListTile(
                            value: showSignatureLine,
                            onChanged: (v) => setState(() => showSignatureLine = v),
                            title: const Text("Show signature line"),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: printFooter,
                            onChanged: (v) => setState(() => printFooter = v),
                            title: const Text("Show footer"),
                          ),
                          TextFormField(
                            controller: footerTextController,
                            decoration: const InputDecoration(
                              labelText: "Footer text",
                              hintText: "e.g., Thank you for visiting",
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              saveHospitalInfo();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings saved!")));
                            },
                            child: const Text("Save"),
                          ),
                        ],
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
  }
}
