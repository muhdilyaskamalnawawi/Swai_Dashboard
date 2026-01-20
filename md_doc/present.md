# SWAI Dashboard (Smart WaterGuard) — Jury Presentation Notes

Date: 2026-01-12

## 1) Project summary (what problem it solves)
Smart WaterGuard (SWAI Dashboard) is a Flutter dashboard for aquaculture water-quality monitoring. It collects sensor readings (pH, temperature, TDS), stores them in a cloud database (Supabase), visualizes trends (charts/gauges), and triggers alerts when conditions become unsafe.

The “smart” part is:
- **On-device ML (TensorFlow Lite)** classification of water quality (Good / Moderate / Bad) with **confidence**.
- **Optional AI recommendations (Gemini)** that turns readings into short actionable advice.

## 2) Architecture (what runs where)

### Sensor layer (Arduino)
- Reads sensors and sends a JSON payload containing `pH/ph`, `temp/temperature`, `tds`, optionally a `timestamp`.
- Source: [ARDUINO_SENSOR_CODE_FIXED.ino](../ARDUINO_SENSOR_CODE_FIXED.ino)

### Backend ingestion + storage + optional Gemini (Python Flask)
- Receives readings at `POST /api/sensor/reading`.
- Normalizes payload keys (`pH` vs `ph`, `temperature` vs `temp`) and assigns timestamps.
- Computes:
  - rule-based status (`Good/Moderate/Bad`) + confidence (heuristic)
  - `is_alert` if readings are critical
  - optional Gemini recommendation (if API key is provided)
- Inserts row into Supabase table (`sensor_readings` by default).
- Source: [sensor_server.py](../sensor_server.py)

### Mobile/Desktop dashboard (Flutter)
- Loads environment config (`.env`), sets up background checks (Android WorkManager), and shows the dashboard UI.
- Entry: [lib/main.dart](../lib/main.dart)

## 3) ML component (what model, how it works)

### 3.1 Deployed model (on-device)
- **Model name / file:** `water_model_improved.tflite`
- **Location:** [assets/models/water_model_improved.tflite](../assets/models/water_model_improved.tflite)
- **Runtime:** `tflite_flutter` plugin
- **Inference code:** [lib/services/prediction_service.dart](../lib/services/prediction_service.dart)

### 3.2 Labels (class order)
The app assumes the output indices map to:
1. `Bad`
2. `Good`
3. `Moderate`

This is explicitly documented in:
- [assets/models/feature_info.txt](../assets/models/feature_info.txt)

### 3.3 Features (inputs)
The deployed pipeline supports a **5-feature model**, with feature order:
1. `pH`
2. `TDS`
3. `Temperature`
4. `pH_deviation = abs(pH - 7.0)`
5. `temp_normalized = (temp - 25.0) / 5.0`

Reference:
- [assets/models/feature_info.txt](../assets/models/feature_info.txt)
- Feature construction + ordering: [lib/services/prediction_service.dart](../lib/services/prediction_service.dart)

### 3.4 Preprocessing (StandardScaler)
The deployed model was trained with **StandardScaler normalization**. To match training-time preprocessing, the app contains scaler constants (mean and scale) and applies standardization when the model expects 5 features.

Where:
- Standardization constants + function: [lib/services/prediction_service.dart](../lib/services/prediction_service.dart)

### 3.5 Output probabilities + confidence
- The model outputs 3 values. If they already look like probabilities (all in [0,1] and sum ≈ 1), the app uses them directly.
- Otherwise, the app applies a **softmax** to get normalized probabilities.
- It reports:
  - **top class**
  - **top probability** = confidence
  - **confidence gap** = (top prob − 2nd prob), used as an uncertainty signal

Where:
- Softmax and probability checks: [lib/services/prediction_service.dart](../lib/services/prediction_service.dart)

### 3.6 Safety / fallback behavior
To avoid failures in real deployments:
- If model fails to load, the app falls back to a **rule-based** prediction.
- If `tds <= 0`, it treats this as invalid and returns “Unsafe” (sensor fault guard).
- If the model predicts `Moderate` but readings are clearly within safe ranges (with margins), the app can promote it to `Good` to keep output aligned with domain thresholds.

Where:
- Fallback and guards: [lib/services/prediction_service.dart](../lib/services/prediction_service.dart)

### 3.7 ML tests
Basic behavioral tests validate that sample readings map to Safe/Caution/Unsafe outputs.
- Source: [test/ml_test.dart](../test/ml_test.dart)

## 4) Training pipeline (code source for model training)

### 4.1 Primary training + export script
- Script: [create_compatible_model.py](../create_compatible_model.py)
- Trains a Keras Dense network and exports a TFLite model using built-in ops for compatibility.
- Notes:
  - The dataset path is currently hard-coded to a local Windows path.
  - It saves:
    - `water_model_improved.tflite` (deployed)
    - `scaler.pkl` (StandardScaler)
    - `label_encoder.pkl`

### 4.2 Confidence/accuracy upgrade scripts (experiments)
There are additional training/upgrade scripts in the repo used to improve performance and confidence calibration:
- [upgrade_model_confidence.py](../upgrade_model_confidence.py)
  - Adds engineered features, augmentation for imbalance, deeper model, checkpointing (`best_model.h5`).
- [upgrade_ml_model_advanced.py](../upgrade_ml_model_advanced.py)
  - Uses deeper architecture, dropout + L2, class weights, LR scheduling, early stopping.

Important presentation note:
- Some experimental scripts create a **6-feature** dataset; the deployed Flutter inference code is primarily designed around **3 or 5 features**. The deployed model should match the feature count expected in [lib/services/prediction_service.dart](../lib/services/prediction_service.dart).

### 4.3 Compatibility fixer
- [fix_model_compatibility.py](../fix_model_compatibility.py) explains how to re-export a Keras model into a more compatible TFLite format (built-ins only, optimized).

## 5) Thresholds / ranges (what is “safe” vs “critical”)

### 5.1 In Flutter (domain thresholds)
- Config: [lib/config/app_config.dart](../lib/config/app_config.dart)
- Safe ranges:
  - pH: 6.5–8.5
  - temp: 25–30 °C
  - TDS: 100–500 ppm
- Critical ranges:
  - pH critical: < 5.0 or > 10.0
  - temp critical: < 10 or > 45 °C
  - TDS critical: < 0 or > 1500 ppm

### 5.2 In backend (server thresholds)
- Backend uses the same ranges in [sensor_server.py](../sensor_server.py) to mark `is_alert` and for rule-based classification.

## 6) What to demo (2–3 minutes)
1. Open dashboard → show latest readings and history charts.
2. Show ML label output with confidence (Safe/Caution/Unsafe string).
3. Change to an unsafe scenario (e.g., high TDS or extreme pH) → show alert state + recommendation.
4. Mention robustness: ML + fallback rules + critical thresholds.

## 7) Code map (quick “where is what”)
- App entry: [lib/main.dart](../lib/main.dart)
- Model path constant: [lib/config/app_config.dart](../lib/config/app_config.dart)
- ML inference: [lib/services/prediction_service.dart](../lib/services/prediction_service.dart)
- Sensor reading model: [lib/models/sensor_reading.dart](../lib/models/sensor_reading.dart)
- Backend ingestion: [sensor_server.py](../sensor_server.py)
- Model training/export: [create_compatible_model.py](../create_compatible_model.py)
- ML tests: [test/ml_test.dart](../test/ml_test.dart)
- Model assets directory: [assets/models/](../assets/models/)

## 8) Conversation log (requirements gathered)
- User request: “Provide all things to tell jury… especially ML parts and code source.”
- Added: architecture + demo script + ML on-device details + training scripts + thresholds.
- User request: “Add model name, training code, ranges; document everything into present.md.”

