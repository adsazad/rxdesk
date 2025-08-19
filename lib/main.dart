import 'dart:io';

import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as pvrd;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spirobtvo/ProviderModals/DefaultPatientModal.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';
import 'package:spirobtvo/ProviderModals/ImportFileProvider.dart';
import 'package:spirobtvo/Services/navigatorService.dart';
import 'package:spirobtvo/data/local/database.dart';
import 'package:spirobtvo/home.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    title: 'SpiroBT',
    size: Size(1920, 1080),
    center: true,
    minimumSize: Size(800, 600),
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.maximize();
  });

  HttpOverrides.global = new MyHttpOverrides();

  // Load settings from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  String? settingsJson = prefs.getString("globalSettings");
  GlobalSettingsModal globalSettings;
  if (settingsJson != null) {
    globalSettings = GlobalSettingsModal(
      com: "none",
      autoRecordOnOff: true,
      filterOnOf: true,
      highPass: 5,
      lowPass: 3,
      notch: true,
      gridLine: true,
      sampleRate: '300',
      voltage1: 1.112,
      value1: 20.93,
      voltage2: 0.972,
      value2: 19,
      applyConversion: false,
      tidalMeasuredReference: 0.0,
      tidalActualReference: 0.0,
      tidalScalingFactor: 1.0,
      hospitalName: '',
      hospitalAddress: '',
      hospitalContact: '',
      hospitalEmail: '',
      deviceType: "none",
      machineCom: "none",
      atDetectionMethod: "VO2 max",
      transportDelayMs: 1000,
    );
    globalSettings.fromJson(settingsJson);
  } else {
    globalSettings = GlobalSettingsModal(
      com: "none",
      autoRecordOnOff: true,
      filterOnOf: true,
      highPass: 5,
      lowPass: 3,
      notch: true,
      gridLine: true,
      sampleRate: '300',
      voltage1: 1.112,
      value1: 20.93,
      voltage2: 0.996,
      value2: 19,
      applyConversion: false,
      tidalMeasuredReference: 0.0,
      tidalActualReference: 0.0,
      tidalScalingFactor: 1.0,
      hospitalName: '',
      hospitalAddress: '',
      hospitalContact: '',
      hospitalEmail: '',
      deviceType: "none",
      machineCom: "none",
      atDetectionMethod: "VO2 max",
      transportDelayMs: 1000,
    );
  }

  runApp(
    ProviderScope(
      child: pvrd.MultiProvider(
        providers: [
          pvrd.ChangeNotifierProvider<GlobalSettingsModal>(
            create: (context) => globalSettings,
          ),
          pvrd.ChangeNotifierProvider<DefaultPatientModal>(
            create: (context) => DefaultPatientModal(),
          ),
          pvrd.Provider<AppDatabase>(
            create: (context) => AppDatabase(),
            dispose: (context, db) => db.close(),
          ),
          pvrd.ChangeNotifierProvider<ImportFileProvider>(
            create: (_) => ImportFileProvider(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.instance.navigationKey,
          theme: ThemeData(
            fontFamily: "Ubuntu",
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.black45,
              selectionColor: Colors.black45,
              selectionHandleColor: Colors.black45,
            ),
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.black45),
              hintStyle: TextStyle(color: Colors.black45),
              errorStyle: TextStyle(color: Colors.redAccent),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(0),
                borderSide: BorderSide(color: Colors.black45, width: 2.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(0),
                borderSide: BorderSide(color: Colors.black45, width: 2.0),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                ),
                backgroundColor: MaterialStateProperty.all(Colors.black87),
                foregroundColor: MaterialStateProperty.all(Colors.white),
              ),
            ),
            primaryColor: Colors.black45,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.black.withOpacity(0.9),
              iconTheme: IconThemeData(color: Colors.white),
              foregroundColor: Colors.white,
            ),
          ),
          routes: {'/': (context) => Scaffold(body: Home())},
        ),
      ),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
