import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Application configuration constants
class AppConfig {
  // Supabase Configuration - Read from .env or use fallback
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL']?.replaceAll('"', '');
    if (url == null || url.isEmpty) {
      const fallback = 'https://jrybjofyxppwicvgflpz.supabase.co';
      debugPrint('⚠️ SUPABASE_URL not in .env, using fallback');
      return fallback;
    }
    return url;
  }

  static String get supabaseKey {
    final key = dotenv.env['SUPABASE_KEY']?.replaceAll('"', '');
    if (key == null || key.isEmpty) {
      const fallback =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpyeWJqb2Z5eHBwd2ljdmdmbHB6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ2OTQ1NTcsImV4cCI6MjA4MDI3MDU1N30.z58mhtQfn1DGsAIpMSfj8rNH_69OJ2MS03LC84ZoKWY';
      debugPrint('⚠️ SUPABASE_KEY not in .env, using fallback');
      return fallback;
    }
    return key;
  }

  // Gemini API Configuration - Read from .env file
  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY']?.replaceAll('"', '');
    if (key == null || key.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
    return key;
  }

  // ML Model Configuration
  static const String mlModelPath = 'assets/models/water_model_improved.tflite';

  // Sensor Thresholds (define what counts as "critical")
  static const Map<String, Map<String, double>> thresholds = {
    'pH': {
      'min': 6.5,
      'max': 8.5,
      'criticalMin': 5.0,
      'criticalMax': 10.0,
    },
    'temp': {
      'min': 25.0,
      'max': 30.0,
      'criticalMin': 10.0,
      'criticalMax': 45.0,
    },
    'tds': {
      'min': 100.0,
      'max': 500.0,
      'criticalMin': 0.0,
      'criticalMax': 1500.0,
    },
  };

  // API endpoints (if using external API for sensor data)
  static const String apiBaseUrl = 'YOUR_API_BASE_URL';
}
