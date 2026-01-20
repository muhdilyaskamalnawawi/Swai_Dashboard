# SWAI Dashboard - App Architecture & Data Flow

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SWAI Dashboard App                          │
│                    (Flutter Mobile App)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
              ┌─────▼──┐ ┌────▼──┐ ┌───▼────┐
              │ Config │ │ Models│ │Widgets │
              │ & UI   │ │ &Data │ │ & UI   │
              └───┬────┘ └───┬───┘ └───┬────┘
                  │          │         │
                  └──────────┼─────────┘
                             │
                    ┌────────▼────────┐
                    │    Services     │
                    │   (Business     │
                    │    Logic)       │
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
     ┌────▼────┐      ┌──────▼───────┐   ┌────▼────┐
     │Supabase │      │ Prediction   │   │ Gemini  │
     │Database │      │ Service      │   │ Service │
     └────┬────┘      │ (ML Model)   │   └─────────┘
          │           └──────┬───────┘
          │                  │
     ┌────▼───────────────────┴─────────┐
     │   External Services & APIs       │
     │                                  │
     │ • Sensor Data (Arduino/Node-RED) │
     │ • Cloud Database (Supabase)      │
     │ • AI Recommendations (Gemini)    │
     └────────────────────────────────┘
```

---

## 🔄 Complete Data Flow (Step by Step)

### **Phase 1: App Initialization (Launch)**

```
1. main() is called
   ↓
2. WidgetsFlutterBinding.ensureInitialized()
   ├─ Prepares Flutter engine
   └─ Allows async operations before rendering
   ↓
3. Supabase.initialize(url, key)
   ├─ Connects to Supabase cloud database
   ├─ Sets up real-time listener
   └─ Creates authenticated session
   ↓
4. NotificationService.initialize()
   ├─ Sets up Android notification channels
   ├─ Requests iOS notification permissions
   └─ Prepares push notification system
   ↓
5. runApp(MyApp())
   ├─ Builds Flutter widget tree
   └─ Shows HomeScreen with bottom navigation
```

---

### **Phase 2: User Opens Dashboard Screen**

```
HomeScreen (Bottom Navigation)
  └─ User taps "Dashboard" tab
     └─ DashboardScreen is built
        ↓
        initState() is called:
        ├─ _initializeServices()
        │  ├─ PredictionService.initializeModel()
        │  │  └─ Loads TensorFlow Lite model (if desktop/Windows)
        │  │
        │  └─ GeminiService.initialize()
        │     └─ Sets up Gemini API connection
        │
        └─ _latestReadingStream = _supabaseService.getLatestReadingStream()
           └─ Creates LIVE stream subscription to Supabase
              ↓
              (Supabase sends latest sensor reading)
              ↓
              StreamBuilder rebuilds UI automatically
```

---

### **Phase 3: Real-Time Data Updates (Core Flow)**

#### **The Magic Loop** 🔁

```
┌──────────────────────────────────────────────────────────────┐
│                  REAL-TIME DATA CYCLE                        │
└──────────────────────────────────────────────────────────────┘

STEP 1: Arduino/Python Backend sends data
├─ Sends JSON: {pH: 7.2, temp: 28.5, tds: 250, timestamp: ...}
├─ Recommended: Arduino posts directly to Supabase REST
│  └─ https://<YOUR_PROJECT>.supabase.co/rest/v1/sensor_readings
└─ Optional: Python/Flask server receives at /api/sensor/reading and inserts into Supabase

STEP 2: Python Server stores data
├─ Validates readings against thresholds
├─ Checks if critical/warning alert
└─ Inserts into Supabase: sensor_readings table
   └─ Record: {id, pH, temp, tds, prediction, recommendation, timestamp, is_alert}

STEP 3: Supabase Realtime Emits Update
├─ Database change detected (NEW ROW INSERT)
├─ Realtime socket notifies all connected clients
└─ Flutter app receives update (subscription is ACTIVE)

STEP 4: Flutter UI Rebuilds (StreamBuilder)
├─ Receives new SensorReading object
├─ StreamBuilder detects data change
├─ Calls build() method
└─ UI re-renders with new values

STEP 5: Dashboard Screen Updates
├─ Gauge 1: pH = 7.2 ✓
├─ Gauge 2: Temp = 28.5°C ✓
├─ Gauge 3: TDS = 250 ppm ✓
├─ Prediction Card: "✓ Safe - Water quality is good (92.5% confidence)"
├─ Recommendation Card: "Your water quality is optimal for Red Tilapia..."
└─ Alert Banner: GREEN (no critical issues)

STEP 6: Check Alerts & Notifications
├─ _checkAlerts(reading) is called
├─ _isCriticalReading() evaluates thresholds
│  └─ pH: 6.5-8.5 safe ✓
│  └─ Temp: 25-30°C safe ✓
│  └─ TDS: 100-500 ppm safe ✓
├─ If CRITICAL:
│  ├─ GeminiService.generateAlertMessage(reading)
│  │  └─ "pH is 4.5 - CRITICAL! Pond is too acidic. Add lime treatment immediately."
│  │
│  └─ NotificationService.showAlertNotification()
│     └─ Red banner notification on phone
│        └─ User sees: "Water Quality Alert - pH is 4.5 - CRITICAL!..."
│
└─ Loop continues (waiting for next sensor reading)
```

---

## 📊 Service Architecture

### **1. Supabase Service** (Database Bridge)
```dart
SupabaseService
├─ getLatestReadingStream()         ← Real-time stream subscription
├─ getLatestReading()               ← One-time fetch
├─ getHistory(limit, dateRange)     ← Historical data for charts
├─ insertReading(reading)           ← Save reading to DB
└─ calculateStatistics()            ← Min/max/avg for analytics

Flow: SupabaseClient → PostgreSQL → Realtime Socket → Stream<SensorReading>
```

### **2. Prediction Service** (ML Engine)
```dart
PredictionService
├─ initializeModel(modelPath)       ← Load .tflite model
├─ getPrediction(reading)           ← Run inference
│  └─ Uses PythonMLService on Windows/Linux/macOS
│  └─ Returns: "Safe", "Moderate", "Bad" + confidence %
└─ _formatPredictionWithConfidence() ← Pretty print with %

Flow: SensorReading → Python subprocess → TensorFlow Lite → Prediction string
```

### **3. Gemini Service** (AI Recommendations)
```dart
GeminiService
├─ initialize()                     ← Setup API key
├─ getRecommendation(pH, temp, tds) ← Get treatment advice
├─ generateAlertMessage(reading)    ← Create alert text
└─ getDetailedAnalysis()            ← Deep-dive report

Flow: Sensor values → Gemini API prompt → LLM response → Formatted text
```

### **4. Notification Service** (Alerts)
```dart
NotificationService
├─ initialize()                     ← Setup Android/iOS channels
├─ showAlertNotification()          ← Critical alert (high priority)
├─ showInfoNotification()           ← Info alert (low priority)
└─ scheduleNotification()           ← Scheduled check

Flow: Critical condition → Notification payload → Local platform notification
```

---

## 🎨 UI Layer Architecture

### **Screen Hierarchy**
```
MyApp (Material 3 Theme)
└─ HomeScreen (Navigation Host)
   ├─ [0] DashboardScreen
   │  ├─ GaugeWidget (pH)
   │  ├─ GaugeWidget (Temp)
   │  ├─ GaugeWidget (TDS)
   │  ├─ Prediction Card
   │  ├─ Recommendation Card
   │  └─ Alert Banner (Red/Orange/Green)
   │
   ├─ [1] HistoryScreen
   │  ├─ FL Chart (Line chart)
   │  ├─ Metric Selector (pH/Temp/TDS)
   │  ├─ Date Range Picker (7/14/30 days)
   │  └─ Statistics Panel
   │
   └─ [2] FishInfoScreen
      ├─ TabBar (pH, TDS, Temperature)
      ├─ TabView 1: pH Guidelines
      ├─ TabView 2: TDS Guidelines
      └─ TabView 3: Temperature Guidelines
```

### **DashboardScreen Data Flow (Detailed)**
```dart
DashboardScreen
  ├─ initState()
  │  └─ _latestReadingStream = SupabaseService.getLatestReadingStream()
  │
  ├─ StreamBuilder<SensorReading?>
  │  └─ Listens to real-time updates
  │     ├─ ConnectionState.waiting → Loading spinner
  │     ├─ ConnectionState.active  → Show data
  │     │  └─ build(context, snapshot)
  │     │     ├─ Get: snapshot.data (current SensorReading)
  │     │     └─ Build widgets with values
  │     │
  │     └─ ConnectionState.done    → Error state
  │
  ├─ GaugeWidget(pH: reading.pH)
  │  └─ Syncfusion Gauge renders visual needle
  │
  ├─ PredictionCard
  │  ├─ Calls: PredictionService.getPrediction(reading)
  │  └─ Shows: "✓ Safe (92.5% confidence)"
  │
  ├─ RecommendationCard
  │  ├─ Calls: GeminiService.getRecommendation(...)
  │  └─ Shows: "Your water is optimal for Red Tilapia..."
  │
  ├─ AlertBanner
  │  ├─ _isCriticalReading() → RED banner + sound
  │  ├─ _isWarningReading()  → ORANGE banner
  │  └─ _isNormalReading()   → GREEN banner
  │
  ├─ FAB (Floating Action Button)
  │  └─ Tap to manually refresh
  │     └─ _fetchLatestReading()
  │
  └─ Async Alert Check
     ├─ _checkAlerts(reading)
     ├─ If critical:
     │  ├─ Get alert message from Gemini
     │  └─ Show push notification
     └─ If warning:
        └─ Show SnackBar (temporary)
```

---

## 🔌 External Connections

### **1. Arduino → Python Backend → Supabase**

```
ESP32 (Arduino)
  ↓ (POST JSON)
Python Flask Server (192.168.8.48:8000)
  ├─ Receives: {pH, temp, tds, timestamp}
  ├─ Validates readings
  ├─ Checks thresholds
  └─ INSERT into Supabase
      ↓
      Supabase sensor_readings table
      ├─ Stores: {id, pH, temp, tds, prediction, recommendation, timestamp, is_alert}
      └─ Emits: Realtime event to all subscribed clients
```

### **2. Supabase Real-Time Subscription**

```
SupabaseService.getLatestReadingStream()
  ├─ Creates: RealtimeChannel subscription
  ├─ Listens to: sensor_readings table changes
  ├─ On INSERT/UPDATE:
  │  └─ Emits: new SensorReading object via Stream
  │
  └─ Flutter StreamBuilder receives update
     └─ Rebuilds UI with new data
```

### **3. Prediction Service (Desktop ML)**

```
Windows/Linux/macOS (has Python)
  ├─ PredictionService.getPrediction()
  ├─ Spawns Python subprocess:
  │  └─ python predict_tflite.py 7.2 250 28.5
  │
  └─ TensorFlow Lite model evaluates:
     ├─ Input: [pH=7.2, TDS=250, Temp=28.5]
     ├─ Processing: Neural network inference
     └─ Output: {Prediction: "Good", Confidence: 0.925}
```

### **4. Gemini API Integration**

```
GeminiService.getRecommendation(pH=7.2, temp=28.5, tds=250)
  ├─ Builds prompt:
  │  └─ "pH is 7.2 (safe range 6.5-8.5), temp is 28.5°C (safe 25-30)...
  │     Red Tilapia farming context... Provide treatment recommendation"
  │
  ├─ HTTP POST to Google Gemini API
  ├─ LLM generates response
  └─ Returns: "Your water is optimal for Red Tilapia farming..."
```

---

## 📈 State Management & Lifecycle

### **Widget Lifecycle in DashboardScreen**

```
┌─────────────────────────────────────────────────────┐
│  DashboardScreen (StatefulWidget)                   │
└─────────────────────────────────────────────────────┘
         │
         ↓
    initState() ← ONE TIME
    ├─ Create _latestReadingStream (subscription)
    ├─ Initialize PredictionService
    └─ Initialize GeminiService
         │
         ↓
    build() ← CALLED MULTIPLE TIMES
    ├─ Returns Scaffold with StreamBuilder
    └─ StreamBuilder listens to _latestReadingStream
         │
         ├─ NEW DATA arrives (sensor reading)
         ├─ StreamBuilder detects change
         └─ Calls build() again with new snapshot
              │
              ├─ Gauge values update
              ├─ Prediction card updates
              ├─ Recommendation card updates
              ├─ Alert banner updates
              └─ UI re-renders (hot reload style)
         │
         ↓
    dispose() ← CLEANUP
    └─ Close streams, cancel subscriptions
```

### **Stream Pattern (Real-Time Magic)**

```dart
// CREATES SUBSCRIPTION
late Stream<SensorReading?> _latestReadingStream = 
    _supabaseService.getLatestReadingStream();

// LISTENS TO UPDATES
StreamBuilder<SensorReading?>(
  stream: _latestReadingStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.active) {
      // NEW DATA RECEIVED
      final reading = snapshot.data;
      return GaugeWidget(value: reading.pH);  // UPDATED UI
    }
  }
)
```

---

## 🎯 Key Design Patterns Used

### **1. Service Layer Pattern**
- Business logic separated from UI
- Each service has single responsibility
- Example: `SupabaseService` only handles database operations

### **2. Singleton Pattern**
- `GeminiService`, `PredictionService` initialized once
- Reused across the app
- Prevents multiple API connections

### **3. Stream Pattern**
- Real-time data subscription
- `StreamBuilder` rebuilds UI when data arrives
- No polling needed, very efficient

### **4. Repository Pattern**
- `SupabaseService` acts as data repository
- App doesn't know about database implementation
- Easy to swap backends (e.g., Firebase instead of Supabase)

### **5. Model-View-Controller (MVC)**
- Models: `SensorReading` (data structure)
- Views: Screens & Widgets (UI)
- Controllers: Services (business logic)

---

## 📊 Example: Complete Data Journey (One Reading)

```
TIME: 10:30 AM
════════════════════════════════════════════════════════════

ESP32 Sensor reads:
  pH = 4.5 (CRITICAL LOW!)
  Temp = 28.5°C
  TDS = 250 ppm
                   ↓
Python Backend receives POST
  Validates: pH 4.5 < criticalMin 5.0 ✗ CRITICAL
                   ↓
Inserts into Supabase
  sensor_readings table
  {
    id: uuid(),
    pH: 4.5,
    temp: 28.5,
    tds: 250,
    timestamp: "2025-12-12T10:30:00Z",
    is_alert: true,
    prediction: null,
    recommendation: null
  }
                   ↓
Supabase REALTIME SOCKET emits:
  "INSERT into sensor_readings..."
                   ↓
Flutter App receives via subscription
  StreamBuilder detects update
  snapshot.data = new SensorReading(pH: 4.5, ...)
                   ↓
DashboardScreen rebuilds:
  ├─ Gauge 1 (pH) needle moves to 4.5 (RED ZONE)
  ├─ PredictionService.getPrediction() called
  │  └─ Python subprocess:
  │     "python predict_tflite.py 4.5 250 28.5"
  │     → Output: "Bad" (0.15 confidence)
  ├─ Prediction card shows:
  │  "✗ Unsafe - Water treatment recommended (15.0% confidence)"
  ├─ GeminiService.getRecommendation() called
  │  → Gemini API response:
  │     "CRITICAL ALERT! pH 4.5 is dangerously acidic.
  │      Your Red Tilapia will not survive. Immediate action:
  │      1. Add 50kg hydrated lime per hectare
  │      2. Re-test pH in 2 hours
  │      3. Target: pH 6.8-7.2"
  ├─ Recommendation card shows: (above text)
  ├─ Alert Banner turns RED with pulsing animation
  └─ _checkAlerts() detects critical condition
     ├─ GeminiService.generateAlertMessage()
     │  → "pH CRITICAL: 4.5 (safe: 5.0-10.0). 
     │     Pond too acidic. Add lime treatment now!"
     │
     └─ NotificationService.showAlertNotification()
        → Android: Red banner + alarm sound
        → iPhone: Banner notification + vibration
        → App log: "🚨 CRITICAL ALERT TRIGGERED"

USER SEES:
  ✓ Real-time gauge moving to dangerous zone
  ✓ Prediction: "Unsafe"
  ✓ Red alert banner on screen
  ✓ Detailed Gemini recommendations
  ✓ Push notification with emergency message
  ✓ All within 1-2 seconds of sensor reading!

════════════════════════════════════════════════════════════
```

---

## 🚀 Performance Considerations

| Component | Performance | Notes |
|-----------|-------------|-------|
| **Supabase Streaming** | ⚡ <500ms | Real-time socket connection, very fast |
| **ML Prediction** | ⚡ 50-200ms | On-device TensorFlow Lite, no network lag |
| **Gemini API** | ⚠️ 1-3 seconds | Cloud API, network dependent |
| **UI Rebuild** | ⚡ <100ms | Flutter Hot Reload fast |
| **Notification** | ⚡ Instant | Local notification, no network needed |

---

## 🔐 Data Security Flow

```
Arduino → HTTPS POST → Python Backend
                          ↓
                   Validate & Check
                          ↓
                    Supabase HTTPS
                          ↓
                   Encrypted Storage
                          ↓
                   Flutter App HTTPS
                          ↓
                    Encrypted Cache
                          ↓
                       User Screen
```

---

## 📝 Summary: The Complete Loop

1. **Data Sources**: Arduino/sensors collect water quality data
2. **Backend Receiver**: Python Flask server validates and stores
3. **Cloud Database**: Supabase stores and broadcasts changes
4. **Real-time Transport**: WebSocket sends updates to app instantly
5. **AI Processing**: ML prediction + Gemini recommendations run
6. **Alert System**: Critical conditions trigger notifications
7. **User Interface**: Dashboard visualizes everything in real-time
8. **Loop Repeats**: Every 30 seconds (configurable)

**Result**: User sees live water quality monitoring with AI insights! 🌊📱✨
