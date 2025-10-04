import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:holtersync/Pages/GlobalSettings.dart';
import 'package:holtersync/Pages/AI/AiInterpretationTab.dart';
import 'package:holtersync/Pages/RecordingsListPage.dart';
import 'package:holtersync/Pages/patient/list.dart';
import 'package:holtersync/Pages/patient/patientAdd.dart';
import 'package:holtersync/ProviderModals/DefaultPatientModal.dart';
import 'package:holtersync/ProviderModals/ImportFileProvider.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';
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
  final GlobalKey<MyBigGraphV2State> detailGraphKey = GlobalKey();
  final HolterReportGenerator _holter = HolterReportGenerator();
  TabController? _tabController;

  // Paging: 20 rows x 60 seconds each
  static const int rowsPerPage = 30;
  static const int secondsPerRow = 60;
  static const int sr = 300; // base sampling rate for all calculations
  static const int samplesPerRow = secondsPerRow * sr; // 18,000 per row
  static const int displaySrTop = 60; // overview fetch rate
  static const int samplesPerRowTop = secondsPerRow * displaySrTop; // 3,600
  static const int samplesPerPage =
      rowsPerPage * samplesPerRow; // page measured in base samples
  int _currentPage = 0;
  int _totalSamples = 0;
  List<List<double>>?
  _lastRows; // cache of last rendered rows for quick refresh
  // Detail graph state
  int? _selectedRowIndex; // 0..rowsPerPage-1
  List<double> _detailData = const [];

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
      "minDisplay": -(4096 / 12) * 0.5,
      "maxDisplay": (4096 / 12) * 0.5,
      "scale": 3,
      "gain": 1.0,
      "filterConfig": {"filterOn": false, "lpf": 3, "hpf": 5, "notch": 1},
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
  // AI running state now managed inside AiInterpretationTab
  bool _progressDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attach TabController listener after first frame when DefaultTabController is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachTabControllerIfAvailable();
    });
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

  void _attachTabControllerIfAvailable() {
    try {
      final tc = DefaultTabController.of(context);
      if (!identical(_tabController, tc)) {
        _tabController?.removeListener(_onTabChanged);
        _tabController = tc;
        _tabController!.addListener(_onTabChanged);
      }
    } catch (_) {
      // DefaultTabController not found yet; will try again on next frame/build
    }
  }

  void _onTabChanged() {
    // Only act when the animation/gesture has ended
    if (_tabController == null || _tabController!.indexIsChanging) return;
    // If switched back to Viewer tab (index 0), ensure graph content is visible immediately
    if (_tabController!.index == 0) {
      // If plotConfig lost its 10-channel setup (hot reload or earlier state), restore
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
                "minDisplay": -(4096 / 12) * 0.5,
                "maxDisplay": (4096 / 12) * 0.5,
                "scale": 3,
                "gain": 1.0,
                "filterConfig": {
                  "filterOn": false,
                  "lpf": 3,
                  "hpf": 5,
                  "notch": 1,
                },
                "meter": {
                  "decimal": 1,
                  "unit": "mV",
                  "convert": (double x) => x,
                },
              },
            ),
          );
        setState(() {});
        // Schedule render after rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (_lastRows != null && _lastRows!.isNotEmpty) {
            myBigGraphKey.currentState?.renderMultiRowPage(_lastRows!);
          } else {
            await _loadPage(_currentPage);
          }
        });
      } else {
        // Re-render existing data to force paint if needed, otherwise reload current page
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (_lastRows != null && _lastRows!.isNotEmpty) {
            myBigGraphKey.currentState?.renderMultiRowPage(_lastRows!);
          } else {
            await _loadPage(_currentPage);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
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
    final db = Provider.of<AppDatabase>(context, listen: false);
    final ValueNotifier<String> msg = ValueNotifier<String>(
      'Starting analysis…',
    );
    try {
      // Show a blocking progress dialog while initializing (can take time)
      _showBlockingProgressDialog(
        title: 'Preparing recording',
        message:
            'Please wait while we load and analyze the data...\n(This may take a minute)',
        messageListenable: msg,
      );

      // Run heavy analysis off the UI thread
      await _holter.initWithRecordingIdOnBackground(
        db,
        recordingId,
        onProgress: (p, stage) {
          final pct = (p * 100).clamp(0, 100).toStringAsFixed(0);
          msg.value = '$pct% • $stage';
        },
      );

      _totalSamples = await _holter.getTotalEcgSamples();
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load recording: $e')));
      }
    } finally {
      // Ensure we close the progress dialog
      _closeBlockingProgressDialog();
    }
  }

  void _showBlockingProgressDialog({
    String title = 'Loading',
    String message = 'Please wait...',
    ValueListenable<String>? messageListenable,
  }) {
    _progressDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 12),
                if (messageListenable != null)
                  ValueListenableBuilder<String>(
                    valueListenable: messageListenable,
                    builder:
                        (_, value, __) => Text(
                          value,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                  )
                else
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeBlockingProgressDialog() {
    if (!_progressDialogOpen) return;
    if (!mounted) {
      _progressDialogOpen = false;
      return;
    }
    // Try to pop the dialog route explicitly (not maybePop)
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {
      // ignore if already closed
    } finally {
      _progressDialogOpen = false;
    }
  }

  // AI run logic moved into AiInterpretationTab

  Widget _buildTopToolbar() {
    return Container(
      alignment: Alignment.centerLeft,
      color: Colors.blue.shade700,
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                'HolterSync',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _toolbarButton(
              icon: Icons.save_alt,
              label: 'Load Data',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => RecordingsListPage()),
                );
              },
            ),
            _toolbarButton(
              icon: Icons.upload_file,
              label:
                  _isImportingHolter
                      ? 'Importing ${(100 * _holterImportProgress).toStringAsFixed(0)}%'
                      : 'Load New Holter',
              onPressed: () {
                if (_isImportingHolter) return;
                _importNewHolterFile();
              },
            ),
            _toolbarButton(
              icon: Icons.settings,
              label: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => GlobalSettings()),
                );
              },
            ),
            _toolbarButton(
              icon: Icons.people,
              label: 'Patients',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => PatientsList()));
              },
            ),
            _toolbarButton(
              icon: Icons.person_add,
              label: 'Add Patient',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (context) => PatientAdd()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildViewerTab() {
    // Layout: a single Row: [left: graphs column], [right: stats]
    // Inside left, a Column with top (smaller) overview graph and bottom (bigger) detail graph.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: stacked graphs
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
            child: Column(
              children: [
                // Top overview graph (smaller)
                MyBigGraphV2(
                  lineStrokeWidth: 0.5,
                  key: myBigGraphKey,
                  showXAxisLabels: false,
                  showYAxisLabels: false,
                  isImported: true,
                  onCycleComplete: () {},
                  streamConfig: const [],
                  onStreamResult: (_) {},
                  plot:
                      plotConfig.length == 1
                          ? plotConfig
                          : plotConfig, // will be 10 rows after first page load
                  // Use 60Hz overview size for better readability
                  windowSize: samplesPerRowTop,
                  verticalLineConfigs: [
                    // {
                    //   'seconds': 0.5,
                    //   'stroke': 0.5,
                    //   'color': Colors.blueAccent.withOpacity(0.2),
                    // },
                    // {
                    //   'seconds': 1.0,
                    //   'stroke': 0.8,
                    //   'color': Colors.redAccent.withOpacity(0.2),
                    // },
                  ],
                  horizontalInterval: 4096 / 12,
                  verticalInterval: 8,
                  samplingRate: 300,
                  minY: -(4096 / 12) * 5,
                  maxY: (4096 / 12) * 25,
                  chartHeight: 480, // further increased height for overview
                  showLeftConsole: false,
                  onRowTap: (rowIdx) async {
                    // Map row tap to the absolute sample range for that row on current page
                    if (_totalSamples <= 0) return;
                    final startSample = _currentPage * samplesPerPage;
                    final rowStart = startSample + rowIdx * samplesPerRow;
                    final rowLen =
                        ((rowStart + samplesPerRow) <= _totalSamples)
                            ? samplesPerRow
                            : (_totalSamples - rowStart);
                    if (rowLen <= 0) return;
                    // Fetch full-resolution (filtered + baseline-corrected) for detail view
                    final data = await _holter.getEcgSamples(rowStart, rowLen);
                    if (!mounted) return;
                    setState(() {
                      _selectedRowIndex = rowIdx;
                      _detailData = data;
                    });
                    // Render in detail graph (single channel) after widget mounts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final rows = <List<double>>[data];
                      detailGraphKey.currentState?.renderMultiRowPage(rows);
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (_detailData.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6.0, left: 2.0),
                      child: Text(
                        _selectedRowIndex != null
                            ? 'Expanded view: Row ${_selectedRowIndex! + 1} (60s)'
                            : 'Expanded view',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                // Bottom detail graph (bigger) - visible when data loaded
                Expanded(
                  child: Container(
                    alignment: Alignment.topLeft,
                    child:
                        _detailData.isNotEmpty
                            ? MyBigGraphV2(
                              showLeftConsole: false,
                              showXAxisLabels: false,
                              showYAxisLabels: false,
                              key: detailGraphKey,
                              isImported: true,
                              onCycleComplete: () {},
                              streamConfig: const [],
                              onStreamResult: (_) {},
                              plot: [
                                {
                                  "name": "ECG (detail)",
                                  "boxValue": 4096 / 12,
                                  "unit": "mV",
                                  "minDisplay": -(4096 / 12) * 3,
                                  "maxDisplay": (4096 / 12) * 3,
                                  "scale": 3,
                                  "gain": 1.0,
                                  "filterConfig": {
                                    "filterOn": false,
                                    "lpf": 3,
                                    "hpf": 5,
                                    "notch": 1,
                                  },
                                  "meter": {
                                    "decimal": 1,
                                    "unit": "mV",
                                    "convert": null,
                                  },
                                },
                              ],
                              // Detail remains full resolution at 300Hz per row
                              windowSize: samplesPerRow,
                              enableHorizontalScroll: true,
                              pixelsPerSample: 0.5,
                              verticalLineConfigs: [
                                // {
                                //   'seconds': 0.05,
                                //   'stroke': 0.5,
                                //   'color': Colors.blueAccent,
                                // },
                                {
                                  'seconds': 0.25,
                                  'stroke': 0.5,
                                  'color': Colors.blueAccent,
                                },
                                {
                                  'seconds': 0.5,
                                  'stroke': 0.5,
                                  'color': Colors.blueAccent,
                                },
                                {
                                  'seconds': 1.0,
                                  'stroke': 0.8,
                                  'color': Colors.redAccent,
                                },
                              ],
                              horizontalInterval: 4096 / 12,
                              verticalInterval: 8,
                              samplingRate: 300,
                              minY: -(4096 / 12) * 5,
                              maxY: (4096 / 12) * 25,
                              chartHeight:
                                  300, // further decreased height for detail
                            )
                            : Center(
                              child: Text(
                                'Tap a row above to view details',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right-side panel with page/time, navigation, and stats
        Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                style: const TextStyle(fontSize: 12, color: Colors.black87),
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
                        (_totalPages == 0 || _currentPage >= _totalPages - 1)
                            ? null
                            : () async {
                              await _loadPage(_currentPage + 1);
                            },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statBox(
                'Avg BPM',
                (_holter.avrBpm > 0) ? _holter.avrBpm.toStringAsFixed(1) : '--',
              ),
              _statBox(
                'Min BPM',
                (_holter.minBpm > 0) ? _holter.minBpm.toStringAsFixed(1) : '--',
              ),
              _statBox(
                'Max BPM',
                (_holter.maxBpm > 0) ? _holter.maxBpm.toStringAsFixed(1) : '--',
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
    );
  }

  Widget _buildAiTab() => AiInterpretationTab(holter: _holter);

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
    // Fetch full-resolution data for this page for detail
    final data = await _holter.getEcgSamples(startSample, length);
    List<List<double>> rows = [];
    List<List<double>> rowsTop = [];
    for (int r = 0; r < rowsPerPage; r++) {
      final rs = r * samplesPerRow;
      final re =
          (rs + samplesPerRow <= data.length)
              ? (rs + samplesPerRow)
              : data.length;
      if (rs >= data.length) {
        rows.add(const <double>[]);
        rowsTop.add(const <double>[]);
      } else {
        final baseRow = data.sublist(rs, re);
        rows.add(baseRow);
        // Build 60Hz row via stride pick just for rendering; values are already filtered per-page
        final stride = sr ~/ displaySrTop; // 5
        final reduced = <double>[];
        for (int i = 0; i < baseRow.length; i += stride) {
          reduced.add(baseRow[i]);
        }
        rowsTop.add(reduced);
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
              // "minDisplay": (-4096 / 12) * 1,
              "minDisplay": -(4096 / 12) * 0.5,
              "maxDisplay": (4096 / 12) * 0.5,
              "scale": 3,
              "gain": 1.0,
              "filterConfig": {
                "filterOn": false,
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

    // Render page and update current page
    _lastRows = rows; // keep full-res cached for detail
    // Render overview using 60Hz rows
    myBigGraphKey.currentState?.renderMultiRowPage(rowsTop);
    setState(() {
      _currentPage = pageIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          title: null,
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44 + 3 + 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopToolbar(),
                const SizedBox(height: 2),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: Colors.blue.shade700,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: Colors.blue.shade700,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Viewer'),
                      Tab(text: 'AI interpretation'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _KeepAlive(child: _buildViewerTab()),
            _KeepAlive(child: _buildAiTab()),
          ],
        ),
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({Key? key, required this.child}) : super(key: key);
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
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
