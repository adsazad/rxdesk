import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class Utility {
  String getAvailableFilePath(
    String basePath,
    String baseName,
    String extension,
  ) {
    int counter = 1;
    String filePath = '$basePath/$baseName.$extension';

    while (File(filePath).existsSync()) {
      filePath = '$basePath/$baseName($counter).$extension';
      counter++;
    }

    return filePath;
  }

  Future<void> exportBreathStatsToExcel(Map<String, dynamic> cp) async {
    if (cp['breathStats'] == null || !(cp['breathStats'] is List)) return;

    final breathStats = List<Map<String, dynamic>>.from(cp['breathStats']);
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    // ✅ Custom headers
    final customHeaders = [
      'O%',
      'CO2%',
      'HR',
      'VO2%',
      'VCO2%',
      'VE MINTUE',
      'RER',
      'ESTIMATED CO',
    ];

    for (int i = 0; i < customHeaders.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(customHeaders[i]);
    }

    // Fill data according to the custom order
    for (int r = 0; r < breathStats.length; r++) {
      final row = breathStats[r];
      sheet
          .getRangeByIndex(r + 2, 1)
          .setText(row['o2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 2)
          .setText(row['co2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 3)
          .setText(row['hr']?.toStringAsFixed(0) ?? '');
      sheet
          .getRangeByIndex(r + 2, 4)
          .setText(row['vo2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 5)
          .setText(row['vco2']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 6)
          .setText(row['minuteVentilation']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 7)
          .setText(row['rer']?.toStringAsFixed(2) ?? '');
      sheet
          .getRangeByIndex(r + 2, 8)
          .setText(row['co']?.toStringAsFixed(2) ?? '');
    }

    final dir = await getDownloadsDirectory();
    final path = getAvailableFilePath(dir!.path, 'CPET_breathstats', 'xlsx');
    final bytes = workbook.saveAsStream();
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    workbook.dispose();

    print("✅ Excel exported to: $path");
  }
}
