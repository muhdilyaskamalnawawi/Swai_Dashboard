# SWAI Dashboard – Architecture & SRS Reference (Jan 2026)

## 1. Executive Summary
- Purpose: Real-time water quality monitoring with on-device ML predictions and Gemini-driven recommendations.
- Platforms: Flutter (Android/iOS/desktop), Supabase backend, optional Python edge inference.
- Key flows: Sensor ingest → Supabase → real-time stream to app → ML prediction → Gemini advice → alerts/notifications.

## 2. System Context (Level 0)
```
[Physical Sensors/ESP32] → [Node-RED/Python API] → [Supabase DB + Realtime]
                                          ↓
                               [SWAI Dashboard Flutter App]
                                          ↓
                             [Local Notifications + Gemini]
```

## 3. High-Level Architecture (Level 1)
- Presentation: Flutter screens/widgets (Dashboard, History, Fish Info) using M3 design.
- Domain Model: `SensorReading` (id, pH, temp, tds, prediction, recommendation, timestamp, isAlert).
- Services:
  - `SupabaseService`: CRUD, realtime stream, history queries, statistics.
  - `PredictionService`: TFLite inference; Python subprocess fallback on desktop.
  - `GeminiService`: Recommendations, alert text, detailed analysis.
  - `NotificationService`: Channels init, alert/info/scheduled notifications.
- Config: `AppConfig` for thresholds, API keys, base URLs.
- Assets: `assets/models/prediction_model.tflite` (or updated model path).

## 4. Detailed Data Flow (Happy Path)
1) Sensor posts reading to backend (Node-RED/Flask) → Supabase `sensor_readings` insert.
2) Supabase Realtime emits change → `getLatestReadingStream()` delivers `SensorReading` to app.
3) Dashboard `StreamBuilder` rebuilds:
   - Gauges update (pH/temp/tds).
   - `PredictionService.getPrediction()` returns class + confidence.
   - `GeminiService.getRecommendation()` returns treatment advice.
   - `_isCriticalReading()`/`_isWarningReading()` decide banner color and notifications.
4) Alerts:
   - Critical → `generateAlertMessage()` + `showAlertNotification()`.
   - Warning → Snackbar/visual warning.
5) History view uses `getHistory()` with date filters and shows FL Chart + min/max/avg.

## 5. Module Responsibilities
- `lib/main.dart`: App init, Supabase client boot, NotificationService init, route to HomeScreen.
- `lib/config/app_config.dart`: Thresholds (min/max/critical), API URLs/keys placeholders.
- `lib/models/sensor_reading.dart`: JSON ↔ object mapping, null-safe defaults.
- `lib/services/supabase_service.dart`: Realtime stream, latest fetch, history queries, stats, insert.
- `lib/services/prediction_service.dart`: Load TFLite model, run inference, confidence formatting, rule-based fallback.
- `lib/services/gemini_service.dart`: Singleton, prompt templates, recommendation/alert/detailed analysis.
- `lib/services/notification_service.dart`: Init channels, alert/info/scheduled notifications.
- `lib/screens/dashboard_screen.dart`: Real-time UI, gauges, prediction/recommendation cards, alert banner, FAB refresh.
- `lib/screens/history_screen.dart`: Metric selector, date filters (7/14/30 days), FL Chart, stats panel.
- `lib/screens/home_screen.dart`: Bottom navigation (Dashboard/History/Fish Info).
- `lib/widgets/gauge_widget.dart`: Syncfusion radial gauges with colored zones.

## 6. Data Model
`sensor_readings` table
- id (uuid)
- pH (float)
- temp (float °C)
- tds (float ppm)
- prediction (text)
- recommendation (text)
- timestamp (timestamptz)
- is_alert (bool)

JSON mapping tolerates casing variants (pH/ph/P_H, temp/Temp, TDS/tds).

## 7. API & Integration Points
- Supabase: Realtime channel on `sensor_readings`; RPC via Supabase Flutter SDK.
- Backend ingest: HTTP POST from Node-RED/Arduino/Python to Supabase (or via Supabase REST/RPC).
- Gemini: `google_generative_ai` SDK; requires `GEMINI_API_KEY` in config.
- Notifications: `flutter_local_notifications` with platform channels; permissions required on Android 13+/iOS.

## 8. Functional Requirements (selected)
- FR1: Display latest pH/temp/tds values on Dashboard with gauges and status banner.
- FR2: Subscribe to realtime updates; UI refresh ≤500 ms after Supabase emit.
- FR3: Run on-device prediction for each new reading; show class + confidence.
- FR4: Provide AI recommendation per reading; show in card.
- FR5: Trigger critical and warning alerts based on thresholds; send local notification for critical.
- FR6: History screen shows time-series chart, metric selector, and stats over selectable ranges (7/14/30 days).
- FR7: Manual refresh via FAB on Dashboard.
- FR8: Offline-safe notifications (queued locally); data sync resumes when online.

## 9. Non-Functional Requirements
- Performance: Dashboard render <2s cold start; inference 50–200 ms; Gemini call 1–3 s.
- Availability: Realtime stream auto-reconnect; graceful degradation to last cached reading.
- Reliability: Handle null/partial payloads with defaults; avoid crashes on stream errors.
- Security: Do not hardcode secrets; use RLS on Supabase; enforce HTTPS; rate-limit ingest endpoints.
- Maintainability: Service-layer abstraction; centralized thresholds in `AppConfig`; typed model.
- Observability: Log inference errors and Gemini failures; surface user-facing messages on fallback.

## 10. Threshold Logic (AppConfig-driven)
- Safe ranges (example): pH 6.5–8.5, temp 25–30°C, tds 100–500 ppm.
- Critical ranges: outside criticalMin/criticalMax (e.g., pH <5 or >10).
- Warning ranges: outside safe min/max but inside critical bounds.
- Used by `DashboardScreen._isCriticalReading()` / `_isWarningReading()` for banner + notifications.

## 11. ML Inference
- Model: `assets/models/prediction_model.tflite`, input [[pH, tds, temp]], output class probabilities [Good, Moderate, Bad].
- Init: `PredictionService.initializeModel()` must run before inference (Splash/init).
- Fallback: Rule-based classification if model fails to load or subprocess fails.
- Desktop: Python subprocess path for compatibility; ensure `.venv` activated when running from desktop.

## 12. Gemini Recommendations
- Singleton init on first call.
- Prompt contextualizes thresholds: pH 6.5–8.5, temp 25–30°C, tds 100–500 ppm.
- Methods: `getRecommendation()`, `generateAlertMessage()`, `getDetailedAnalysis()`; supports streaming responses.

## 13. Notifications
- `initialize()` configures Android/iOS channels; request permissions.
- `showAlertNotification()` for critical; `showInfoNotification()` for minor; `scheduleNotification()` for timed reminders.
- Ensure Android POST_NOTIFICATIONS permission and iOS entitlements.

## 14. Deployment & Ops
- Config: Set Supabase URL/key, Gemini key in `app_config.dart` (or env/secret manager for production builds).
- Assets: Place model at `assets/models/prediction_model.tflite`; run `flutter pub get` after changes to pubspec/assets.
- Lint/format: `flutter analyze`; `flutter format lib/`.
- Build: `flutter build apk --release`; `flutter build ios --release`.
- Pre-flight checklist: credentials present, notification permissions, model file exists, backend reachable.

## 15. Testing Guidance
- Unit: `SensorReading` JSON mapping; threshold functions; prediction formatting.
- Integration: Supabase stream end-to-end; Gemini call mocked; notification trigger paths.
- UI: StreamBuilder states (loading/active/error), history chart renders for all ranges, alert banner color logic.
- ML: Validate model input/output shapes; verify fallback path when model missing.

## 16. Risks & Mitigations
- Gemini quota/latency → cache recent recommendations; handle timeouts gracefully.
- Missing model file → rule-based fallback with user-visible warning.
- Supabase downtime → retry/backoff; show cached data with stale indicator.
- Threshold drift → centralize edits in `AppConfig`; keep prompts aligned with threshold semantics.
- Large history queries → cap to 7–30 days; use indexes on `timestamp`.

## 17. Change Log
- 2026-01-08: Consolidated architecture + SRS reference; cleaned README conflict footer; removed generated build artifacts.
