# TensorFlow Lite Model Setup

## Required: Add Your Model File

**Place your trained `.tflite` model file here:**
```
assets/models/prediction_model.tflite
```

## Model Requirements

### Input Format
The model should accept **3 features** as input:
- pH (float, typically 0-14)
- TDS (float, typically 0-1000 ppm)
- Temperature (float, typically 0-40°C)

Example input shape: `[1, 3]` (batch size 1, 3 features)

### Output Format
The model should output **3 class probabilities**:
- Index 0: Good (Safe water quality)
- Index 1: Moderate (Caution needed)
- Index 2: Bad (Unsafe water quality)

Example output shape: `[1, 3]` (batch size 1, 3 class probabilities)

## Converting Your Model to TFLite

If you have a Python TensorFlow/Keras model, convert it to TFLite format:

```python
import tensorflow as tf

# Load your trained model
model = tf.keras.models.load_model('your_model.h5')

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

# Save the model
with open('prediction_model.tflite', 'wb') as f:
    f.write(tflite_model)
```

## Model Location
The app expects the model at: `assets/models/prediction_model.tflite`

This path is configured in `lib/config/app_config.dart`:
```dart
static const String mlModelPath = 'assets/models/prediction_model.tflite';
```

## Adjusting Model Input/Output

If your model uses different input/output formats, update the code in `lib/services/prediction_service.dart`:

1. **Input format** (line ~45):
   ```dart
   final input = [[reading.pH, reading.tds, reading.temp]];
   ```

2. **Output shape** (line ~49):
   ```dart
   final output = List.filled(1, List.filled(3, 0.0))...
   ```

3. **Class mapping** (line ~60):
   ```dart
   const predictions = ['Good', 'Moderate', 'Bad'];
   ```

## Testing

After placing your model file:

1. Run `flutter pub get` to sync assets
2. Rebuild the app: `flutter run`
3. Check the console for:
   - ✓ TFLite model loaded successfully
   - Input/output shapes should match your model

If you see errors, the model file may be missing or have incompatible shapes.
