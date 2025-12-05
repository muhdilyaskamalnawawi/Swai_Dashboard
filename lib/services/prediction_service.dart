import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/sensor_reading.dart';
import 'python_ml_service.dart';

class PredictionService {
  // Use Python model only on desktop platforms (cannot run Python on mobile/web)
  static bool usePythonModel =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Initialize - Python model is used by default (improved TFLite model)
  static Future<void> initializeModel(String modelPath) async {
    // No-op for Python model; guard platform availability
    if (!usePythonModel) {
      debugPrint('Python model not available on this platform.');
    } else {
      debugPrint(
          r'Using improved TFLite model at C:\Users\HP\Documents\SEM 6\fyp\MachineLearning\');
    }
  }

  /// Generate prediction based on sensor readings
  /// Uses improved TensorFlow Lite model with confidence scoring
  static Future<String> getPrediction(SensorReading reading) async {
    if (usePythonModel) {
      // Desktop: call local Python script with TFLite model
      final predictionFull = await PythonMLService.getPredictionFull(
        ph: reading.pH,
        tds: reading.tds,
        temp: reading.temp,
      );

      if (predictionFull.containsKey('error')) {
        debugPrint('Prediction error: ${predictionFull['error']}');
        return _formatPrediction('Error');
      }

      final prediction = predictionFull['Prediction'] ?? 'Unknown';
      final confidence = predictionFull['Confidence'] ?? 0.0;

      // Format with confidence info
      return _formatPredictionWithConfidence(prediction, confidence);
    } else {
      // Mobile/Web: use fallback
      debugPrint('ML model not available on this platform');
      return _formatPrediction('Unknown');
    }
  }

  /// Format prediction from Python model
  static String _formatPrediction(String prediction) {
    const formatMap = {
      'Good': '✓ Safe - Water quality is good',
      'Moderate': '⚠ Caution - Monitor water quality',
      'Bad': '✗ Unsafe - Water treatment recommended',
      'Unknown': '? Low confidence - Unable to predict',
      'Error': '? Prediction unavailable',
    };
    return formatMap[prediction] ?? prediction;
  }

  /// Format prediction with confidence score
  static String _formatPredictionWithConfidence(
      String prediction, double confidence) {
    final baseFormat = _formatPrediction(prediction);
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    // Only append confidence if it's available and prediction is not Unknown
    if (confidence > 0 && prediction != 'Unknown') {
      return '$baseFormat ($confidencePercent% confidence)';
    }

    return baseFormat;
  }
}
