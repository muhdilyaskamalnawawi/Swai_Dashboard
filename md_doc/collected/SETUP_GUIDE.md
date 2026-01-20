# SWAI Dashboard - Complete Setup Guide

## Overview
SWAI Dashboard is a full-featured IoT mobile application built with Flutter that monitors water quality in real-time with AI-powered predictions and recommendations.

### Key Features
✅ **Real-time Dashboard** - Monitor 3 sensor metrics (pH, Temperature, TDS)  
✅ **AI Predictions** - Local ML model for water quality predictions  
✅ **Smart Recommendations** - Gemini AI-powered treatment recommendations  
✅ **History Tracking** - Time-series visualization with line charts  
✅ **Alert Notifications** - Critical threshold alerts with smart messaging  
✅ **Supabase Integration** - Cloud database with real-time sync  

## Architecture

### Data Flow
```
Physical Sensors → Supabase Database
                ↓
           ML Model (Local) → Prediction
           
           Gemini API → Recommendation
                ↓
         Real-time Stream
                ↓
    DashboardScreen Display
           ↓
    History Tracking
```

### Project Structure
```
lib/
├── main.dart                      # App initialization & Supabase setup
├── config/
│   └── app_config.dart           # Configuration constants
├── models/
│   └── sensor_reading.dart       # SensorReading data class
├── services/
│   ├── supabase_service.dart     # Database operations
│   ├── prediction_service.dart   # Local ML inference
│   ├── gemini_service.dart       # AI recommendations
│   ├── api_service.dart          # HTTP endpoints
│   └── notification_service.dart # Alert notifications
├── screens/
│   ├── home_screen.dart          # Main navigation
│   ├── dashboard_screen.dart     # Real-time sensor view
│   └── history_screen.dart       # Historical data & charts
└── widgets/
    ├── gauge_widget.dart         # Syncfusion gauges
    └── chart_widget.dart         # Chart displays
```

## Setup Instructions

### 1. Prerequisites
- Flutter SDK 3.7.0+
- Node.js (for backend integration)
- Supabase account (https://supabase.com)
- Google Gemini API key (https://ai.google.dev)
- Trained TensorFlow Lite model (.tflite)

### 2. Supabase Database Setup

#### Create table `sensor_readings`:
```sql
CREATE TABLE sensor_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pH FLOAT NOT NULL,
  temp FLOAT NOT NULL,
  tds FLOAT NOT NULL,
  prediction TEXT,
  recommendation TEXT,
  timestamp TIMESTAMP DEFAULT NOW(),
  is_alert BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Enable real-time subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE sensor_readings;
```

### 3. Configure Application

#### `lib/config/app_config.dart`
```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseKey = 'YOUR_ANON_KEY';
static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
static const String mlModelPath = 'assets/models/prediction_model.tflite';
```

### 4. Add ML Model

1. Place your trained `.tflite` model at: `assets/models/prediction_model.tflite`
2. Update `pubspec.yaml` to include the asset:
```yaml
flutter:
  assets:
    - assets/models/prediction_model.tflite
```

### 5. Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 6. iOS Permissions

Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs to access your network for water quality data</string>
<key>NSBonjourServiceTypes</key>
<array>
  <string>_http._tcp</string>
</array>
```

### 7. Install Dependencies
```bash
flutter pub get
flutter pub upgrade
```

### 8. Run the App
```bash
flutter run -d <device-id>
```

## Integration Points

### Backend API Integration

Update `lib/services/api_service.dart` to integrate with your sensor data source:

```dart
Future<SensorReading> fetchLatestFromSensor() async {
  final response = await http.get(
    Uri.parse('YOUR_SENSOR_API_ENDPOINT/latest'),
  );
  if (response.statusCode == 200) {
    final reading = SensorReading.fromJson(json.decode(response.body));
    // Store in Supabase
    await _supabaseService.insertReading(reading);
    return reading;
  }
  throw Exception('Failed to fetch sensor data');
}
```

### Node-RED Integration

Example Node-RED flow for sensor data insertion:
```json
{
  "nodes": [
    {
      "type": "http in",
      "url": "/api/sensor/data",
      "method": "post"
    },
    {
      "type": "function",
      "func": "msg.payload = {pH: msg.payload.pH, temp: msg.payload.temp, tds: msg.payload.tds}; return msg;"
    },
    {
      "type": "supabase-insert",
      "table": "sensor_readings"
    }
  ]
}
```

### Real-time Data Updates

The app subscribes to real-time updates automatically via:
```dart
_latestReadingStream = _supabaseService.getLatestReadingStream();
```

## Customization

### Adjust Alert Thresholds

Modify `lib/config/app_config.dart`:
```dart
static const Map<String, Map<String, double>> thresholds = {
  'pH': {
    'min': 6.5,      // Safe minimum
    'max': 8.5,      // Safe maximum
    'criticalMin': 5.0,    // Alert minimum
    'criticalMax': 10.0,   // Alert maximum
  },
  // ... etc
};
```

### Custom ML Model

Update `lib/services/prediction_service.dart`:
```dart
static Future<String> getPrediction(SensorReading reading) async {
  List<List<double>> input = [[reading.pH, reading.temp, reading.tds]];
  var output = [0.0];  // Adjust based on model output
  _interpreter!.run(input, output);
  return _interpretPrediction(output[0]);
}
```

### Notification Types

Add custom notifications in `lib/services/notification_service.dart`:
```dart
static Future<void> showWarningNotification({...}) async {
  // Custom warning logic
}
```

## Testing

### Test Data Insertion
```dart
// Insert test reading into Supabase
final testReading = SensorReading(
  id: 'test-${DateTime.now().millisecondsSinceEpoch}',
  pH: 7.2,
  temp: 28.5,
  tds: 250,
  prediction: 'Safe',
  recommendation: 'Continue monitoring',
  timestamp: DateTime.now(),
);
await SupabaseService().insertReading(testReading);
```

### Test Predictions
```dart
// Test ML model
final prediction = await PredictionService.getPrediction(testReading);
print('Prediction: $prediction');
```

### Test Recommendations
```dart
// Test Gemini API
final recommendation = await GeminiService.getRecommendation(testReading);
print('Recommendation: $recommendation');
```

## Troubleshooting

### Issue: "No sensor data available"
- **Solution**: Check Supabase connection in `app_config.dart`
- Verify database has data using Supabase dashboard

### Issue: Predictions not showing
- **Solution**: Ensure `.tflite` model is at `assets/models/prediction_model.tflite`
- Check model input/output format matches `PredictionService`

### Issue: Recommendations fail (Gemini API)
- **Solution**: Verify Gemini API key in `app_config.dart`
- Check API quota at https://ai.google.dev

### Issue: Notifications not working
- **Solution**: Check Android/iOS permissions in manifest
- Test with `NotificationService.showAlertNotification()`

## Performance Tips

1. **Limit history queries**: Use `limit` parameter in `getHistory()`
2. **Batch predictions**: Use `batchPredict()` for multiple readings
3. **Cache recommendations**: Store recent recommendations to reduce API calls
4. **Debounce updates**: Avoid excessive state rebuilds with proper `StreamBuilder` keys

## API Reference

### SupabaseService
- `getLatestReading()` - Fetch most recent sensor reading
- `getHistory(limit, startDate, endDate)` - Fetch readings in date range
- `insertReading(reading)` - Save new reading to database
- `getLatestReadingStream()` - Stream real-time updates
- `getStatistics(startDate, endDate)` - Calculate min/max/avg

### PredictionService
- `initializeModel(path)` - Load TensorFlow Lite model
- `getPrediction(reading)` - Generate prediction
- `batchPredict(readings)` - Predict for multiple readings

### GeminiService
- `initialize()` - Setup Gemini model
- `getRecommendation(reading)` - Get AI recommendation
- `generateAlertMessage(reading)` - Create alert text
- `getDetailedAnalysis(reading, issue)` - Detailed explanation

### NotificationService
- `initialize()` - Setup notification channels
- `showAlertNotification(title, body)` - Critical alert
- `showInfoNotification(title, body)` - Info message
- `scheduleNotification(...)` - Schedule future alert

## Development Workflow

```bash
# Get dependencies
flutter pub get

# Run code analysis
flutter analyze

# Format code
flutter format lib/

# Run app
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

## Future Enhancements

- [ ] Water treatment schedules
- [ ] Export data to CSV/PDF
- [ ] Multi-location support
- [ ] Push notifications from backend
- [ ] Advanced ML analytics
- [ ] Offline mode with sync
- [ ] User authentication
- [ ] Settings/preferences screen

## Support

For issues or questions:
1. Check `.github/copilot-instructions.md` for architecture
2. Review example integrations in this guide
3. Test services individually before integration
4. Enable debug logging in services

---

**Last Updated**: December 2024
