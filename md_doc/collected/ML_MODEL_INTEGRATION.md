# Python ML Model Integration Guide

## Your ML Model

**Location**: `C:\Users\HP\Documents\smart_wgai\water_model.pkl`  
**Type**: Scikit-learn classifier  
**Input**: `[pH, TDS, Temperature]`  
**Output**: Prediction class → `{0: 'Good', 1: 'Moderate', 2: 'Bad'}`

---

## How It Works

Your Flutter app now integrates with your Python ML model:

### 1. **Python Integration Service**
- File: `lib/services/python_ml_service.dart`
- Calls your `predict.py` script via Python subprocess
- Parses JSON response
- Returns prediction string

### 2. **Prediction Service (Updated)**
- File: `lib/services/prediction_service.dart`
- **Primary**: Uses Python model (your trained model)
- **Fallback**: Can use TFLite if available
- Auto-detects model availability

### 3. **Prediction Output Mapping**

```
Python Model Output    →    Dashboard Display
─────────────────────────────────────────────
Good                   →    ✓ Safe
Moderate               →    ⚠ Caution
Bad                    →    ✗ Unsafe
```

---

## Setup Instructions

### Step 1: Verify Python Installation
```bash
python --version
# Should output: Python 3.x.x
```

### Step 2: Verify Dependencies
```bash
pip list | findstr joblib
# Should show: joblib X.X.X
```

### Step 3: Verify Model File
```powershell
Test-Path 'C:\Users\HP\Documents\smart_wgai\water_model.pkl'
# Should return: True
```

### Step 4: Test Python Script Directly
```bash
python 'C:\Users\HP\Documents\smart_wgai\predict.py' 7.2 250 28.5
# Should output JSON like:
# {"pH": 7.2, "TDS": 250, "Temp": 28.5, "Prediction": "Good"}
```

---

## How the Integration Works

### 1. Dashboard collects sensor data:
```dart
pH: 7.2, TDS: 250, Temp: 28.5
```

### 2. Calls PredictionService.getPrediction():
```dart
final prediction = await PredictionService.getPrediction(reading);
// Calls Python model internally
```

### 3. PythonMLService runs Python script:
```python
python predict.py 7.2 250 28.5
```

### 4. Script returns JSON:
```json
{
  "pH": 7.2,
  "TDS": 250,
  "Temp": 28.5,
  "Prediction": "Good"
}
```

### 5. Result displayed on dashboard:
```
Prediction Card: ✓ Safe - Water quality is good
```

---

## Model Availability Checking

Check if everything is set up correctly:

```dart
// In your code:
bool isModelReady = await PythonMLService.isAvailable();

if (isModelReady) {
  print('✓ Python model is ready to use');
} else {
  print('✗ Python model or dependencies missing');
}
```

---

## Troubleshooting

### Issue: "Python not found"
**Solution**: Add Python to system PATH
```bash
setx PATH "%PATH%;C:\Python312"
# Restart terminal and try again
```

### Issue: "joblib module not found"
**Solution**: Install joblib
```bash
pip install joblib
```

### Issue: "water_model.pkl not found"
**Solution**: Verify model file path
```powershell
Get-Item 'C:\Users\HP\Documents\smart_wgai\water_model.pkl'
```

### Issue: "Prediction unavailable" in app
**Solution**: Check debug output
```
I/flutter (12345): Error running prediction: ...
```

---

## Alternative: Convert to TensorFlow Lite

If you want to run the model entirely on-device without Python:

```python
# convert_to_tflite.py
import tensorflow as tf
import joblib
import numpy as np

# Load sklearn model
model = joblib.load('water_model.pkl')

# Create TFLite converter
# (method depends on your model architecture)

# Save as .tflite
# tflite_model.write_bytes(open('model.tflite', 'wb').write)
```

Then place at: `assets/models/prediction_model.tflite`

---

## Model Information from Your Script

```python
# Input Order (from predict.py):
ph = sys.argv[1]      # First argument
tds = sys.argv[2]     # Second argument  
temp = sys.argv[3]    # Third argument

# Model Training:
model.predict([[ph, temp, tds]])

# Output Labels:
{0: 'Good', 1: 'Moderate', 2: 'Bad'}
```

---

## Current Configuration

In your `lib/config/app_config.dart`:

```dart
static const String mlModelPath = 'assets/models/prediction_model.tflite';
// ^ Used if converting to TFLite in future
```

Your Python model is called automatically by `PythonMLService`.

---

## Testing the Integration

### Manual Test
```dart
// In dashboard_screen.dart or any screen:
final prediction = await PredictionService.getPrediction(
  SensorReading(
    id: 'test',
    pH: 7.2,
    temp: 28.5,
    tds: 250,
    prediction: '',
    recommendation: '',
    timestamp: DateTime.now(),
  ),
);
print(prediction);
// Output: ✓ Safe - Water quality is good
```

### Check Model Availability
```dart
bool available = await PythonMLService.isAvailable();
print(available ? '✓ Ready' : '✗ Not ready');
```

---

## Next Steps

1. ✅ Run app with `flutter run`
2. ✅ Check dashboard for predictions
3. ✅ Monitor debug logs for errors
4. ✅ Test with different sensor values
5. ✅ (Optional) Convert to TFLite for offline use

---

## Files Modified

- `lib/services/prediction_service.dart` - Updated to use Python model
- `lib/services/python_ml_service.dart` - **NEW** - Python integration

---

## Model Statistics

- **Type**: Scikit-learn classifier (joblib format)
- **Input Features**: 3 (pH, TDS, Temperature)
- **Output**: 3 classes (Good, Moderate, Bad)
- **Location**: `C:\Users\HP\Documents\smart_wgai\water_model.pkl`
- **Script**: `C:\Users\HP\Documents\smart_wgai\predict.py`

---

Ready to use! Your trained model is now integrated into the Flutter app. 🚀
