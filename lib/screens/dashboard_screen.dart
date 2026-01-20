import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../services/supabase_service.dart';
import '../services/prediction_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/background_monitor_service.dart';
import '../config/app_config.dart';
import '../widgets/wave_background.dart';
import '../widgets/water_metric_card.dart';
import '../widgets/fish_health_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _supabaseService = SupabaseService();
  late Stream<SensorReading?> _latestReadingStream;
  SensorReading? _currentReading;

  String? _processingReadingKey;

  // Real-time observation stream
  StreamSubscription<SensorReading?>? _streamSubscription;

  Timer? _autoRefreshTimer;
  bool _autoRefreshInFlight = false;

  bool _recommendationEnabled = true;
  bool _notificationEnabled = true;

  // Treat tiny sensor noise as "no change" to prevent re-processing loops.
  static const double _phEpsilon = 0.05;
  static const double _tempEpsilon = 0.10;
  static const double _tdsEpsilon = 5.0;

  String _readingProcessingKey(SensorReading reading) {
    return '${reading.id}|'
        '${(reading.pH * 100).round()}|'
        '${(reading.temp * 10).round()}|'
        '${reading.tds.round()}';
  }

  bool _hasMeaningfulSensorChange(SensorReading a, SensorReading b) {
    return (a.pH - b.pH).abs() > _phEpsilon ||
        (a.temp - b.temp).abs() > _tempEpsilon ||
        (a.tds - b.tds).abs() > _tdsEpsilon;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up real-time stream for live data updates immediately so build() can
    // safely use it, but delay the initial fetch until services are ready.
    _latestReadingStream = _supabaseService.getLatestReadingStream();
    _startObservationStream();
    _startAutoRefresh();

    // Initialize ML + AI first to avoid racing the first processing pipeline.
    () async {
      await _initializeServices();
      await _loadSettings();
      if (!mounted) return;

      // Fetch initial data after services are initialized
      await _fetchLatestReading();

      // Start background monitoring
      BackgroundMonitorService.startMonitoring(
        interval: const Duration(minutes: 5),
      );

      debugPrint('✅ Dashboard initialized');
    }();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Public method for external refresh (from AppBar)
  Future<void> refreshLatestReading() async {
    return _fetchLatestReading();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollLatestReading());
    });
  }

  Future<void> _pollLatestReading() async {
    if (!mounted) return;
    if (_autoRefreshInFlight) return;

    _autoRefreshInFlight = true;
    try {
      final latest = await _supabaseService.getLatestReading();
      if (!mounted || latest == null) return;

      final current = _currentReading;
      final isDifferent = current == null ||
          latest.id != current.id ||
          latest.timestamp != current.timestamp ||
          latest.pH != current.pH ||
          latest.temp != current.temp ||
          latest.tds != current.tds;

      if (!isDifferent) return;

      debugPrint('🔁 Poll refresh: new latest reading received');
      setState(() => _currentReading = latest);

      final sameRow = current != null && latest.id == current.id;
      final valuesChanged =
          sameRow ? _hasMeaningfulSensorChange(current, latest) : false;

      final needsPrediction = valuesChanged ||
          latest.prediction == null ||
          latest.prediction!.isEmpty;
      final needsRecommendation = _recommendationEnabled &&
          (latest.recommendation == null || latest.recommendation!.isEmpty);

      if (needsPrediction || needsRecommendation) {
        unawaited(_processAndSaveReading(latest));
      } else {
        await _checkAlerts(latest);
      }
    } catch (e) {
      debugPrint('❌ Poll refresh error: $e');
    } finally {
      _autoRefreshInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - refresh data immediately
      debugPrint('📱 App resumed - refreshing data...');

      // Re-subscribe to real-time stream to recover from any dropped realtime connection.
      _latestReadingStream = _supabaseService.getLatestReadingStream();
      _startObservationStream();

      _fetchLatestReading();
      // Reload settings so toggles (e.g., AI recommendations) apply when returning from Settings
      _loadSettings();
      BackgroundMonitorService.forceCheck();
    } else if (state == AppLifecycleState.paused) {
      // App went to background
      debugPrint('📱 App paused - background monitoring active');
    }
  }

  /// Stream for real-time updates - process data BEFORE showing to UI
  /// Flow: Supabase → Process (ML + AI) → Save to Supabase → Show in UI
  void _startObservationStream() {
    _streamSubscription?.cancel();
    _streamSubscription = _latestReadingStream.listen(
      (reading) async {
        debugPrint('📡 Stream received reading: pH=${reading?.pH}');
        if (reading != null && mounted) {
          final previous = _currentReading;

          // Always show the latest sensor values immediately.
          // ML/AI enrichment can happen in the background.
          setState(() => _currentReading = reading);

          final sameRow = previous != null && reading.id == previous.id;
          final valuesChanged =
              sameRow ? _hasMeaningfulSensorChange(previous, reading) : false;

          final needsPrediction = valuesChanged ||
              reading.prediction == null ||
              reading.prediction!.isEmpty;
          final needsRecommendation = _recommendationEnabled &&
              (reading.recommendation == null ||
                  reading.recommendation!.isEmpty);

          if (needsPrediction || needsRecommendation) {
            debugPrint(
                '⚙️ Background processing (ML/AI) for latest reading...');
            unawaited(_processAndSaveReading(reading));
          } else {
            debugPrint('✅ Using pre-processed data from database');
            await _checkAlerts(reading);
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Stream error: $error');
        // Show error to user if stream fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Real-time connection error: $error'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  /// Process raw reading: ML + AI in PARALLEL → Save to DB → Update UI
  /// Optimized flow: Run ML and AI simultaneously, then save once
  Future<void> _processAndSaveReading(SensorReading reading) async {
    try {
      final processingKey = _readingProcessingKey(reading);
      if (_processingReadingKey == processingKey) {
        return;
      }

      _processingReadingKey = processingKey;
      debugPrint('⚡ Starting parallel ML + AI processing...');

      // **PARALLEL PROCESSING**: Run ML and AI at the same time
      final results = await Future.wait([
        // Task 1: ML prediction (local, fast ~100-500ms)
        PredictionService.getPrediction(reading)
            .timeout(const Duration(seconds: 2), onTimeout: () => 'Unknown'),

        // Task 2: AI recommendation (API call, slower ~1-3s)
        _recommendationEnabled
            ? GeminiService.getRecommendation(reading)
                .then<String?>((v) => v)
                .timeout(const Duration(seconds: 8), onTimeout: () => null)
            : Future<String?>.value(null),
      ]);

      final prediction =
          results[0] is String ? results[0] as String : 'Unknown';
      final recommendation = results[1] is String ? results[1] as String : null;

      debugPrint('✅ Parallel processing complete: ML + AI done together');

      // Create updated reading with both predictions
      final updatedReading = reading.copyWith(
        prediction: prediction,
        recommendation: recommendation,
      );

      // Save to database (single write operation)
      try {
        await _supabaseService.updateReadingEnrichment(
          id: reading.id,
          prediction: prediction,
          recommendation: recommendation,
        );
        debugPrint('💾 Saved to Supabase → Ready for UI');
      } catch (e) {
        debugPrint('⚠️ Failed to save to database: $e');
        // Continue to show data even if save fails
      }

      // Update UI with fully processed data
      if (mounted) {
        setState(() => _currentReading = updatedReading);
      }

      // Check for alerts after everything is ready
      await _checkAlerts(updatedReading);

      debugPrint('✅ Flow: Sensor → Supabase → [ML ∥ AI] → Supabase → UI');
    } catch (e) {
      debugPrint('❌ Error in processing pipeline: $e');
      // Fallback: show raw data if processing fails
      if (mounted) {
        setState(() => _currentReading = reading);
      }
    } finally {
      final processingKey = _readingProcessingKey(reading);
      if (_processingReadingKey == processingKey) {
        _processingReadingKey = null;
      }
    }
  }

  Future<void> _loadSettings() async {
    final recommendationEnabled =
        await SettingsService.getRecommendationEnabled();
    final notificationEnabled = await SettingsService.getNotificationEnabled();

    if (!mounted) return;

    setState(() {
      _recommendationEnabled = recommendationEnabled;
      _notificationEnabled = notificationEnabled;
    });
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
      debugPrint('🔄 Fetching latest reading from Supabase...');
      final reading = await _supabaseService.getLatestReading();

      if (reading != null && mounted) {
        debugPrint(
            '✅ Got reading: pH=${reading.pH}, Temp=${reading.temp}°C, TDS=${reading.tds}');
        setState(() => _currentReading = reading);

        // If prediction/recommendation missing (e.g., initial fetch or after refresh),
        // run processing pipeline so UI doesn't stay at "Analyzing".
        if ((reading.prediction == null || reading.prediction!.isEmpty) ||
            (_recommendationEnabled &&
                (reading.recommendation == null ||
                    reading.recommendation!.isEmpty))) {
          debugPrint('⚙️ Post-fetch processing: generating ML + AI');
          await _processAndSaveReading(reading);
        } else {
          await _checkAlerts(reading);
        }
      } else {
        debugPrint('⚠️ No reading data returned from Supabase');
      }
    } catch (e) {
      debugPrint('❌ Error fetching data: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching data: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _checkAlerts(SensorReading reading) async {
    if (!_notificationEnabled) return;

    final isCritical = _isCriticalReading(reading);
    if (!isCritical) return;

    // Build a specific alert message showing WHAT is critical
    final criticalIssues = <String>[];
    final phThreshold = AppConfig.thresholds['pH']!;
    final tempThreshold = AppConfig.thresholds['temp']!;
    final tdsThreshold = AppConfig.thresholds['tds']!;

    if (reading.pH < phThreshold['criticalMin']!) {
      criticalIssues.add('pH too low (${reading.pH.toStringAsFixed(1)})');
    } else if (reading.pH > phThreshold['criticalMax']!) {
      criticalIssues.add('pH too high (${reading.pH.toStringAsFixed(1)})');
    }

    if (reading.temp < tempThreshold['criticalMin']!) {
      criticalIssues.add('Temp too low (${reading.temp.toStringAsFixed(1)}°C)');
    } else if (reading.temp > tempThreshold['criticalMax']!) {
      criticalIssues
          .add('Temp too high (${reading.temp.toStringAsFixed(1)}°C)');
    }

    if (reading.tds <= tdsThreshold['criticalMin']!) {
      criticalIssues.add('TDS too low (${reading.tds.toStringAsFixed(0)} ppm)');
    } else if (reading.tds > tdsThreshold['criticalMax']!) {
      criticalIssues
          .add('TDS too high (${reading.tds.toStringAsFixed(0)} ppm)');
    }

    if (criticalIssues.isEmpty) return;

    // Single consolidated notification
    final alertMessage = criticalIssues.join(', ');
    await NotificationService.showAlertNotification(
      title: '⚠️ Critical Water Quality Alert',
      body: alertMessage,
      dedupeKey: reading.id,
    );
  }

  bool _isCriticalReading(SensorReading reading) {
    final phThreshold = AppConfig.thresholds['pH']!;
    final tempThreshold = AppConfig.thresholds['temp']!;
    final tdsThreshold = AppConfig.thresholds['tds']!;

    return reading.pH < phThreshold['criticalMin']! ||
        reading.pH > phThreshold['criticalMax']! ||
        reading.temp < tempThreshold['criticalMin']! ||
        reading.temp > tempThreshold['criticalMax']! ||
        reading.tds <= tdsThreshold['criticalMin']! ||
        reading.tds > tdsThreshold['criticalMax']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          // Use only _currentReading - updated by interval timer
          final reading = _currentReading;

          if (reading == null) {
            return Stack(
              children: [
                const WaveBackground(),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sensors_off,
                          size: 64,
                          color: Color(0xFF94A3B8), // slate-400
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No sensor data available',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B), // slate-500
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchLatestReading,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9), // sky-500
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              // Animated wave background
              const WaveBackground(),
              // Content
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Water Metrics Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          WaterMetricCard(
                            label: 'pH Level',
                            value: reading.pH,
                            unit: 'pH',
                            status: _getMetricStatus(
                              reading.pH,
                              AppConfig.thresholds['pH']!,
                            ),
                            icon: Icons.science,
                          ),
                          WaterMetricCard(
                            label: 'Temperature',
                            value: reading.temp,
                            unit: '°C',
                            status: _getMetricStatus(
                              reading.temp,
                              AppConfig.thresholds['temp']!,
                            ),
                            icon: Icons.thermostat,
                          ),
                          WaterMetricCard(
                            label: 'TDS',
                            value: reading.tds,
                            unit: 'ppm',
                            status: _getMetricStatus(
                              reading.tds,
                              AppConfig.thresholds['tds']!,
                            ),
                            icon: Icons.water_drop,
                          ),
                          WaterMetricCard(
                            label: 'Ammonia',
                            value: reading.pH,
                            unit: 'Ammonia',
                            status: _getMetricStatus(
                              reading.pH,
                              AppConfig.thresholds['pH']!,
                            ),
                            icon: Icons.science,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ML Prediction Card - Always visible
                      _buildModernInfoCard(
                        title: 'ML WATER QUALITY PREDICTION',
                        content:
                            reading.prediction ?? 'Analyzing water quality...',
                        icon: Icons.psychology_outlined,
                        isPrediction: true,
                      ),
                      const SizedBox(height: 16),

                      // AI Recommendation Card - Optional based on settings
                      if (_recommendationEnabled)
                        FishHealthCard(
                          status: '', // Remove status display
                          description: reading.recommendation ??
                              'Generating recommendations...',
                          lastChecked: reading.timestamp,
                        ),
                      if (_recommendationEnabled) const SizedBox(height: 16),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: null,
    );
  }

  MetricStatus _getMetricStatus(double value, Map<String, double> thresholds) {
    if (value <= thresholds['criticalMin']! ||
        value > thresholds['criticalMax']!) {
      return MetricStatus.alert;
    } else if (value < thresholds['min']! || value > thresholds['max']!) {
      return MetricStatus.caution;
    } else {
      return MetricStatus.good;
    }
  }
}

Widget _buildModernInfoCard({
  required String title,
  required String content,
  required IconData icon,
  bool isPrediction = false,
}) {
  Color statusColor;
  Color bgColor;

  if (content.toLowerCase().contains('safe') ||
      content.toLowerCase().contains('good') ||
      content.toLowerCase().contains('excellent')) {
    statusColor = const Color(0xFF059669); // emerald-600
    bgColor = const Color(0xFFD1FAE5); // emerald-100
  } else if (content.toLowerCase().contains('caution') ||
      content.toLowerCase().contains('monitor') ||
      content.toLowerCase().contains('warning')) {
    statusColor = const Color(0xFFD97706); // amber-600
    bgColor = const Color(0xFFFEF3C7); // amber-100
  } else {
    statusColor = const Color(0xFFDC2626); // rose-600
    bgColor = const Color(0xFFFEE2E2); // rose-100
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.5),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: bgColor.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B), // slate-500
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1E293B), // slate-800
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
