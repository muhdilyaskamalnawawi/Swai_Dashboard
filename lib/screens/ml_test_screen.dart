import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../services/prediction_service.dart';

/// Debug screen to test ML model predictions
class MLTestScreen extends StatefulWidget {
  const MLTestScreen({super.key});

  @override
  State<MLTestScreen> createState() => _MLTestScreenState();
}

class _MLTestScreenState extends State<MLTestScreen> {
  final List<Map<String, dynamic>> _testResults = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _testCases = [
    {
      'name': 'Test 1: Good Quality',
      'pH': 7.2,
      'tds': 300.0,
      'temp': 27.0,
      'expected': 'Safe',
    },
    {
      'name': 'Test 2: Moderate (Low pH)',
      'pH': 6.0,
      'tds': 300.0,
      'temp': 27.0,
      'expected': 'Caution',
    },
    {
      'name': 'Test 3: Bad Quality',
      'pH': 5.0,
      'tds': 800.0,
      'temp': 35.0,
      'expected': 'Unsafe',
    },
    {
      'name': 'Test 4: High pH',
      'pH': 9.0,
      'tds': 300.0,
      'temp': 27.0,
      'expected': 'Caution',
    },
    {
      'name': 'Test 5: High TDS',
      'pH': 7.2,
      'tds': 600.0,
      'temp': 27.0,
      'expected': 'Caution',
    },
    {
      'name': 'Test 6: High Temp',
      'pH': 7.2,
      'tds': 300.0,
      'temp': 35.0,
      'expected': 'Caution',
    },
    {
      'name': 'Test 7: Edge Case (All Min)',
      'pH': 6.5,
      'tds': 100.0,
      'temp': 25.0,
      'expected': 'Safe',
    },
    {
      'name': 'Test 8: Edge Case (All Max)',
      'pH': 8.5,
      'tds': 500.0,
      'temp': 30.0,
      'expected': 'Safe',
    },
  ];

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    for (var testCase in _testCases) {
      final reading = SensorReading(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        pH: testCase['pH'],
        temp: testCase['temp'],
        tds: testCase['tds'],
        prediction: '',
        recommendation: '',
        timestamp: DateTime.now(),
      );

      final prediction = await PredictionService.getPrediction(reading);

      setState(() {
        _testResults.add({
          'name': testCase['name'],
          'input':
              'pH: ${testCase['pH']}, TDS: ${testCase['tds']}, Temp: ${testCase['temp']}°C',
          'expected': testCase['expected'],
          'actual': prediction,
          'passed': prediction.contains(testCase['expected']),
        });
      });

      // Small delay between tests
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final passedTests = _testResults.where((r) => r['passed']).length;
    final totalTests = _testResults.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Model Testing'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: passedTests == totalTests
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: passedTests == totalTests
                          ? Colors.green
                          : Colors.orange,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Test Results',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$passedTests / $totalTests Tests Passed',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: passedTests == totalTests
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${((passedTests / totalTests) * 100).toStringAsFixed(1)}% Success Rate',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Test Results List
                Expanded(
                  child: ListView.builder(
                    itemCount: _testResults.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final result = _testResults[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ListTile(
                          leading: Icon(
                            result['passed'] ? Icons.check_circle : Icons.error,
                            color: result['passed'] ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          title: Text(
                            result['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                result['input'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expected: ${result['expected']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Actual: ${result['actual']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: result['passed']
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),

                // Rerun Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _runTests,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rerun Tests'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
