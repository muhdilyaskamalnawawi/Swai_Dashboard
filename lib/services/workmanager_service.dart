import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/app_config.dart';
import 'background_monitor_service.dart';
import 'notification_service.dart';

const String waterQualityCheckTask = 'waterQualityCheckTask';
const String waterQualityWorkUniqueName = 'waterQualityCheck';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // Supabase must be initialized in this headless isolate.
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseKey,
      );
    } catch (_) {
      // Ignore: Supabase may already be initialized in some app states.
    }

    // Local notifications plugin init (no permission prompts in background).
    try {
      await NotificationService.initialize(requestPermissions: false);
    } catch (_) {
      // Ignore: plugin may already be initialized.
    }

    switch (task) {
      case waterQualityCheckTask:
        await BackgroundMonitorService.checkWaterQualityOnce(
          fromBackground: true,
        );
        break;
      default:
        break;
    }

    return true;
  });
}

class WorkmanagerService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    _initialized = true;
  }

  /// Register periodic background checks.
  ///
  /// Note: Android WorkManager enforces a minimum periodic interval of 15 minutes.
  static Future<void> registerPeriodicWaterQualityCheck({
    Duration frequency = const Duration(minutes: 15),
  }) async {
    await initialize();

    final normalized = frequency < const Duration(minutes: 15)
        ? const Duration(minutes: 15)
        : frequency;

    await Workmanager().registerPeriodicTask(
      waterQualityWorkUniqueName,
      waterQualityCheckTask,
      frequency: normalized,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Useful for manual testing (runs ASAP).
  static Future<void> runOneOffWaterQualityCheck() async {
    await initialize();
    await Workmanager().registerOneOffTask(
      '${waterQualityWorkUniqueName}_oneoff_${DateTime.now().millisecondsSinceEpoch}',
      waterQualityCheckTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> cancelWaterQualityCheck() async {
    await Workmanager().cancelByUniqueName(waterQualityWorkUniqueName);
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
