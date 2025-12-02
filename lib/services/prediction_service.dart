import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/sensor_reading.dart';
import 'python_ml_service.dart';

class PredictionService {
  // Use Python model only on desktop platforms (cannot run Python on mobile/web)
  static bool usePythonModel =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Initialize - Python model is used by default
  static Future<void> initializeModel(String modelPath) async {
    // No-op for Python model; guard platform availability
    if (!usePythonModel) {
      debugPrint('Python model not available on this platform.');
    } else {
      debugPrint(
          r'Using Python ML model at C:\Users\HP\Documents\smart_wgai\water_model.pkl');
    }
  }

  /// Generate prediction based on sensor readings
  /// Uses Python model (water_model.pkl)
  static Future<String> getPrediction(SensorReading reading) async {
    try {
      if (usePythonModel) {
        // Desktop: call local Python script
        final prediction = await PythonMLService.getPrediction(
          ph: reading.pH,
          tds: reading.tds,
          temp: reading.temp,
        );
        return _formatPrediction(prediction);
      }
      // Mobile/Web: Python execution not supported
      return 'Prediction unavailable (Python not supported on this platform)';
    } catch (e) {
      debugPrint('Error running prediction: $e');
      return 'Prediction unavailable';
    }
  }

  /// Format prediction from Python model
  static String _formatPrediction(String prediction) {
    const formatMap = {
      'Good': '✓ Safe - Water quality is good',
      'Moderate': '⚠ Caution - Monitor water quality',
      'Bad': '✗ Unsafe - Water treatment recommended',
      'Error': '? Prediction unavailable',
    };
    return formatMap[prediction] ?? prediction;
  }

  /// Batch prediction for multiple readings
  static Future<List<String>> batchPredict(List<SensorReading> readings) async {
    List<String> predictions = [];
    for (var reading in readings) {
      predictions.add(await getPrediction(reading));
    }
    return predictions;
  }
}
