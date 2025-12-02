# SWAI Dashboard - Copilot Instructions

## Project Overview
SWAI Dashboard is a comprehensive Flutter IoT application for real-time water quality monitoring. It integrates cloud database (Supabase), local ML predictions, AI recommendations (Gemini), and critical alert notifications.

### Core Features
- **Real-time Dashboard**: Gauges for pH, temperature, TDS with live updates
- **AI Predictions**: Local TensorFlow Lite model for water quality assessment
- **Smart Recommendations**: Gemini API for context-aware treatment guidance
- **History Visualization**: Line charts for time-series sensor data
- **Critical Alerts**: Local push notifications for threshold violations
- **Cloud Sync**: Supabase for persistent storage and real-time streaming

## Architecture & Data Flow

### High-Level System Design
```
Physical Sensors / Node-RED API
        ↓
   Supabase Database (sensor_readings table)
        ↓
   Real-time Stream (getLatestReadingStream)
        ↓
    DashboardScreen
    ├─ ML Model → Prediction
    ├─ Gemini API → Recommendation
    ├─ GaugeWidget (pH, Temp, TDS)
    ├─ AlertNotification (if critical)
    └─ HistoryScreen (time-series chart)
```

### Component Responsibilities

**Data Layer: `lib/models/sensor_reading.dart`**
- Immutable `SensorReading` with 8 fields (id, pH, temp, tds, prediction, recommendation, timestamp, isAlert)
- Bidirectional JSON mapping via `toJson()` and `fromJson()` factory
- Type coercion with `??` for robustness against null values
- **Critical**: Maps backend field names (pH, temp, TDS capitalized variants)

**Database: `lib/services/supabase_service.dart`**
- CRUD operations on `sensor_readings` table
- Real-time stream via `getLatestReadingStream()` (subscription pattern)
- Bulk queries with date range filters: `getHistory(limit, startDate, endDate)`
- Statistics calculation (min/max/avg) for dashboard analytics
- **Init**: Static `Supabase.instance.client` from main.dart

**ML Inference: `lib/services/prediction_service.dart`**
- Loads `.tflite` model from `assets/models/prediction_model.tflite`
- Input format: `[[pH, temp, TDS]]` (adjust if model differs)
- Output: String classification (Safe/Caution/Unsafe)
- **Important**: `initializeModel()` must be called before `getPrediction()`

**AI Recommendations: `lib/services/gemini_service.dart`**
- Singleton pattern with `initialize()` on first call
- Prompt templates contextualized by sensor ranges (pH 6.5-8.5, temp 25-30°C, TDS 100-500 ppm)
- Three methods: `getRecommendation()` (single), `generateAlertMessage()` (critical), `getDetailedAnalysis()` (deep-dive)
- Stream support for real-time text generation

**Notifications: `lib/services/notification_service.dart`**
- Android & iOS channel setup in `initialize()` (call in `main()`)
- Two alert types: `showAlertNotification()` (high priority) vs `showInfoNotification()` (low)
- Timezone-aware scheduling via `scheduleNotification()`
- **Check**: Manifest permissions & iOS entitlements before deployment

**UI Layer: `lib/screens/`**
- **`home_screen.dart`**: Bottom navigation container (Dashboard ↔ History)
- **`dashboard_screen.dart`**: Stateful, streams latest reading, shows gauges + cards, refreshes on FAB tap
  - Alert banner: Red if critical (pH/temp/TDS outside safety limits), orange if warning
  - Real-time updates via `StreamBuilder` on `getLatestReadingStream()`
- **`history_screen.dart`**: FL Chart line graph, metric selector (pH/Temp/TDS), date range picker (7/14/30 days)
  - Statistics card shows avg/min/max for selected period
  - Responsive layout with batch loading (limit 1000 rows)

**Gauges: `lib/widgets/gauge_widget.dart`**
- Syncfusion `SfRadialGauge` with 3 color zones (red-safe-red)
- Thresholds hardcoded per metric: pH 6.5-8.5, temp 25-30, TDS 100-500
- Threshold config in `lib/config/app_config.dart` for centralized maintenance

## Critical Patterns & Conventions

### Real-Time Updates
- Dashboard auto-subscribes via `_latestReadingStream` in `initState()`
- `StreamBuilder` rebuilds UI when Supabase emits new rows
- No manual polling needed; subscription-based for efficiency

### Error Handling
- Services throw exceptions; UI catches and shows `SnackBar` or `CircularProgressIndicator`
- No retry logic by default; production should add exponential backoff
- Fallback states (e.g., "No sensor data available") for graceful degradation

### Threshold Checks
Performed in `DashboardScreen._isCriticalReading()` and `_isWarningReading()`:
- **Critical**: Outside `criticalMin/Max` (e.g., pH < 5 or > 10)
- **Warning**: Outside `min/max` safe range (e.g., pH < 6.5 or > 8.5)
- Triggers alert notifications and UI banner changes

### State Management
- No Provider pattern currently (despite being in pubspec); pure `setState()`
- Consider adopting Provider if app grows (search + load prediction/recommendation concurrently)
- Local state (gauge values, chart data) lives in screen StatefulWidgets

### Backend Integration
- `ApiService.baseUrl` placeholder; update with Node-RED or IoT backend URL
- `AppConfig` contains environment secrets; never commit actual values
- JSON mapping resilient to field name variations (pH vs ph, Temp vs temp)

### ML Model Integration
- Model must be `.tflite` format, placed in `assets/models/`
- Input/output normalization defined in `PredictionService._interpretPrediction()`
- Adjust thresholds (0.7 = Safe, 0.4 = Caution, <0.4 = Unsafe) per model accuracy

## Common Development Tasks

### Adding a New Sensor Metric (e.g., Turbidity)
1. Add field to `SensorReading`: `final double turbidity;`
2. Update `fromJson()` mapping: `turbidity: json['turbidity']?.toDouble() ?? 0`
3. Create Supabase migration: `ALTER TABLE sensor_readings ADD turbidity FLOAT;`
4. Add to `AppConfig.thresholds` with safe/critical ranges
5. Add `GaugeWidget` in `DashboardScreen.build()` with min/max/ranges
6. Include in `HistoryScreen` metric selector toggle
7. Retrain ML model if prediction depends on this metric

### Connecting Node-RED Backend
1. Update `AppConfig.apiBaseUrl` to Node-RED server IP:1880
2. Create Node-RED flow: MQTT input → parse → Supabase insert
3. Configure Supabase credentials in flow (see `BACKEND_INTEGRATION.md`)
4. Test with: `curl http://IP:1880/api/water-quality/latest`
5. Verify data appears in Supabase dashboard

### Customizing Alert Thresholds
1. Edit `AppConfig.thresholds`: adjust `criticalMin`, `criticalMax`, `min`, `max`
2. Thresholds apply to `_isCriticalReading()` and `_isWarningReading()` logic
3. Update `GeminiService.generateAlertMessage()` prompt if threshold semantics change

### Enabling Local ML Model
1. Place trained `.tflite` file at `assets/models/prediction_model.tflite`
2. Run `flutter pub get` to sync assets
3. Model loads in `DashboardScreen.initState()` → `PredictionService.initializeModel()`
4. Predictions show in dashboard card on every reading update

### Testing with Mock Data
```dart
// Insert test reading
final test = SensorReading(
  id: 'test-${DateTime.now().millisecondsSinceEpoch}',
  pH: 7.2, temp: 28.5, tds: 250,
  prediction: 'Safe', recommendation: 'Monitor',
  timestamp: DateTime.now(),
);
await SupabaseService().insertReading(test);
```

## Unused/Outdated Dependencies
- `fl_chart: ^0.68.0` ← Updated from 1.1.1 (was broken)
- `provider: ^6.1.5` ← In pubspec but unused; consider removing or adopting
- `chart_widget.dart` ← References old `charts_flutter` package; replaced by FL Chart in `HistoryScreen`

## Build & Run

```bash
# Install/update dependencies
flutter pub get
flutter pub upgrade

# Run linter
flutter analyze

# Format code
flutter format lib/

# Run on device
flutter run -d <device-id>

# Build release APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

## Pre-Deployment Checklist

- [ ] Supabase credentials in `app_config.dart` (URL, anon key)
- [ ] Gemini API key configured and quota verified
- [ ] `.tflite` model file at `assets/models/prediction_model.tflite`
- [ ] Android manifest includes `POST_NOTIFICATIONS` permission
- [ ] iOS `Info.plist` has network usage description
- [ ] Node-RED backend online and reachable at configured URL
- [ ] Notification channels created on first app launch
- [ ] Threshold values reviewed and tuned for your sensors
- [ ] Run `flutter analyze` with zero warnings
- [ ] Test alert notifications with critical threshold data

## Documentation References
- **Setup Guide**: `SETUP_GUIDE.md` – Complete initialization steps
- **Backend Integration**: `BACKEND_INTEGRATION.md` – Node-RED + Supabase flows
- **Architecture Details**: This file (copilot-instructions.md)

## Performance Tips

1. **Limit history queries** to last 7-30 days; use `startDate`/`endDate` filters
2. **Batch ML predictions** via `PredictionService.batchPredict()` for bulk analysis
3. **Debounce Gemini calls**: Cache recent recommendations to avoid API quota exhaustion
4. **Stream optimization**: Use `StreamBuilder` key to prevent unnecessary rebuilds
5. **Database indexing**: Ensure Supabase has index on `timestamp` for fast range queries

## Future Enhancements

- [ ] Authentication system (Supabase Auth)
- [ ] Multi-location/device support
- [ ] Export data to CSV/PDF
- [ ] Offline mode with local SQLite sync
- [ ] Advanced analytics dashboard
- [ ] Treatment schedule planner
- [ ] User-configurable alert rules
- [ ] Historical trending analysis
