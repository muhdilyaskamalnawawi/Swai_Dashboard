import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../models/sensor_reading.dart';
import '../services/supabase_service.dart';
import '../services/prediction_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../config/app_config.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabaseService = SupabaseService();
  late Stream<SensorReading?> _latestReadingStream;
  SensorReading? _currentReading;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _latestReadingStream = _supabaseService.getLatestReadingStream();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize prediction model
      await PredictionService.initializeModel(AppConfig.mlModelPath);
      // Initialize Gemini
      await GeminiService.initialize();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  Future<void> _fetchLatestReading() async {
    try {
      final reading = await _supabaseService.getLatestReading();
      if (reading != null) {
        setState(() => _currentReading = reading);
        await _checkAlerts(reading);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    }
  }

  Future<void> _checkAlerts(SensorReading reading) async {
    final isCritical = _isCriticalReading(reading);
    if (isCritical) {
      final alertMessage = await GeminiService.generateAlertMessage(reading);
      await NotificationService.showAlertNotification(
        title: 'Water Quality Alert',
        body: alertMessage,
      );
    }
  }

  bool _isCriticalReading(SensorReading reading) {
    final phThreshold = AppConfig.thresholds['pH']!;
    final tempThreshold = AppConfig.thresholds['temp']!;
    final tdsThreshold = AppConfig.thresholds['tds']!;

    return reading.pH < phThreshold['criticalMin']! ||
        reading.pH > phThreshold['criticalMax']! ||
        reading.temp < tempThreshold['criticalMin']! ||
        reading.temp > tempThreshold['criticalMax']! ||
        reading.tds < tdsThreshold['criticalMin']! ||
        reading.tds > tdsThreshold['criticalMax']!;
  }

  bool _isWarningReading(SensorReading reading) {
    final phThreshold = AppConfig.thresholds['pH']!;
    final tempThreshold = AppConfig.thresholds['temp']!;
    final tdsThreshold = AppConfig.thresholds['tds']!;

    return reading.pH < phThreshold['min']! ||
        reading.pH > phThreshold['max']! ||
        reading.temp < tempThreshold['min']! ||
        reading.temp > tempThreshold['max']! ||
        reading.tds < tdsThreshold['min']! ||
        reading.tds > tdsThreshold['max']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SWAI Dashboard'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLatestReading,
          ),
        ],
      ),
      body: StreamBuilder<SensorReading?>(
        stream: _latestReadingStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final reading = snapshot.data ?? _currentReading;

          if (reading == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sensors, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No sensor data available'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetchLatestReading,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final isWarning = _isWarningReading(reading);
          final isCritical = _isCriticalReading(reading);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Alert Banner
                if (isCritical)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Critical: Water quality is unsafe!',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isWarning && !isCritical)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Warning: Some readings are outside safe range',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Gauges Row
                Row(
                  children: [
                    Expanded(
                      child: _buildGaugeCard(
                        'pH',
                        reading.pH,
                        0,
                        14,
                        AppConfig.thresholds['pH']!['min']!,
                        AppConfig.thresholds['pH']!['max']!,
                        'pH',
                      ),
                    ),
                    Expanded(
                      child: _buildGaugeCard(
                        'Temperature',
                        reading.temp,
                        20,
                        40,
                        AppConfig.thresholds['temp']!['min']!,
                        AppConfig.thresholds['temp']!['max']!,
                        '°C',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _buildGaugeCard(
                    'TDS',
                    reading.tds,
                    0,
                    1000,
                    AppConfig.thresholds['tds']!['min']!,
                    AppConfig.thresholds['tds']!['max']!,
                    'ppm',
                  ),
                ),
                const SizedBox(height: 24),

                // Prediction Card
                _buildInfoCard(
                  title: 'AI Prediction',
                  content: reading.prediction ?? 'Loading prediction...',
                  icon: Icons.psychology,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),

                // Recommendation Card
                _buildInfoCard(
                  title: 'Recommendation',
                  content:
                      reading.recommendation ?? 'Loading recommendation...',
                  icon: Icons.lightbulb,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),

                // Last Updated
                Text(
                  'Last updated: ${reading.timestamp.toString().split('.')[0]}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGaugeCard(
    String title,
    double value,
    double min,
    double max,
    double safeMin,
    double safeMax,
    String unit,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(
              height: 180,
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    minimum: min,
                    maximum: max,
                    ranges: [
                      GaugeRange(
                        startValue: min,
                        endValue: safeMin,
                        color: Colors.red,
                      ),
                      GaugeRange(
                        startValue: safeMin,
                        endValue: safeMax,
                        color: Colors.green,
                      ),
                      GaugeRange(
                        startValue: safeMax,
                        endValue: max,
                        color: Colors.red,
                      ),
                    ],
                    pointers: [
                      NeedlePointer(value: value),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} $unit',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
