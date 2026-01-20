# ML Model Confidence Upgrade Guide

## 🎯 What's Been Upgraded

Your ML model has been enhanced with advanced techniques to improve prediction confidence and accuracy:

### Key Improvements

1. **Data Augmentation** ✓
   - Balanced minority classes using noise injection
   - Improved class distribution for better predictions

2. **Feature Engineering** ✓
   - Added pH deviation (distance from neutral pH 7.0)
   - Added normalized temperature feature
   - Model now uses 5 features instead of 3

3. **Enhanced Neural Network** ✓
   - Deeper architecture: 64 → 32 → 16 neurons
   - Batch normalization for training stability
   - L2 regularization to prevent overfitting
   - Dropout layers (30% → 21% → 15%)

4. **Advanced Training Techniques** ✓
   - Early stopping with best weights restoration
   - Learning rate scheduling (adaptive reduction)
   - Cross-validation for robust performance estimation
   - Custom metrics: Accuracy, Precision, Recall

5. **Smart Flutter Integration** ✓
   - Automatic feature detection (3 or 5 features)
   - Enhanced logging with probability distributions
   - Backward compatible with old models

## 🚀 How to Use

### Step 1: Run the Upgrade Script

Open a terminal and activate your Python environment:

```powershell
cd C:\Users\HP\swai_dashboard
.venv\Scripts\Activate.ps1
python upgrade_model_confidence.py
```

### Expected Output

You should see:
```
🚀 SWAI Water Quality ML Model - Confidence Upgrade
====================================================================
📊 Loading dataset...
✓ Dataset loaded: XXX rows, X columns

🔄 Applying data augmentation...
✓ Augmented dataset: XXX rows

🎯 Training model...
Epoch 1/150
...

📊 Test Set Performance:
  ✓ Accuracy: XX.XX%
  ✓ Precision: XX.XX%
  ✓ Recall: XX.XX%

✅ MODEL UPGRADE COMPLETE!
```

### Step 2: Verify Model Files

Check that these files were created:
```
assets/models/
  ├── water_model_improved.tflite  (Updated with enhanced model)
  ├── scaler.pkl                    (Feature scaling parameters)
  ├── label_encoder.pkl             (Class label mapping)
  └── feature_info.txt              (Feature documentation)
```

### Step 3: Test in Flutter App

```powershell
flutter clean
flutter pub get
flutter run
```

Watch the console for:
```
✓ TFLite model loaded successfully
  Input shape: [1, 5]
  Output shape: [1, 3]

🤖 ML Prediction: Good (95.3% confidence)
   Probabilities: 95.3%, 3.2%, 1.5%
```

## 📊 Performance Metrics

### Before Upgrade (Basic Model)
- Features: 3 (pH, TDS, Temperature)
- Architecture: Simple 32→16→8
- Typical accuracy: ~75-85%
- Confidence: Often low or uncertain

### After Upgrade (Enhanced Model)
- Features: 5 (pH, TDS, Temp, pH deviation, Temp normalized)
- Architecture: Advanced 64→32→16 with BatchNorm
- Expected accuracy: **85-95%**
- Confidence: Higher and more reliable

## 🔧 Customization Options

### Adjust Training Parameters

Edit `upgrade_model_confidence.py`:

```python
# Line 20-25: Hyperparameters
EPOCHS = 150              # More epochs = better training (but slower)
BATCH_SIZE = 16           # Smaller = more updates, larger = faster
LEARNING_RATE = 0.001     # Lower = more stable, higher = faster convergence
DROPOUT_RATE = 0.3        # Higher = more regularization

# Line 28-29: Validation
USE_CROSS_VALIDATION = True  # Enable/disable CV
CV_FOLDS = 5                 # Number of CV folds
```

### Add More Features

To add additional sensor readings (turbidity, dissolved oxygen, etc.):

1. **Update dataset**: Add columns to your CSV file
2. **Update script** (`upgrade_model_confidence.py` line 48):
   ```python
   feature_cols = ['pH', 'TDS', 'Temperature', 'Turbidity', 'DO']
   ```
3. **Update Flutter** ([prediction_service.dart](lib/services/prediction_service.dart)):
   ```dart
   } else if (numFeatures == 7) {
     // Extended model with more sensors
     features = [
       reading.pH, 
       reading.tds, 
       reading.temp,
       reading.turbidity,
       reading.dissolvedOxygen,
       phDeviation,
       tempNormalized,
     ];
   }
   ```

### Change Model Architecture

In `upgrade_model_confidence.py` line 180-210:

```python
def create_model(input_dim, num_classes, learning_rate=0.001, dropout_rate=0.3):
    model = tf.keras.Sequential([
        # Adjust these layers
        tf.keras.layers.Dense(128, activation='relu'),  # Bigger = more capacity
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.4),
        
        tf.keras.layers.Dense(64, activation='relu'),
        # ... add more layers
    ])
```

## 🧪 Testing & Validation

### Test Individual Predictions

Add test code to the script:

```python
# At the end of upgrade_model_confidence.py
test_cases = [
    {'pH': 7.0, 'TDS': 300, 'Temperature': 27.5},  # Should be Good
    {'pH': 5.5, 'TDS': 800, 'Temperature': 35.0},  # Should be Bad
    {'pH': 8.2, 'TDS': 520, 'Temperature': 28.0},  # Should be Moderate
]

for test in test_cases:
    # Prepare features with engineering
    features = [
        test['pH'], 
        test['TDS'], 
        test['Temperature'],
        abs(test['pH'] - 7.0),
        (test['Temperature'] - 25.0) / 5.0
    ]
    features_scaled = scaler.transform([features])
    
    # Predict
    interpreter.set_tensor(input_details[0]['index'], features_scaled.astype(np.float32))
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    
    predicted_class = np.argmax(output[0])
    confidence = output[0][predicted_class] * 100
    
    print(f"Test: {test}")
    print(f"  → {label_encoder.classes_[predicted_class]} ({confidence:.1f}%)")
```

### Compare with Previous Model

Keep your old model as backup:

```powershell
# Before running upgrade script
cp assets/models/water_model_improved.tflite assets/models/water_model_old.tflite

# After upgrade, to revert if needed:
cp assets/models/water_model_old.tflite assets/models/water_model_improved.tflite
```

## 📈 Monitoring Model Performance

### In Your Flutter App

The enhanced prediction service now logs detailed info:

```dart
// lib/screens/dashboard_screen.dart
// Already using getPrediction(), but watch console output:

🤖 ML Prediction: Good (95.3% confidence)
   Probabilities: 95.3%, 3.2%, 1.5%
```

### Collect Feedback for Retraining

Add user feedback mechanism:

```dart
// lib/services/feedback_service.dart
Future<void> submitFeedback({
  required SensorReading reading,
  required String userLabel,  // What user thinks it should be
}) async {
  await SupabaseService().insert('prediction_feedback', {
    'pH': reading.pH,
    'tds': reading.tds,
    'temp': reading.temp,
    'model_prediction': reading.prediction,
    'user_label': userLabel,
    'timestamp': DateTime.now().toIso8601String(),
  });
}
```

Then periodically export feedback and retrain:

```sql
-- In Supabase SQL editor
SELECT * FROM prediction_feedback 
WHERE timestamp > NOW() - INTERVAL '1 month'
ORDER BY timestamp DESC;
```

## 🐛 Troubleshooting

### Issue: Model accuracy too low

**Solution**: Collect more training data
- Aim for 500+ samples per class
- Ensure balanced distribution
- Label data carefully

### Issue: High confidence but wrong predictions

**Solution**: Calibrate confidence scores
```python
# In upgrade_model_confidence.py, after training
from sklearn.calibration import CalibratedClassifierCV

# This requires sklearn-compatible model, so convert predictions:
calibrated_probs = calibrate_predictions(model, X_val, y_val)
```

### Issue: Input shape mismatch error

**Solution**: Check feature count
```dart
// In Flutter console, you'll see:
✗ Failed to load TFLite model: Input tensor has 5 dimensions but 3 were provided
```

Make sure your Flutter code matches the Python script's `feature_cols`.

### Issue: Model file too large for mobile

**Solution**: Apply quantization
```python
# In upgrade_model_confidence.py, line 350
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]  # Add this line
```

## 📚 Next Steps

1. **Collect More Data**: The more quality data, the better the model
2. **Add More Sensors**: Turbidity, DO, ammonia for comprehensive analysis
3. **Implement Time-Series**: Use LSTM to capture temporal patterns
4. **Deploy Online Learning**: Update model with user feedback
5. **A/B Testing**: Compare model versions in production

## 🎓 Learning Resources

- [TensorFlow Lite Guide](https://www.tensorflow.org/lite/guide)
- [Neural Network Architectures](https://cs231n.github.io/)
- [Data Augmentation Techniques](https://arxiv.org/abs/1904.12848)
- [Model Confidence Calibration](https://arxiv.org/abs/1706.04599)

## ✅ Quick Checklist

Before deploying upgraded model:

- [ ] Script ran successfully with >80% accuracy
- [ ] Model file created at `assets/models/water_model_improved.tflite`
- [ ] Feature info saved with correct feature count
- [ ] Flutter app loads model without errors
- [ ] Console shows "Input shape: [1, 5]" (or your feature count)
- [ ] Sample predictions show high confidence (>80%)
- [ ] Tested with known Good/Bad water samples
- [ ] Backup of old model created
- [ ] Documentation updated with new features

## 🆘 Need Help?

Check these files for more details:
- [ML_UPGRADE_GUIDE.md](ML_UPGRADE_GUIDE.md) - Comprehensive strategies
- [ML_MODEL_INTEGRATION.md](ML_MODEL_INTEGRATION.md) - Integration details
- [ARCHITECTURE_EXPLAINED.md](ARCHITECTURE_EXPLAINED.md) - System architecture

## 📊 Model Performance Log

Keep track of your improvements:

| Date | Accuracy | Precision | Recall | Features | Notes |
|------|----------|-----------|--------|----------|-------|
| Baseline | 78% | 75% | 72% | 3 | Original model |
| After upgrade | __% | __% | __% | 5 | Feature engineering |
| With more data | __% | __% | __% | 5 | Added 500 samples |

---

**Remember**: Better data > Better model architecture. Focus on collecting quality, labeled data for best results! 🎯
