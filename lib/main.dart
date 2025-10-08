import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as pvrd;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medicore/ProviderModals/DefaultPatientModal.dart';
import 'package:medicore/ProviderModals/GlobalSettingsModal.dart';
import 'package:medicore/ProviderModals/ImportFileProvider.dart';
import 'package:medicore/Services/navigatorService.dart';
import 'package:medicore/data/local/database.dart';
import 'package:medicore/home.dart';
import 'package:medicore/Pages/setup_wizard.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    title: 'Medicore',
    size: Size(1920, 1080),
    center: true,
    minimumSize: Size(800, 600),
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.maximize();
  });

  HttpOverrides.global = MyHttpOverrides();

  // Load settings from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  // Check if setup is completed
  bool setupCompleted = prefs.getBool('setup_completed') ?? false;
  
  String? settingsJson = prefs.getString("globalSettings");
  GlobalSettingsModal globalSettings;
  if (settingsJson != null) {
    try {
      globalSettings = GlobalSettingsModal.fromJson(settingsJson);
    } catch (e) {
      globalSettings = GlobalSettingsModal();
    }
  } else {
    globalSettings = GlobalSettingsModal();
  }

  runApp(MedicoreApp(
    setupCompleted: setupCompleted,
    globalSettings: globalSettings,
  ));
}

class MedicoreApp extends StatelessWidget {
  final bool setupCompleted;
  final GlobalSettingsModal globalSettings;

  const MedicoreApp({
    super.key,
    required this.setupCompleted,
    required this.globalSettings,
  });

  @override
  Widget build(BuildContext context) {
    return pvrd.MultiProvider(
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
        initialRoute: setupCompleted ? '/' : '/setup',
        routes: {
          '/': (context) => Scaffold(body: Home()),
          '/setup': (context) => SetupWizard(),
        },
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}