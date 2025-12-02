import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';
import '../models/sensor_reading.dart';

class GeminiService {
  static late GenerativeModel _model;
  static bool _initialized = false;

  /// Initialize Gemini model with API key
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: AppConfig.geminiApiKey,
      );
      _initialized = true;
      debugPrint('✓ Gemini AI initialized');
    } catch (e) {
      debugPrint('✗ Error initializing Gemini: $e');
      rethrow;
    }
  }

  /// Get AI-powered recommendation based on sensor readings
  static Future<String> getRecommendation(SensorReading reading) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final prompt = _buildPrompt(reading);

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'Unable to generate recommendation';
    } catch (e) {
      debugPrint('Error generating recommendation: $e');
      return 'Recommendation unavailable. Please check Gemini API key.';
    }
  }

  /// Build prompt for Gemini based on sensor data (Red Tilapia aquaculture specialist)
  static String _buildPrompt(SensorReading reading) {
    final ph = reading.pH.toStringAsFixed(2);
    final tds = reading.tds.toStringAsFixed(0);
    final temp = reading.temp.toStringAsFixed(2);

    return '''Role: Act as an aquaculture specialist for Red Tilapia. Only mention fish in the results.

Target Users: Small to medium-scale freshwater pond farmers in Malaysia raising tilapia.

Optimal Ranges for Red Tilapia:
- Temperature: 25°C – 30°C
- pH: 6.5 – 8.5
- TDS: 100 – 500 ppm

Input (Real-Time Data):
- pH: $ph
- TDS: $tds ppm
- Temperature: $temp °C

Instructions:
Analyze the real-time data against the optimal ranges for pond environments.
Give a concise single, actionable recommendation for a local farmer.
Keep the recommendation 1–2 sentences, max 30 words.

Output Format:
Analysis: [brief observation of which parameters are OK or need adjustment]

Action: [practical advice for immediate action—what, how]—by using a verb.''';
  }

  /// Stream recommendations for real-time updates (advanced)
  static Stream<String> getRecommendationStream(SensorReading reading) async* {
    if (!_initialized) {
      await initialize();
    }

    try {
      final prompt = _buildPrompt(reading);
      final content = [Content.text(prompt)];
      final stream = _model.generateContentStream(content);

      await for (var response in stream) {
        yield response.text ?? '';
      }
    } catch (e) {
      debugPrint('Error in recommendation stream: $e');
      yield 'Error generating recommendation';
    }
  }

  /// Get detailed analysis for specific issues
  static Future<String> getDetailedAnalysis(
      SensorReading reading, String issue) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final prompt = '''
You are a water quality expert. The user is experiencing: "$issue"

Current sensor data:
- pH: ${reading.pH.toStringAsFixed(2)}
- Temperature: ${reading.temp.toStringAsFixed(2)}°C
- TDS: ${reading.tds.toStringAsFixed(2)} ppm

Provide a detailed explanation of the issue and specific remediation steps in 3-4 sentences.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'Unable to generate analysis';
    } catch (e) {
      debugPrint('Error generating analysis: $e');
      return 'Analysis unavailable';
    }
  }

  /// Generate alert message if thresholds exceeded
  static Future<String> generateAlertMessage(SensorReading reading) async {
    if (!_initialized) {
      await initialize();
    }

    List<String> issues = [];

    if (reading.pH < 6.5 || reading.pH > 8.5) {
      issues.add('pH level is ${reading.pH < 6.5 ? 'too low' : 'too high'}');
    }
    if (reading.temp < 25 || reading.temp > 30) {
      issues
          .add('Temperature is ${reading.temp < 25 ? 'too low' : 'too high'}');
    }
    if (reading.tds < 100 || reading.tds > 500) {
      issues.add('TDS level is ${reading.tds < 100 ? 'too low' : 'too high'}');
    }

    if (issues.isEmpty) {
      return 'All parameters are within safe range';
    }

    try {
      final prompt = '''
Alert: ${issues.join(', ')}.

Current readings: pH ${reading.pH}, Temperature ${reading.temp}°C, TDS ${reading.tds} ppm

Generate a brief alert message (one sentence) with urgency level.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'Alert: Threshold exceeded';
    } catch (e) {
      debugPrint('Error generating alert: $e');
      return 'Alert: Sensor reading outside safe range';
    }
  }
}
