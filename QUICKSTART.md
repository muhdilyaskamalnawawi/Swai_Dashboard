# SWAI Dashboard - Quick Start (5 Minutes)

## TL;DR Setup

### Step 1: Get Your Credentials (2 min)

**Supabase:**
1. Go to https://supabase.com/dashboard
2. Create new project
3. Go to Settings → API
4. Copy `Project URL` and `anon` key

**Gemini API:**
1. Go to https://ai.google.dev
2. Click "Get API Key"
3. Copy your API key

### Step 2: Add Credentials (1 min)

Open `lib/config/app_config.dart` and replace:
```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseKey = 'YOUR_ANON_KEY';
static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
```

### Step 3: Setup Database (1 min)

In Supabase dashboard, go to SQL Editor and run:
```sql
CREATE TABLE sensor_readings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pH FLOAT NOT NULL,
  temp FLOAT NOT NULL,
  tds FLOAT NOT NULL,
  prediction TEXT,
  recommendation TEXT,
  timestamp TIMESTAMP DEFAULT NOW(),
  is_alert BOOLEAN DEFAULT FALSE
);

ALTER PUBLICATION supabase_realtime ADD TABLE sensor_readings;
```

### Step 4: Add Your ML Model (1 min)

1. Place your `.tflite` file at: `assets/models/prediction_model.tflite`
2. Run: `flutter pub get`

### Step 5: Run! (< 1 min)

```bash
flutter run -d <device-id>
```

---

## Testing Without Real Sensors

### Option 1: Insert Test Data in Supabase

Go to Supabase dashboard → `sensor_readings` table → Insert row:
```
pH: 7.2
temp: 28.5
tds: 250
timestamp: (auto-filled)
```

### Option 2: Add Test Data Programmatically

In `dashboard_screen.dart`, add to `_initializeServices()`:
```dart
// Test data insertion
final testReading = SensorReading(
  id: 'test-${DateTime.now().millisecondsSinceEpoch}',
  pH: 7.2,
  temp: 28.5,
  tds: 250,
  prediction: 'Safe',
  recommendation: 'Continue monitoring',
  timestamp: DateTime.now(),
);
await _supabaseService.insertReading(testReading);
```

---

## Check That Everything Works

1. **Dashboard Tab** - Should show 3 gauges with test data
2. **History Tab** - Should show line chart
3. **Insert critical data** - Should show red alert banner
4. **Check notification** - Should pop notification (if permissions granted)

---

## Troubleshooting Quick Fixes

### "Connection Error"
→ Check `supabaseUrl` and `supabaseKey` in `app_config.dart`

### "No sensor data"
→ Insert test data in Supabase dashboard

### "Predictions blank"
→ Ensure `.tflite` file exists at `assets/models/prediction_model.tflite`

### "Recommendations blank"
→ Check `geminiApiKey` in `app_config.dart` and API quota at https://ai.google.dev

### "No notifications"
→ Grant permissions in app settings (Android)

---

## File Locations Quick Reference

| What | Where |
|------|-------|
| Credentials | `lib/config/app_config.dart` |
| ML Model | `assets/models/prediction_model.tflite` |
| Dashboard UI | `lib/screens/dashboard_screen.dart` |
| Database | `lib/services/supabase_service.dart` |
| Predictions | `lib/services/prediction_service.dart` |
| Recommendations | `lib/services/gemini_service.dart` |
| Notifications | `lib/services/notification_service.dart` |

---

## Next: Real Sensor Integration

Once you verify the test setup works:

1. **Node-RED Setup** - See `BACKEND_INTEGRATION.md`
2. **Connect Your Sensors** - HTTP/MQTT to Node-RED
3. **Flow to Supabase** - Node-RED inserts readings
4. **Real-time Updates** - Dashboard streams live data

---

## Full Documentation

- 📖 **SETUP_GUIDE.md** - Complete guide (all details)
- 🔌 **BACKEND_INTEGRATION.md** - Sensor integration
- 🏗️ **.github/copilot-instructions.md** - Architecture
- ✅ **BUILD_SUMMARY.md** - What was built

---

**You're all set! Your water quality monitoring app is ready to go! 💧**
