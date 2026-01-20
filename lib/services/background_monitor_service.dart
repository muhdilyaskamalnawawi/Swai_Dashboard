import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../models/sensor_reading.dart';
import '../config/app_config.dart';

/// Background monitoring service that checks water quality even when app is closed
/// Uses polling mechanism to check for critical conditions
class BackgroundMonitorService {
  static Timer? _monitorTimer;
  static bool _isMonitoring = false;
  static final _supabaseService = SupabaseService();

  /// Start background monitoring with polling interval
  static Future<void> startMonitoring({
    Duration interval = const Duration(minutes: 5),
  }) async {
    if (_isMonitoring) {
      debugPrint('⚠️ Monitoring already active');
      return;
    }

    debugPrint('🔄 Starting background monitoring (interval: $interval)');
    _isMonitoring = true;

    // Initial check
    await _checkWaterQuality();

    // Set up periodic checks
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (timer) async {
      await _checkWaterQuality();
    });
  }

  /// Stop background monitoring
  static void stopMonitoring() {
    debugPrint('🛑 Stopping background monitoring');
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
  }

  /// Check water quality and send notifications if critical
  static Future<void> _checkWaterQuality() async {
    await checkWaterQualityOnce(fromBackground: false);
  }

  /// Check water quality once (used by in-app polling and WorkManager).
  static Future<void> checkWaterQualityOnce({
    required bool fromBackground,
  }) async {
    try {
      final notificationEnabled =
          await SettingsService.getNotificationEnabled();
      if (!notificationEnabled) {
        debugPrint('🔕 Notifications disabled, skipping check');
        return;
      }

      debugPrint(
          '🔍 Checking water quality${fromBackground ? ' (background)' : ''}...');
      final reading = await _supabaseService.getLatestReading();

      if (reading == null) {
        debugPrint('⚠️ No sensor data available');
        return;
      }

      // Check if this is a new reading (persisted so it also works across
      // WorkManager executions).
      final lastBackgroundId =
          await SettingsService.getLastBackgroundReadingId();
      if (lastBackgroundId != null && reading.id == lastBackgroundId) {
        debugPrint('✓ No new data (last checked: ${reading.timestamp})');
        return;
      }

      await SettingsService.setLastBackgroundReadingId(reading.id);
      debugPrint(
          '✅ New reading: pH=${reading.pH}, Temp=${reading.temp}°C, TDS=${reading.tds}');

      // Check if reading is critical
      if (_isCriticalReading(reading)) {
        debugPrint('🚨 CRITICAL reading detected!');
        final lastCriticalNotifiedId =
            await SettingsService.getLastCriticalNotifiedReadingId();
        if (lastCriticalNotifiedId == reading.id) {
          debugPrint('⏭️ Already notified critical for reading: ${reading.id}');
          return;
        }
        await _sendCriticalAlert(reading);
        await SettingsService.setLastCriticalNotifiedReadingId(reading.id);
      } else if (_isWarningReading(reading)) {
        debugPrint('⚠️ Warning reading detected');
        final lastWarningNotifiedId =
            await SettingsService.getLastWarningNotifiedReadingId();
        if (lastWarningNotifiedId == reading.id) {
          debugPrint('⏭️ Already notified warning for reading: ${reading.id}');
          return;
        }
        await _sendWarningAlert(reading);
        await SettingsService.setLastWarningNotifiedReadingId(reading.id);
      } else {
        debugPrint('✅ Water quality is good');
      }
    } catch (e) {
      debugPrint('❌ Background check error: $e');
    }
  }

  /// Check if reading is critical
  static bool _isCriticalReading(SensorReading reading) {
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

  /// Check if reading is in warning range
  static bool _isWarningReading(SensorReading reading) {
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

  /// Send critical alert notification
  static Future<void> _sendCriticalAlert(SensorReading reading) async {
    final issues = <String>[];

    final phThreshold = AppConfig.thresholds['pH']!;
    if (reading.pH < phThreshold['criticalMin']!) {
      issues.add('pH CRITICALLY LOW (${reading.pH.toStringAsFixed(1)})');
    } else if (reading.pH > phThreshold['criticalMax']!) {
      issues.add('pH CRITICALLY HIGH (${reading.pH.toStringAsFixed(1)})');
    }

    final tempThreshold = AppConfig.thresholds['temp']!;
    if (reading.temp < tempThreshold['criticalMin']!) {
      issues.add('Temperature TOO COLD (${reading.temp.toStringAsFixed(1)}°C)');
    } else if (reading.temp > tempThreshold['criticalMax']!) {
      issues.add('Temperature TOO HOT (${reading.temp.toStringAsFixed(1)}°C)');
    }

    final tdsThreshold = AppConfig.thresholds['tds']!;
    if (reading.tds <= tdsThreshold['criticalMin']!) {
      issues.add('TDS TOO LOW (${reading.tds.toStringAsFixed(0)} ppm)');
    } else if (reading.tds > tdsThreshold['criticalMax']!) {
      issues.add('TDS TOO HIGH (${reading.tds.toStringAsFixed(0)} ppm)');
    }

    final message = issues.join('\n');

    await NotificationService.showAlertNotification(
      title: '🚨 CRITICAL WATER ALERT',
      body: 'IMMEDIATE ACTION REQUIRED!\n$message',
      dedupeKey: reading.id,
    );
  }

  /// Send warning alert notification
  static Future<void> _sendWarningAlert(SensorReading reading) async {
    final issues = <String>[];

    final phThreshold = AppConfig.thresholds['pH']!;
    if (reading.pH < phThreshold['min']!) {
      issues.add('pH LOW (safe ${phThreshold['min']}-${phThreshold['max']})');
    } else if (reading.pH > phThreshold['max']!) {
      issues.add('pH HIGH (safe ${phThreshold['min']}-${phThreshold['max']})');
    }

    final tempThreshold = AppConfig.thresholds['temp']!;
    if (reading.temp < tempThreshold['min']!) {
      issues.add(
          'Temp LOW (safe ${tempThreshold['min']}-${tempThreshold['max']}°C)');
    } else if (reading.temp > tempThreshold['max']!) {
      issues.add(
          'Temp HIGH (safe ${tempThreshold['min']}-${tempThreshold['max']}°C)');
    }

    final tdsThreshold = AppConfig.thresholds['tds']!;
    if (reading.tds < tdsThreshold['min']!) {
      issues.add(
          'TDS LOW (safe ${tdsThreshold['min']}-${tdsThreshold['max']} ppm)');
    } else if (reading.tds > tdsThreshold['max']!) {
      issues.add(
          'TDS HIGH (safe ${tdsThreshold['min']}-${tdsThreshold['max']} ppm)');
    }

    final issuesText = issues.isEmpty ? '' : '\n${issues.join('\n')}';

    await NotificationService.showInfoNotification(
      title: '⚠️ Water Quality Warning',
      body: 'pH: ${reading.pH.toStringAsFixed(1)}\n'
          'Temp: ${reading.temp.toStringAsFixed(1)}°C\n'
          'TDS: ${reading.tds.toStringAsFixed(0)} ppm$issuesText',
      dedupeKey: reading.id,
    );
  }

  /// Force immediate check (useful for manual refresh)
  static Future<void> forceCheck() async {
    debugPrint('🔄 Force checking water quality...');
    await _checkWaterQuality();
  }

  /// Get monitoring status
  static bool get isMonitoring => _isMonitoring;
}
