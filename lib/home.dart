import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holtersync/Pages/GlobalSettings.dart';
import 'package:holtersync/Pages/RecordingsListPage.dart';
import 'package:holtersync/Pages/patient/list.dart';
import 'package:holtersync/Pages/patient/patientAdd.dart';
import 'package:holtersync/ProviderModals/DefaultPatientModal.dart';
import 'package:holtersync/ProviderModals/ImportFileProvider.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';
import 'package:holtersync/Widgets/IconButtonColumn.dart';
import 'package:holtersync/Widgets/MyBigGraphScrollable.dart';
import 'package:holtersync/data/local/database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<MyBigGraphV2State> myBigGraphKey = GlobalKey();
  final HolterReportGenerator _holter = HolterReportGenerator();

  // Paging: 10 rows x 30 seconds each @ 300Hz = 90,000 samples per page
  static const int rowsPerPage = 10;
  static const int secondsPerRow = 30;
  static const int sr = 300;
  static const int samplesPerRow = secondsPerRow * sr; // 9000
  static const int samplesPerPage = rowsPerPage * samplesPerRow; // 90,000
  int _currentPage = 0;
  int _totalSamples = 0;

  int get _totalPages =>
      _totalSamples > 0
          ? ((_totalSamples + samplesPerPage - 1) ~/ samplesPerPage)
          : 0;

  String _formatSeconds(double seconds) {
    final total = seconds.floor();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  String get _currentPageTimeRangeText {
    if (_totalSamples <= 0 || _totalPages == 0)
      return 'Time: --:--:-- - --:--:-- @ 300 Hz';
    final startSample = _currentPage * samplesPerPage;
    final length =
        (startSample + samplesPerPage <= _totalSamples)
            ? samplesPerPage
            : (_totalSamples - startSample);
    final startSec = startSample / sr;
    final endSec = (startSample + length) / sr;
    return 'Time: ${_formatSeconds(startSec)} - ${_formatSeconds(endSec)} @ 300 Hz';
  }

  Widget _statBox(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ECG-only plot configuration
  final List<Map<String, dynamic>> plotConfig = [
    {
      "name": "ECG",
      "boxValue": 4096 / 12,
      "unit": "mV",
      "minDisplay": (-4096 / 12) * 3,
      "maxDisplay": (4096 / 12) * 3,
      "scale": 3,
      "gain": 1.0,
      "filterConfig": {"filterOn": true, "lpf": 3, "hpf": 5, "notch": 1},
      "meter": {"decimal": 1, "unit": "mV", "convert": (double x) => x},
    },
  ];

  // Import state
  bool _isImportingHolter = false;
  double _holterImportProgress = 0.0;

  File? importedFile;
  bool isImported = false;
  double importProgressPercent = 0.0;
  double currentImportDisplayIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final importProvider = Provider.of<ImportFileProvider>(context);
    if (importProvider.recordingId != null) {
      final int recId = importProvider.recordingId!;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _runHolterFromRecordingId(recId);
        await _loadPage(0); // show first page once holter is ready
        importProvider.clear();
      });
    }
  }

  // Pick raw holter, convert to .bin (ECG-only), save under app docs, insert DB row
  Future<void> _importNewHolterFile() async {
    setState(() {
      _isImportingHolter = true;
      _holterImportProgress = 0.0;
    });

    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Holter file to import',
        type: FileType.any,
      );
      if (res == null || res.files.single.path == null) {
        setState(() => _isImportingHolter = false);
        return;
      }
      final srcFile = File(res.files.single.path!);
      final raw = await srcFile.readAsBytes();

      // Decode ECG from raw (0x55 0xAA frames: 25 samples per frame, stride 8)
      final List<double> ecg = <double>[];
      int i = 0;
      while (i < raw.length - 1) {
        if (raw[i] == 0x55 && raw[i + 1] == 0xAA) {
          int f2 = i + 2, f3 = i + 3;
          for (int j = 0; j < 25; j++) {
            if (f2 < raw.length && f3 < raw.length) {
              // 16-bit little-endian sample: low byte at f2, high byte at f3
              int v = (raw[f2]) | (raw[f3] << 8); // = low + high*256
              // Optional: if the stream is signed 16-bit, sign-extend:
              if (v >= 0x8000) v -= 0x10000;
              ecg.add(v.toDouble());

              f2 += 8;
              f3 += 8;
            } else {
              break;
            }
          }
          // Jump near end of this frame to continue scanning
          i = f3 - 1;
        } else {
          i += 1;
        }
        if (raw.isNotEmpty) {
          _holterImportProgress = i / raw.length;
          if (mounted) setState(() {});
        }
      }

      if (ecg.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No ECG samples decoded from the file.'),
            ),
          );
          setState(() => _isImportingHolter = false);
        }
        return;
      }

      // Build .bin with JSON header + 5 Float64 channels (only ECG filled)
      final defaultPatient =
          Provider.of<DefaultPatientModal>(context, listen: false).patient;
      final headerJson = {
        'patient': defaultPatient ?? {},
        'format': 'holtersync-bin-v1',
        'samplingRate': 300,
        'channels': ['ECG', 'O2', 'CO2', 'Vol', 'Flow'],
        'createdAt': DateTime.now().toIso8601String(),
      };
      final headerBytes = utf8.encode(jsonEncode(headerJson));
      final headerLenBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, headerBytes.length, Endian.little);

      const bytesPerSample = 5 * 8;
      final samplesBytes = Uint8List(ecg.length * bytesPerSample);
      final bd = ByteData.view(samplesBytes.buffer);
      for (int s = 0; s < ecg.length; s++) {
        final base = s * bytesPerSample;
        bd.setFloat64(base + 0, ecg[s], Endian.little);
        bd.setFloat64(base + 8, 0.0, Endian.little);
        bd.setFloat64(base + 16, 0.0, Endian.little);
        bd.setFloat64(base + 24, 0.0, Endian.little);
        bd.setFloat64(base + 32, 0.0, Endian.little);
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final recordsDir = Directory(
        p.join(docsDir.path, 'HolterSync', 'Records'),
      );
      if (!await recordsDir.exists()) await recordsDir.create(recursive: true);
      final savePath = p.join(
        recordsDir.path,
        'recording_${const Uuid().v4()}.bin',
      );
      await File(
        savePath,
      ).writeAsBytes(headerLenBytes + headerBytes + samplesBytes);

      // Insert DB row
      final db = Provider.of<AppDatabase>(context, listen: false);
      final patient = defaultPatient;
      if (patient != null && patient['id'] != null) {
        await db
            .into(db.recordings)
            .insert(
              RecordingsCompanion(
                patientId: drift.Value(patient['id'] as int),
                filePath: drift.Value(savePath),
                createdAt: drift.Value(DateTime.now()),
                recordedAt: drift.Value(DateTime.now()),
              ),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Holter imported and saved.')),
        );
        setState(() {
          _isImportingHolter = false;
          _holterImportProgress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import holter: $e')));
        setState(() => _isImportingHolter = false);
      }
    }
  }

  // Import an existing .bin by path and feed ECG-only to graph
  Future<void> importBinFileFromPath(String path) async {
    try {
      final file = File(path);
      importedFile = file;
      final bytes = await file.readAsBytes();
      if (bytes.length < 4) return;

      final headerLen = ByteData.sublistView(
        bytes,
        0,
        4,
      ).getUint32(0, Endian.little);
      if (headerLen <= 0 || headerLen > 8192) return;
      final sampleData = bytes.sublist(4 + headerLen);

      const bytesPerSample = 5 * 8;
      final sampleCount = sampleData.length ~/ bytesPerSample;

      // Set patient info if present
      final jsonBytes = bytes.sublist(4, 4 + headerLen);
      final patient = jsonDecode(utf8.decode(jsonBytes));
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('default_patient', jsonEncode(patient));
      Provider.of<DefaultPatientModal>(
        context,
        listen: false,
      ).setDefault(patient);

      // Prime filter engine with ECG-only
      for (int i = 0; i < sampleCount; i++) {
        final start = i * bytesPerSample;
        final bd = ByteData.sublistView(
          sampleData,
          start,
          start + bytesPerSample,
        );
        final ecg = bd.getFloat64(0, Endian.little);
        myBigGraphKey.currentState?.updateEverythingWithoutGraph([ecg]);
      }

      setState(() {
        importProgressPercent = 1.0;
        isImported = true;
      });

      await getSamplesFromFile(currentImportDisplayIndex.toInt());
    } catch (_) {}
  }

  Future<void> getSamplesFromFile(
    int index, {
    int seconds = 20,
    int samplingRate = 300,
  }) async {
    if (importedFile == null) return;
    const bytesPerSample = 5 * 8;
    final bytes = await importedFile!.readAsBytes();
    if (bytes.length < 4) return;

    final headerLen = ByteData.sublistView(
      bytes,
      0,
      4,
    ).getUint32(0, Endian.little);
    if (headerLen <= 0 || headerLen > 8192) return;

    final sampleData = bytes.sublist(4 + headerLen);
    final sampleCount = sampleData.length ~/ bytesPerSample;

    int startIndex = index;
    int count = seconds * samplingRate;
    int endIndex = (startIndex + count).clamp(0, sampleCount);

    for (int i = startIndex; i < endIndex; i++) {
      final start = i * bytesPerSample;
      final bd = ByteData.sublistView(
        sampleData,
        start,
        start + bytesPerSample,
      );
      final ecg = bd.getFloat64(0, Endian.little);
      myBigGraphKey.currentState?.updateEverything([ecg]);
    }
  }

  Future<void> _runHolterFromRecordingId(int recordingId) async {
    try {
      final db = Provider.of<AppDatabase>(context, listen: false);
      await _holter.initWithRecordingId(db, recordingId);
      _totalSamples = await _holter.getTotalEcgSamples();
      // ignore: avoid_print
      print("Holter samples: $_totalSamples");
      // optional: warm up filters minimally
      final warm = await _holter.getEcgSamples(0, 1000);
      for (final v in warm) {
        myBigGraphKey.currentState?.updateEverythingWithoutGraph([v]);
      }
      if (mounted) setState(() {}); // refresh to show stats
    } catch (e, st) {
      // ignore: avoid_print
      print('Holter analysis failed: $e');
      // ignore: avoid_print
      print(st);
    }
  }

  Future<void> _loadPage(int pageIndex) async {
    if (_totalSamples <= 0) return;
    if (pageIndex < 0) return;
    final startSample = pageIndex * samplesPerPage;
    if (startSample >= _totalSamples) return;

    // Fetch page worth of samples
    final length =
        (startSample + samplesPerPage <= _totalSamples)
            ? samplesPerPage
            : (_totalSamples - startSample);
    final data = await _holter.getEcgSamples(startSample, length);
    // Split into 10 rows of up to 9000 samples
    List<List<double>> rows = [];
    for (int r = 0; r < rowsPerPage; r++) {
      final rs = r * samplesPerRow;
      final re =
          (rs + samplesPerRow <= data.length)
              ? (rs + samplesPerRow)
              : data.length;
      if (rs >= data.length) {
        rows.add(const <double>[]);
      } else {
        rows.add(data.sublist(rs, re));
      }
    }

    // Ensure the graph is configured with 10 channels (one per row)
    if (plotConfig.length != rowsPerPage) {
      plotConfig
        ..clear()
        ..addAll(
          List.generate(
            rowsPerPage,
            (i) => {
              "name": "ECG ${i + 1}",
              "boxValue": 4096 / 12,
              "unit": "mV",
              "minDisplay": (-4096 / 12) * 3,
              "maxDisplay": (4096 / 12) * 3,
              "scale": 3,
              "gain": 1.0,
              "filterConfig": {
                "filterOn": true,
                "lpf": 3,
                "hpf": 5,
                "notch": 1,
              },
              "meter": {"decimal": 1, "unit": "mV", "convert": (double x) => x},
            },
          ),
        );
      setState(() {});
    }

    // Render page
    myBigGraphKey.currentState?.renderMultiRowPage(rows);

    setState(() {
      _currentPage = pageIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Toolbar
            Container(
              alignment: Alignment.center,
              color: Colors.blue.shade700,
              height: 70,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButtonColumn(
                      icon: Icons.save_alt,
                      label: "Load Data",
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RecordingsListPage(),
                          ),
                        );
                      },
                    ),
                    IconButtonColumn(
                      icon: Icons.upload_file,
                      label:
                          _isImportingHolter
                              ? "Importing ${(100 * _holterImportProgress).toStringAsFixed(0)}%"
                              : "Load New Holter",
                      onPressed: () {
                        if (_isImportingHolter) return;
                        _importNewHolterFile();
                      },
                    ),
                    IconButtonColumn(
                      icon: Icons.settings,
                      label: 'Settings',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GlobalSettings(),
                          ),
                        );
                      },
                    ),
                    IconButtonColumn(
                      icon: Icons.people,
                      label: 'Patients',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PatientsList(),
                          ),
                        );
                      },
                    ),
                    IconButtonColumn(
                      icon: Icons.person_add,
                      label: 'Add Patient',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => PatientAdd()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: MyBigGraphV2(
                    key: myBigGraphKey,
                    isImported: true,
                    onCycleComplete: () {},
                    streamConfig: const [],
                    onStreamResult: (_) {},
                    plot:
                        plotConfig.length == 1
                            ? plotConfig
                            : plotConfig, // will be 10 rows after first page load
                    windowSize: samplesPerRow, // 30 sec @ 300 Hz per row
                    verticalLineConfigs: [
                      {
                        'seconds': 0.5,
                        'stroke': 0.5,
                        'color': Colors.blueAccent.withOpacity(0.2),
                      },
                      {
                        'seconds': 1.0,
                        'stroke': 0.8,
                        'color': Colors.redAccent.withOpacity(0.2),
                      },
                    ],
                    horizontalInterval: 4096 / 12,
                    verticalInterval: 8,
                    samplingRate: 300,
                    minY: -(4096 / 12) * 5,
                    maxY: (4096 / 12) * 25,
                  ),
                ),
                Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _totalPages > 0
                            ? 'Page ${_currentPage + 1} / $_totalPages'
                            : 'Page -- / --',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentPageTimeRangeText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            tooltip: 'Previous Page',
                            onPressed:
                                (_currentPage > 0)
                                    ? () async {
                                      await _loadPage(_currentPage - 1);
                                    }
                                    : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            tooltip: 'Next Page',
                            onPressed:
                                (_totalPages == 0 ||
                                        _currentPage >= _totalPages - 1)
                                    ? null
                                    : () async {
                                      await _loadPage(_currentPage + 1);
                                    },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stats boxes from HolterReportGenerator
                      _statBox(
                        'Avg BPM',
                        (_holter.avrBpm > 0)
                            ? _holter.avrBpm.toStringAsFixed(1)
                            : '--',
                      ),
                      _statBox(
                        'Min BPM',
                        (_holter.minBpm > 0)
                            ? _holter.minBpm.toStringAsFixed(1)
                            : '--',
                      ),
                      _statBox(
                        'Max BPM',
                        (_holter.maxBpm > 0)
                            ? _holter.maxBpm.toStringAsFixed(1)
                            : '--',
                      ),
                      _statBox(
                        'R-peaks',
                        (_holter.allRrIndexes.isNotEmpty)
                            ? _holter.allRrIndexes.length.toString()
                            : '--',
                      ),
                      if (_holter.conditions != null &&
                          _holter.conditions is List &&
                          (_holter.conditions as List).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Conditions',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        for (final cond in (_holter.conditions as List).take(3))
                          _statBox(
                            '${cond['name']}',
                            (cond['index'] is List)
                                ? (cond['index'] as List).length.toString()
                                : '0',
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
