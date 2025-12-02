/// Application configuration constants
class AppConfig {
  // Supabase Configuration - Update with your credentials
  static const String supabaseUrl = 'https://jrybjofyxppwicvgflpz.supabase.co';
  static const String supabaseKey = 'sb_secret_tdP1pQNqoDS5mXHmz_CF-w_orfeERyT';

  // Gemini API Configuration - Update with your API key
  static const String geminiApiKey = 'AIzaSyCfZC4dXs9oTDCnvzpPzgkbTO0jwfpBVtQ';

  // ML Model Configuration
  static const String mlModelPath = 'assets/models/prediction_model.tflite';

  // Sensor Thresholds (define what counts as "critical")
  static const Map<String, Map<String, double>> thresholds = {
    'pH': {
      'min': 6.5,
      'max': 8.5,
      'criticalMin': 5.0,
      'criticalMax': 10.0,
    },
    'temp': {
      'min': 25.0,
      'max': 30.0,
      'criticalMin': 10.0,
      'criticalMax': 45.0,
    },
    'tds': {
      'min': 100.0,
      'max': 500.0,
      'criticalMin': 0.0,
      'criticalMax': 1500.0,
    },
  };

  // API endpoints (if using external API for sensor data)
  static const String apiBaseUrl = 'YOUR_API_BASE_URL';
}
