import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to call Python ML model for water quality predictions
/// Uses your trained model at: C:\Users\HP\Documents\smart_wgai\water_model.pkl
class PythonMLService {
  static const String pythonScriptPath =
      r'C:\Users\HP\Documents\smart_wgai\predict.py';

  /// Get prediction from Python ML model
  /// Returns prediction string (Good, Moderate, Bad, or error)
  static Future<String> getPrediction({
    required double ph,
    required double tds,
    required double temp,
  }) async {
    try {
      // Run Python script with sensor arguments
      final result = await Process.run(
        'python',
        [pythonScriptPath, ph.toString(), tds.toString(), temp.toString()],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        debugPrint('Python script error: ${result.stderr}');
        return 'Error';
      }

      // Parse JSON response from Python script
      final Map<String, dynamic> response = jsonDecode(result.stdout);

      if (response.containsKey('error')) {
        debugPrint('Prediction error: ${response['error']}');
        return 'Error';
      }

      return response['Prediction'] ?? 'Unknown';
    } catch (e) {
      debugPrint('Failed to get prediction: $e');
      return 'Error';
    }
  }

  /// Get full prediction result including sensor values
  static Future<Map<String, dynamic>> getPredictionFull({
    required double ph,
    required double tds,
    required double temp,
  }) async {
    try {
      final result = await Process.run(
        'python',
        [pythonScriptPath, ph.toString(), tds.toString(), temp.toString()],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        return {'error': result.stderr, 'prediction': 'Error'};
      }

      final Map<String, dynamic> response = jsonDecode(result.stdout);
      return response;
    } catch (e) {
      debugPrint('Failed to get full prediction: $e');
      return {'error': e.toString(), 'prediction': 'Error'};
    }
  }

  /// Convert prediction to readable format
  /// Maps: Good → Safe, Moderate → Caution, Bad → Unsafe
  static String formatPrediction(String prediction) {
    final Map<String, String> formatMap = {
      'Good': 'Safe',
      'Moderate': 'Caution',
      'Bad': 'Unsafe',
    };
    return formatMap[prediction] ?? prediction;
  }

  /// Check if Python and model are available
  static Future<bool> isAvailable() async {
    try {
      // Check if Python is installed
      final pythonCheck = await Process.run('python', ['--version']);
      if (pythonCheck.exitCode != 0) return false;

      // Check if script exists
      final scriptFile = File(pythonScriptPath);
      if (!await scriptFile.exists()) return false;

      // Check if model file exists
      const modelPath = r'C:\Users\HP\Documents\smart_wgai\water_model.pkl';
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) return false;

      return true;
    } catch (e) {
      debugPrint('Availability check failed: $e');
      return false;
    }
  }
}
