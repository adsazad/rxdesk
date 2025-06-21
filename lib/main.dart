import 'dart:io';

import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as pvrd;
import 'package:spirobtvo/ProviderModals/DefaultPatientModal.dart';
import 'package:spirobtvo/ProviderModals/GlobalSettingsModal.dart';
import 'package:spirobtvo/Services/navigatorService.dart';
import 'package:spirobtvo/home.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Set fullscreen mode on app launch
  WindowOptions windowOptions = WindowOptions(
    title: 'SpiroBT',
    size: Size(1920, 1080), // Optional starting size
    center: true,
    minimumSize: Size(800, 600),
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.maximize();
  });
  // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])

  //     .then((_) {

  HttpOverrides.global = new MyHttpOverrides();
  runApp(
    ProviderScope(
      child: pvrd.MultiProvider(
        providers: [
          pvrd.ChangeNotifierProvider<GlobalSettingsModal>(
            create:
                (context) => GlobalSettingsModal(
                  com: "none",
                  autoRecordOnOff: true,
                  filterOnOf: true,
                  highPass: 5,
                  lowPass: 3,
                  notch: true,
                  gridLine: true,
                  sampleRate: '300',
                  voltage1: 0.96,
                  value1: 20.93,
                  voltage2: 0.77,
                  value2: 15.93,
                  applyConversion: false,
                ),
          ),
          pvrd.ChangeNotifierProvider<DefaultPatientModal>(
            create: (context) => DefaultPatientModal(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.instance.navigationKey,
          // localizationsDelegates: [MonthYearPickerLocalizations.delegate],
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
          routes: {
            '/':
                (context) => Scaffold(
                  body: AnimatedSplashScreen(
                    backgroundColor: Colors.black,
                    splash: Container(
                      child: Column(
                        children: [
                          Image(
                            image: AssetImage("assets/smallbiobtsplash.gif"),
                            width: 150,
                          ),
                        ],
                      ),
                    ),
                    splashTransition: SplashTransition.scaleTransition,
                    duration: 3000,
                    curve: Curves.decelerate,
                    nextScreen: Home(),
                  ),
                ),
          },
        ),
      ),
    ),
  );
  // });
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
