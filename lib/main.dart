import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'services/workmanager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling (helps prevent release-mode force closes on uncaught
  // Dart exceptions and gives us useful logs).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint('$stack');
    // Returning true marks the error as handled.
    return true;
  };

  runZonedGuarded(() async {
    // Load environment variables from .env file
    try {
      await dotenv.load(fileName: '.env');
    } catch (e, st) {
      debugPrint('dotenv.load failed: $e');
      debugPrint('$st');
      // Continue boot; AppConfig has fallbacks for Supabase.
    }

    // Enable Android background polling via WorkManager (registration happens
    // during app init based on platform).
    try {
      await WorkmanagerService.initialize();
    } catch (e, st) {
      // Ignore: WorkManager is Android-only.
      debugPrint('Workmanager init skipped: $e');
      debugPrint('$st');
    }

    // All initialization now happens in SplashScreen
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    debugPrint('runZonedGuarded error: $error');
    debugPrint('$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SWAI Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0EA5E9),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
