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
import 'package:holtersync/Pages/HRV/HrvAnalysisTab.dart';
import 'package:holtersync/Pages/RecordingsListPage.dart';
import 'package:holtersync/Pages/patient/list.dart';
import 'package:holtersync/Pages/patient/patientAdd.dart';
import 'package:holtersync/ProviderModals/DefaultPatientModal.dart';
import 'package:holtersync/ProviderModals/ImportFileProvider.dart';
import 'package:holtersync/Services/HolterReportGenerator.dart';
import 'package:holtersync/Widgets/MyBigGraphScrollable.dart';
import 'package:holtersync/ReportPreviewLite.dart';
import 'package:holtersync/data/local/database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Prefetched page payload for instant navigation
class _PrefetchedPage {
  final int pageIndex;
  final int startSample;
  final int length;
  final List<List<double>> rowsFull; // 300 Hz full-res for detail
  final List<List<double>> rowsTop; // 60 Hz for overview painting
  final List<List<Map<String, int>>> highlights; // overview highlights per row (60 Hz)
  const _PrefetchedPage({
    required this.pageIndex,
    required this.startSample,
    required this.length,
    required this.rowsFull,
    required this.rowsTop,
    required this.highlights,
  });
}

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
  // Per-row highlight ranges for current page (one list per row)
  List<List<Map<String, int>>> _pageRowHighlights = const [];
  // Highlight ranges for the detail graph (list of {start,end} local indices)
  final ValueNotifier<List<Map<String, int>>> _detailHighlightRanges =
      ValueNotifier<List<Map<String, int>>>([]);
  // Notifier for overview (top) chart per-row highlight ranges at 60 Hz
  final ValueNotifier<List<List<Map<String, int>>>> _pageHighlightsVN =
      ValueNotifier<List<List<Map<String, int>>>>(
        List.generate(rowsPerPage, (_) => <Map<String, int>>[]),
      );

  final Map<int, _PrefetchedPage> _pageCache = <int, _PrefetchedPage>{};
  final Map<int, Future<_PrefetchedPage>> _prefetching = <int, Future<_PrefetchedPage>>{};
  static const int _maxCachePages = 5;
  void _trimCacheKeep(int keepPage) {
    while (_pageCache.length > _maxCachePages) {
      // Remove the oldest entry that's not the current page
      final toRemove = _pageCache.keys.firstWhere(
        (k) => k != keepPage,
        orElse: () => _pageCache.keys.first,
      );
      _pageCache.remove(toRemove);
    }
  }

  bool _isValidPage(int page) => page >= 0 && page < _totalPages;

  Future<_PrefetchedPage> _buildPageData(int pageIndex) async {
    final startSample = pageIndex * samplesPerPage;
    final int length = (startSample + samplesPerPage <= _totalSamples)
        ? samplesPerPage
        : (_totalSamples - startSample);

    final data = await _holter.getEcgSamples(startSample, length);
    final rowsFull = <List<double>>[];
    final rowsTop = <List<double>>[];
    for (int r = 0; r < rowsPerPage; r++) {
      final rs = r * samplesPerRow;
      final re = (rs + samplesPerRow <= data.length) ? (rs + samplesPerRow) : data.length;
      if (rs >= data.length) {
        rowsFull.add(const <double>[]);
        rowsTop.add(const <double>[]);
      } else {
        final baseRow = data.sublist(rs, re);
        rowsFull.add(baseRow);
        final stride = sr ~/ displaySrTop; // e.g., 5
        final reduced = <double>[];
        for (int i = 0; i < baseRow.length; i += stride) {
          reduced.add(baseRow[i]);
        }
        rowsTop.add(reduced);
      }
    }
    final highlights = _buildPageRowHighlights(startSample, length);
    return _PrefetchedPage(
      pageIndex: pageIndex,
      startSample: startSample,
      length: length,
      rowsFull: rowsFull,
      rowsTop: rowsTop,
      highlights: highlights,
    );
  }

  void _prefetchPage(int pageIndex) {
    if (!_isValidPage(pageIndex)) return;
    if (_pageCache.containsKey(pageIndex)) return;
    if (_prefetching.containsKey(pageIndex)) return;
    final fut = _buildPageData(pageIndex).then((p) {
      _pageCache[pageIndex] = p;
      _trimCacheKeep(_currentPage);
      _prefetching.remove(pageIndex);
      return p;
    }).catchError((e) {
      _prefetching.remove(pageIndex);
      return Future<_PrefetchedPage>.error(e);
    });
    _prefetching[pageIndex] = fut;
  }

  int get _totalPages =>
      _totalSamples > 0
          ? ((_totalSamples + samplesPerPage - 1) ~/ samplesPerPage)
          : 0;

  // Fixed color mapping for condition names used in highlights and legend
  Color _conditionColor(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('tachy')) return Colors.redAccent;
    if (n.contains('brady')) return Colors.blueAccent;
    if (n == 'svt' || n.contains('supraventricular')) return Colors.purple;
    if (n.contains('pause')) return Colors.orange;
    if (n.contains('af') || n.contains('atrial fib')) return Colors.teal;
    // pvc
    if (n.contains('pvc')) return Colors.blue.shade700;
    return Colors.amber.shade700; // default
  }

  String _formatSeconds(double seconds) {
    final total = seconds.floor();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  // Build contiguous highlight ranges inside the selected 60s row for any detected conditions
  void _updateDetailHighlights({required int rowStart, required int rowLen}) {
    final conds = _holter.conditions;
    if (conds is! List || conds.isEmpty) {
      _detailHighlightRanges.value = const [];
      return;
    }
    final int rowEnd = rowStart + rowLen; // exclusive
    // Build colored highlight ranges per condition
    const int pad = 45; // 150ms at 300Hz
    final List<Map<String, int>> coloredRanges = [];
    for (final c in conds) {
      if (c is! Map) continue;
      final name = c['name'] as String?;
      final colorInt = _conditionColor(name).value;
      final idxList = c['index'];
      if (idxList is! List) continue;
      for (final g in idxList) {
        if (g is! int) continue;
        if (g < rowStart || g >= rowEnd) continue;
        final local = g - rowStart;
        final int s = (local - pad).clamp(0, rowLen - 1);
        final int e = (local + pad).clamp(0, rowLen - 1);
        coloredRanges.add({'start': s, 'end': e, 'color': colorInt});
      }
    }
    _detailHighlightRanges.value = coloredRanges;
  }

  // Build per-row highlight ranges for the entire current page from global condition indices
  List<List<Map<String, int>>> _buildPageRowHighlights(
    int pageStartSample,
    int pageLength,
  ) {
    final result = List.generate(rowsPerPage, (_) => <Map<String, int>>[]);
    final conds = _holter.conditions;
    if (conds is! List || conds.isEmpty) return result;

    final int pageEnd = pageStartSample + pageLength; // exclusive
    // For each condition, collect per-row points and create colored ranges
    const int pad = 45; // ~150ms
    for (final c in conds) {
      if (c is! Map) continue;
      final name = c['name'] as String?;
      final colorInt = _conditionColor(name).value;
      final idxList = c['index'];
      if (idxList is! List) continue;
      // per-row points for this condition
      final List<Set<int>> perRowPoints = List.generate(
        rowsPerPage,
        (_) => <int>{},
      );
      for (final g in idxList) {
        if (g is! int) continue;
        if (g < pageStartSample || g >= pageEnd) continue;
        final rel = g - pageStartSample;
        final row = rel ~/ samplesPerRow;
        final local = rel % samplesPerRow;
        if (row >= 0 && row < rowsPerPage) perRowPoints[row].add(local);
      }
      // Expand and scale per row for this condition, then append to result
      for (int r = 0; r < rowsPerPage; r++) {
        if (perRowPoints[r].isEmpty) continue;
        final points = perRowPoints[r].toList()..sort();
        final ranges = <Map<String, int>>[];
        for (final p in points) {
          final s = (p - pad).clamp(0, samplesPerRow - 1);
          final e = (p + pad).clamp(0, samplesPerRow - 1);
          ranges.add({'start': s, 'end': e, 'color': colorInt});
        }
        // Scale to 60 Hz overview
        final stride = sr ~/ displaySrTop; // 5
        for (final m in ranges) {
          int ss = (m['start']! / stride).floor();
          int ee = (m['end']! / stride).ceil();
          if (ss < 0) ss = 0;
          if (ee >= samplesPerRowTop) ee = samplesPerRowTop - 1;
          if (ee >= ss)
            result[r].add({'start': ss, 'end': ee, 'color': colorInt});
        }
      }
    }
    return result;
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
  // Better progress: cancel + ETA
  bool _cancelImport = false;
  DateTime? _importStart;
  String _importEtaLabel = '';
  DateTime? _lastImportUiTick;

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
      _cancelImport = false;
      _importEtaLabel = '';
      _importStart = DateTime.now();
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
      if (_cancelImport) {
        if (mounted) {
          setState(() {
            _isImportingHolter = false;
            _importEtaLabel = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import canceled.')),
          );
        }
        return;
      }

      // Decode ECG from raw (0x55 0xAA frames: 25 samples per frame, stride 8)
      final List<double> ecg = <double>[];
      int i = 0;
      while (i < raw.length - 1) {
        if (_cancelImport) {
          if (mounted) {
            setState(() {
              _isImportingHolter = false;
              _holterImportProgress = 0.0;
              _importEtaLabel = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Import canceled.')),
            );
          }
          return;
        }
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
          // compute ETA based on elapsed and progress
          if (_importStart != null && _holterImportProgress > 0.0) {
            final now = DateTime.now();
            final elapsed = now.difference(_importStart!);
            final remainingFraction = (1.0 - _holterImportProgress) / _holterImportProgress;
            final eta = Duration(milliseconds: (elapsed.inMilliseconds * remainingFraction).round());
            _importEtaLabel = _formatEta(eta);
            // Throttle UI updates to ~20fps
            if (_lastImportUiTick == null || now.difference(_lastImportUiTick!).inMilliseconds >= 50) {
              _lastImportUiTick = now;
              if (mounted) setState(() {});
            }
          } else {
            if (mounted) setState(() {});
          }
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
          _importEtaLabel = '';
          _cancelImport = false;
          _importStart = null;
          _lastImportUiTick = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to import holter: $e')));
        setState(() {
          _isImportingHolter = false;
          _importEtaLabel = '';
          _cancelImport = false;
          _importStart = null;
          _lastImportUiTick = null;
        });
      }
    }
  }

  String _formatEta(Duration d) {
    if (d.isNegative) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s left';
    }
    if (m > 0) {
      return '${m}m ${s.toString().padLeft(2, '0')}s left';
    }
    return '${s}s left';
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
                      ? 'Importing ${(100 * _holterImportProgress).toStringAsFixed(0)}%${_importEtaLabel.isNotEmpty ? ' • ' + _importEtaLabel : ''}'
                      : 'Load New Holter',
              onPressed: () {
                if (_isImportingHolter) return;
                _importNewHolterFile();
              },
            ),
            if (_isImportingHolter)
              _toolbarButton(
                icon: Icons.close,
                label: 'Cancel Import',
                onPressed: () {
                  if (!_isImportingHolter) return;
                  setState(() {
                    _cancelImport = true;
                  });
                },
              ),
            if (_totalSamples > 0)
              _toolbarButton(
                icon: Icons.picture_as_pdf,
                label: 'Report',
                onPressed: () {
                  // Build minimal patient and recording info for report headers
                  final patient = Provider.of<DefaultPatientModal>(
                    context,
                    listen: false,
                  ).patient ?? <String, dynamic>{};
                  final totalSec = (_totalSamples / sr).floor();
                  String two(int n) => n.toString().padLeft(2, '0');
                  final dur = '${two(totalSec ~/ 3600)}:${two((totalSec % 3600) ~/ 60)}:${two(totalSec % 60)}';
                  final info = <String, dynamic>{
                    'Samples': _totalSamples,
                    'Sample Rate': '$sr Hz',
                    'Duration': dur,
                    if (_holter.fileName != null && _holter.fileName!.isNotEmpty)
                      'File': _holter.fileName,
                  };
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportPreviewPageLite(
                        patient: patient,
                        title: 'Holter Report',
                        recordedAt: DateTime.now(),
                        recordingInfo: info,
                        holter: _holter,
                      ),
                    ),
                  );
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
                  channelHighlightRanges: _pageHighlightsVN,
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
                    // Compute highlight ranges for selected 60s row
                    _updateDetailHighlights(rowStart: rowStart, rowLen: rowLen);
                    // Render in detail graph (single channel) after widget mounts
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final rows = <List<double>>[data];
                      detailGraphKey.currentState?.renderMultiRowPage(rows);
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Legend mapping colors to condition names
                _conditionsLegend(),
                const SizedBox(height: 4),
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
                              highlightRanges: _detailHighlightRanges,
                              highlightColor: Colors.redAccent,
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
              // Show AI progress while running (between 0% and 100%)
              ValueListenableBuilder<String>(
                valueListenable: _holter.progress,
                builder: (context, value, _) {
                  final t = value.trim();
                  final isStart = t == '0.00%';
                  final isDone = t == '100.00%';
                  if (isStart || isDone) return const SizedBox(height: 0);
                  double? pct;
                  try {
                    pct = double.parse(t.replaceAll('%', '')) / 100.0;
                  } catch (_) {
                    pct = null;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'AI Interpretation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.black12,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Progress: $t',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
              // Stats boxes
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

  // Small legend row showing which color corresponds to which detected condition
  Widget _conditionsLegend() {
    final conds = _holter.conditions;
    if (conds is! List || conds.isEmpty) return const SizedBox.shrink();
    final names = <String>{};
    for (final c in conds) {
      if (c is Map && c['name'] is String) {
        final n = (c['name'] as String).trim();
        if (n.isNotEmpty) names.add(n);
      }
    }
    if (names.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 10,
          runSpacing: 4,
          children: names.map((n) => _legendItem(n)).toList(),
        ),
      ),
    );
  }

  Widget _legendItem(String name) {
    final color = _conditionColor(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAiTab() => AiInterpretationTab(holter: _holter);

  Future<void> _loadPage(int pageIndex) async {
    if (_totalSamples <= 0) return;
    if (pageIndex < 0) return;
    final startSample = pageIndex * samplesPerPage;
    if (startSample >= _totalSamples) return;

    // Use cache if available or prefetching future if in-flight
    _PrefetchedPage pageData;
    if (_pageCache.containsKey(pageIndex)) {
      pageData = _pageCache[pageIndex]!;
    } else if (_prefetching.containsKey(pageIndex)) {
      pageData = await _prefetching[pageIndex]!;
    } else {
      pageData = await _buildPageData(pageIndex);
      _pageCache[pageIndex] = pageData;
      _trimCacheKeep(pageIndex);
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

    // Render page and update current page from prefetched data
    _lastRows = pageData.rowsFull; // keep full-res cached for detail
    _pageRowHighlights = pageData.highlights;
    _pageHighlightsVN.value = _pageRowHighlights;
    myBigGraphKey.currentState?.renderMultiRowPage(pageData.rowsTop);
    setState(() {
      _currentPage = pageIndex;
    });

    // Prefetch neighbors in the background
    _prefetchPage(pageIndex - 1);
    _prefetchPage(pageIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                      Tab(text: 'HRV analysis'),
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
            _KeepAlive(child: HrvAnalysisTab(holter: _holter)),
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
