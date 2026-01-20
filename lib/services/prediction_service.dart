import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math';
import '../models/sensor_reading.dart';
import '../config/app_config.dart';

class PredictionResult {
  final String label;
  final double confidence;

  PredictionResult(this.label, this.confidence);
}

class PredictionService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  // NOTE: The bundled model (assets/models/water_model_improved.tflite)
  // was trained on StandardScaler-normalized features.
  // These values come from assets/models/scaler.pkl (mean_ and scale_).
  // Feature order for the 5-feature model:
  // [pH, TDS, Temperature, pH_deviation, temp_normalized]
  static const List<double> _scalerMean5 = <double>[
    7.58421748,
    611.269925,
    26.037474,
    1.60070454,
    0.207494791,
  ];
  static const List<double> _scalerScale5 = <double>[
    2.2826405,
    367.24836647,
    8.34504323,
    1.72901784,
    1.66900865,
  ];

  // Confidence calibration parameters (improved)
  static const double HIGH_CONFIDENCE_THRESHOLD =
      0.75; // 75% for strong predictions
  static const double MEDIUM_CONFIDENCE_THRESHOLD = 0.50; // 50% for medium
  static const double LOW_CONFIDENCE_THRESHOLD = 0.35; // Below 35% is uncertain

  /// Initialize TensorFlow Lite model for mobile/desktop
  static Future<void> initializeModel(String modelPath) async {
    if (_isInitialized) {
      debugPrint('ML model already initialized');
      return;
    }

    try {
      debugPrint('🧠 Initializing TFLite model...');
      debugPrint(
          '  Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.toString()}');
      // Verify the asset is present and readable (helps catch pubspec/asset path issues)
      final modelBytes = await rootBundle.load(modelPath);
      debugPrint('  Model asset bytes: ${modelBytes.lengthInBytes}');

      // Load model from assets (works on all platforms)
      _interpreter = await Interpreter.fromAsset(modelPath);
      _isInitialized = true;
      debugPrint('✓ TFLite model loaded successfully from: $modelPath');
      debugPrint('  Input shape: ${_interpreter!.getInputTensor(0).shape}');
      debugPrint('  Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      debugPrint(
          '  🎯 Confidence thresholds: High=$HIGH_CONFIDENCE_THRESHOLD, Medium=$MEDIUM_CONFIDENCE_THRESHOLD');
    } catch (e, st) {
      debugPrint('✗ Failed to load TFLite model: $e');
      debugPrint('  Model path: $modelPath');
      debugPrint(
          '  Note: Android "Registration failed" usually means the model\'s ops/version\n'
          '  are not supported by the TensorFlow Lite runtime bundled with tflite_flutter.\n'
          '  Fix by re-exporting the model using TensorFlow <= 2.12 with built-in ops only,\n'
          '  or by upgrading the TFLite runtime/plugin to match your model.');
      debugPrint('  Stack: $st');
      _isInitialized = false;
    }
  }

  /// Generate prediction based on sensor readings (formatted string as before)
  /// Uses the richer result that also carries confidence
  static Future<String> getPrediction(SensorReading reading) async {
    final result = await getPredictionWithConfidence(reading);
    return result.label;
  }

  /// Generate prediction and return both label and confidence (0-1)
  static Future<PredictionResult> getPredictionWithConfidence(
      SensorReading reading) async {
    // Guard against obviously invalid sensor values.
    // A TDS/EC value of 0.0 in natural water usually indicates a sensor/readout issue.
    if (reading.tds <= 0.0) {
      debugPrint('⚠ Invalid TDS reading (<= 0.0). Marking as Unsafe.');
      return PredictionResult(_formatPrediction('Bad'), 0.0);
    }

    if (!_isInitialized || _interpreter == null) {
      debugPrint(
          'ML model not initialized (or failed to load), using rule-based prediction');
      final fallback = _getRuleBasedPrediction(reading);
      return PredictionResult(fallback, 0.0);
    }

    try {
      // Check model input shape to determine feature count
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final numFeatures = inputShape[1]; // [1, numFeatures]

      List<double> features;

      if (numFeatures == 3) {
        features = [reading.pH, reading.tds, reading.temp];
      } else if (numFeatures == 5) {
        final phDeviation = (reading.pH - 7.0).abs();
        final tempNormalized = (reading.temp - 25.0) / 5.0;
        features = [
          reading.pH,
          reading.tds,
          reading.temp,
          phDeviation,
          tempNormalized,
        ];
      } else {
        debugPrint(
            '⚠ Unexpected input shape: $inputShape, using basic features');
        features = [reading.pH, reading.tds, reading.temp];
      }

      // Apply the same normalization used during training (if we can).
      if (numFeatures == 5 && features.length == 5) {
        features = _standardize(features, _scalerMean5, _scalerScale5);
      }

      final input = [features];

      final output = List.filled(1, List.filled(3, 0.0))
          .map((e) => List<double>.from(e))
          .toList();

      _interpreter!.run(input, output);

      final rawOutput = output[0];
      final normalizedConfidence = _looksLikeProbabilities(rawOutput)
          ? rawOutput
          : _applySoftmax(rawOutput);

      final maxIndex = normalizedConfidence.indexWhere(
          (val) => val == normalizedConfidence.reduce((a, b) => a > b ? a : b));
      final maxConfidence = normalizedConfidence[maxIndex];

      // IMPORTANT: output index order must match the training label encoder.
      // For the bundled model, assets/models/label_encoder.pkl has:
      // ['Bad', 'Good', 'Moderate']
      const predictions = ['Bad', 'Good', 'Moderate'];
      final prediction = predictions[maxIndex];

      final confidenceGap =
          _calculateConfidenceGap(normalizedConfidence, maxIndex);
      final confidenceQuality =
          _getConfidenceQuality(maxConfidence, confidenceGap);

      debugPrint(
          '🤖 ML Prediction: $prediction (${(maxConfidence * 100).toStringAsFixed(1)}% confidence) - $confidenceQuality');
      debugPrint(
          '   Probabilities: ${normalizedConfidence.map((c) => "${(c * 100).toStringAsFixed(1)}%").join(", ")}');
      debugPrint(
          '   Confidence gap: ${(confidenceGap * 100).toStringAsFixed(1)}% (higher = more certain)');

      // If the model confidently outputs "Moderate" even when all sensor
      // values are clearly inside the app's safe ranges, treat it as "Good".
      // This avoids surprising users when the domain thresholds say "Safe".
      final resolvedLabel =
          (prediction == 'Moderate' && _isClearlySafeByThresholds(reading))
              ? 'Good'
              : prediction;

      final formatted = _formatPredictionWithAdvancedConfidence(
          resolvedLabel, maxConfidence, confidenceQuality);

      return PredictionResult(formatted, maxConfidence);
    } catch (e) {
      debugPrint('ML prediction failed, using rule-based fallback: $e');
      final fallback = _getRuleBasedPrediction(reading);
      return PredictionResult(fallback, 0.0);
    }
  }

  static bool _isClearlySafeByThresholds(SensorReading reading) {
    // Invalid/missing sensor readings should never be treated as safe.
    if (reading.tds <= 0.0) return false;

    final ph = AppConfig.thresholds['pH'];
    final temp = AppConfig.thresholds['temp'];
    final tds = AppConfig.thresholds['tds'];
    if (ph == null || temp == null || tds == null) return false;

    // Add margins so values near boundaries don't get force-promoted.
    const phMargin = 0.2;
    const tempMargin = 0.5;
    const tdsMargin = 50.0;

    final phMin = ph['min']! + phMargin;
    final phMax = ph['max']! - phMargin;
    final tempMin = temp['min']! + tempMargin;
    final tempMax = temp['max']! - tempMargin;
    final tdsMin = tds['min']! + tdsMargin;
    final tdsMax = tds['max']! - tdsMargin;

    return reading.pH >= phMin &&
        reading.pH <= phMax &&
        reading.temp >= tempMin &&
        reading.temp <= tempMax &&
        reading.tds >= tdsMin &&
        reading.tds <= tdsMax;
  }

  /// Apply softmax normalization for better probability calibration
  static List<double> _applySoftmax(List<double> scores) {
    // Find max for numerical stability
    final maxScore = scores.reduce((a, b) => a > b ? a : b);

    // Subtract max and exp
    final expScores = scores.map((s) => exp(s - maxScore)).toList();

    // Sum for normalization
    final sum = expScores.reduce((a, b) => a + b);

    // Normalize and return as List<double>
    return expScores.map((e) => e / sum).cast<double>().toList();
  }

  static bool _looksLikeProbabilities(List<double> values) {
    if (values.isEmpty) return false;
    // Typical probability vectors: all in [0,1] and sum ~= 1.
    double sum = 0.0;
    for (final v in values) {
      if (v.isNaN || v.isInfinite) return false;
      if (v < 0.0 || v > 1.0) return false;
      sum += v;
    }
    return sum > 0.98 && sum < 1.02;
  }

  static List<double> _standardize(
    List<double> values,
    List<double> mean,
    List<double> scale,
  ) {
    final out = <double>[];
    final n = min(values.length, min(mean.length, scale.length));
    for (var i = 0; i < n; i++) {
      final denom = scale[i] == 0 ? 1.0 : scale[i];
      out.add((values[i] - mean[i]) / denom);
    }
    // If lengths mismatch, append remaining values unchanged.
    for (var i = n; i < values.length; i++) {
      out.add(values[i]);
    }
    return out;
  }

  /// Calculate confidence gap between top and second prediction
  static double _calculateConfidenceGap(
      List<double> normalizedConfidence, int topIndex) {
    final topScore = normalizedConfidence[topIndex];

    // Find second highest score
    double secondHighest = 0.0;
    for (int i = 0; i < normalizedConfidence.length; i++) {
      if (i != topIndex && normalizedConfidence[i] > secondHighest) {
        secondHighest = normalizedConfidence[i];
      }
    }

    return topScore - secondHighest;
  }

  /// Determine confidence quality based on threshold
  static String _getConfidenceQuality(double confidence, double gap) {
    if (confidence >= HIGH_CONFIDENCE_THRESHOLD && gap >= 0.15) {
      return 'VERY HIGH'; // Excellent confidence
    } else if (confidence >= HIGH_CONFIDENCE_THRESHOLD) {
      return 'HIGH'; // Good confidence
    } else if (confidence >= MEDIUM_CONFIDENCE_THRESHOLD && gap >= 0.10) {
      return 'MEDIUM'; // Moderate confidence
    } else if (confidence >= MEDIUM_CONFIDENCE_THRESHOLD) {
      return 'MEDIUM-LOW'; // Borderline
    } else if (confidence >= LOW_CONFIDENCE_THRESHOLD) {
      return 'LOW'; // Low confidence
    } else {
      return 'VERY LOW'; // Very uncertain
    }
  }

  /// Rule-based prediction fallback when ML model is unavailable
  static String _getRuleBasedPrediction(SensorReading reading) {
    // Keep fallback aligned with AppConfig.thresholds
    const phSafe = {'min': 6.5, 'max': 8.5};
    const tempSafe = {'min': 25.0, 'max': 30.0};
    const tdsSafe = {'min': 100.0, 'max': 1500.0};

    if (reading.tds <= 0.0) {
      return _formatPrediction('Bad');
    }

    int issueCount = 0;

    if (reading.pH < phSafe['min']! || reading.pH > phSafe['max']!) {
      issueCount++;
    }
    if (reading.temp < tempSafe['min']! || reading.temp > tempSafe['max']!) {
      issueCount++;
    }
    if (reading.tds < tdsSafe['min']! || reading.tds > tdsSafe['max']!) {
      issueCount++;
    }

    if (issueCount == 0) {
      return _formatPrediction('Good');
    } else if (issueCount == 1) {
      return _formatPrediction('Moderate');
    } else {
      return _formatPrediction('Bad');
    }
  }

  /// Format prediction from Python model
  static String _formatPrediction(String prediction) {
    const formatMap = {
      'Good': '✔️ Safe - Water quality is good',
      'Moderate': '⚠ Caution - Monitor water quality',
      'Bad': '❌ Unsafe - Water treatment recommended',
      'Unknown': '? Low confidence - Unable to predict',
      'Error': '? Prediction unavailable',
    };
    return formatMap[prediction] ?? prediction;
  }

  /// Format prediction with advanced confidence scoring
  static String _formatPredictionWithAdvancedConfidence(
      String prediction, double confidence, String confidenceQuality) {
    final baseFormat = _formatPrediction(prediction);
    final confidencePercent = (confidence * 100).toStringAsFixed(1);

    // Only append confidence if it's available and prediction is not Unknown
    if (confidence > 0 && prediction != 'Unknown') {
      return '$baseFormat ($confidencePercent% confidence - $confidenceQuality)';
    }

    return baseFormat;
  }
}
