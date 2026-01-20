import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _recommendationEnabledKey = 'recommendation_enabled';
  static const String _autoRefreshKey = 'auto_refresh';
  static const String _notificationEnabledKey = 'notification_enabled';
  static const String _lastBackgroundReadingIdKey =
      'last_background_reading_id';
  static const String _lastCriticalNotifiedReadingIdKey =
      'last_critical_notified_reading_id';
  static const String _lastWarningNotifiedReadingIdKey =
      'last_warning_notified_reading_id';

  // Get settings
  static Future<bool> getRecommendationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_recommendationEnabledKey) ?? true; // Default: enabled
  }

  static Future<bool> getAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoRefreshKey) ?? true; // Default: enabled
  }

  static Future<bool> getNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationEnabledKey) ?? true; // Default: enabled
  }

  static Future<String?> getLastBackgroundReadingId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastBackgroundReadingIdKey);
  }

  static Future<void> setLastBackgroundReadingId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackgroundReadingIdKey, id);
  }

  static Future<String?> getLastCriticalNotifiedReadingId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCriticalNotifiedReadingIdKey);
  }

  static Future<void> setLastCriticalNotifiedReadingId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCriticalNotifiedReadingIdKey, id);
  }

  static Future<String?> getLastWarningNotifiedReadingId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastWarningNotifiedReadingIdKey);
  }

  static Future<void> setLastWarningNotifiedReadingId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastWarningNotifiedReadingIdKey, id);
  }

  // Set settings
  static Future<void> setRecommendationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recommendationEnabledKey, enabled);
  }

  static Future<void> setAutoRefresh(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRefreshKey, enabled);
  }

  static Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);
  }

  // Clear all settings (reset to defaults)
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recommendationEnabledKey);
    await prefs.remove(_autoRefreshKey);
    await prefs.remove(_notificationEnabledKey);
    await prefs.remove(_lastBackgroundReadingIdKey);
    await prefs.remove(_lastCriticalNotifiedReadingIdKey);
    await prefs.remove(_lastWarningNotifiedReadingIdKey);
  }

  // Get app version
  static String getAppVersion() {
    return '1.0.0'; // Update this with each release
  }
}
