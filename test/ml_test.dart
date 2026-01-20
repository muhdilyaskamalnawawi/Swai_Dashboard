import 'package:flutter_test/flutter_test.dart';
import 'package:swai_dasboard/services/prediction_service.dart';
import 'package:swai_dasboard/models/sensor_reading.dart';

void main() {
  // Initialize Flutter bindings for TFLite
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ML Model Tests', () {
    setUpAll(() async {
      // Initialize the TFLite model
      await PredictionService.initializeModel(
        'assets/models/water_model_improved.tflite',
      );
    });

    test('Test 1: Good water quality (all parameters in safe range)', () async {
      final reading = SensorReading(
        id: 'test-1',
        pH: 7.2,
        temp: 27.0,
        tds: 300.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 1 Result: $prediction');
      expect(prediction, contains('Safe'));
    });

    test('Test 2: Moderate quality (pH slightly out of range)', () async {
      final reading = SensorReading(
        id: 'test-2',
        pH: 6.0,
        temp: 27.0,
        tds: 300.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 2 Result: $prediction');
      expect(prediction, contains('Caution'));
    });

    test('Test 3: Bad quality (multiple parameters out of range)', () async {
      final reading = SensorReading(
        id: 'test-3',
        pH: 5.0,
        temp: 35.0,
        tds: 800.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 3 Result: $prediction');
      expect(prediction, contains('Unsafe'));
    });

    test('Test 4: Edge case - pH at upper safe limit', () async {
      final reading = SensorReading(
        id: 'test-4',
        pH: 8.5,
        temp: 27.0,
        tds: 300.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 4 Result: $prediction');
      // pH 8.5 is at upper limit of safe range, should be Safe or Caution
      expect(
        prediction.toLowerCase(),
        anyOf(contains('safe'), contains('caution')),
      );
    });

    test('Test 5: High TDS (above safe range)', () async {
      final reading = SensorReading(
        id: 'test-5',
        pH: 7.2,
        temp: 27.0,
        tds: 800.0, // Above 750, now truly high
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 5 Result: $prediction');
      // TDS 800 is above safe range (750), should be Caution or Unsafe
      expect(
        prediction.toLowerCase(),
        anyOf(contains('caution'), contains('unsafe')),
      );
    });

    test('Test 6: Low temperature', () async {
      final reading = SensorReading(
        id: 'test-6',
        pH: 7.2,
        temp: 20.0,
        tds: 300.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 6 Result: $prediction');
      // Temperature below 25°C should trigger caution or unsafe
      expect(
        prediction.toLowerCase(),
        anyOf(contains('caution'), contains('unsafe')),
      );
    });

    test('Test 7: Perfect conditions', () async {
      final reading = SensorReading(
        id: 'test-7',
        pH: 7.0,
        temp: 27.5,
        tds: 250.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 7 Result: $prediction');
      expect(prediction.toLowerCase(), contains('safe'));
    });

    test('Test 8: All parameters critically out of range', () async {
      final reading = SensorReading(
        id: 'test-8',
        pH: 4.5,
        temp: 40.0,
        tds: 1000.0,
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);
      print('Test 8 Result: $prediction');
      expect(prediction.toLowerCase(), contains('unsafe'));
    });
  });
}
