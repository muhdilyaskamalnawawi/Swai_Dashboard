# ML Model Upgrade Guide

## Current State
- Model: `water_model_improved.tflite`
- Input: pH, TDS, Temperature (3 features)
- Output: Good, Moderate, Bad (3 classes)
- Framework: TensorFlow Lite

## 🎯 Upgrade Strategies

### 1. **Add More Features** (Quick Win)
Collect additional sensor data to improve accuracy:

**Recommended sensors:**
- **Turbidity** - Water clarity (0-1000 NTU)
- **Dissolved Oxygen (DO)** - Fish health indicator (0-20 mg/L)
- **Ammonia (NH3)** - Toxic levels (0-5 ppm)
- **Nitrite/Nitrate** - Nitrogen cycle indicators
- **Conductivity** - Total dissolved ions
- **ORP (Oxidation-Reduction Potential)** - Water oxidation level

**Update prediction service:**
```dart
// lib/services/prediction_service.dart
final input = [
  [
    reading.pH, 
    reading.tds, 
    reading.temp,
    reading.turbidity,    // NEW
    reading.dissolvedO2,  // NEW
    reading.ammonia,      // NEW
  ]
];
```

### 2. **Collect Better Training Data**

**Current issues:**
- Limited dataset size
- Imbalanced classes (too few "Bad" samples)
- No temporal patterns captured

**Solutions:**
```python
# data_collection.py
import pandas as pd
from datetime import datetime, timedelta

# Collect data over time
data = []
for i in range(1000):  # Aim for 1000+ samples
    sample = {
        'timestamp': datetime.now(),
        'pH': read_sensor('pH'),
        'tds': read_sensor('tds'),
        'temp': read_sensor('temp'),
        'quality': expert_label(),  # Manual labeling
    }
    data.append(sample)

df = pd.DataFrame(data)
df.to_csv('water_quality_dataset.csv', index=False)
```

**Data augmentation:**
```python
# Add synthetic samples for rare classes
from sklearn.utils import resample

# Oversample minority class
bad_samples = df[df['quality'] == 'Bad']
bad_oversampled = resample(bad_samples, 
                          n_samples=len(df[df['quality'] == 'Good']),
                          random_state=42)
df_balanced = pd.concat([df, bad_oversampled])
```

### 3. **Improve Model Architecture**

**Option A: Deeper Neural Network**
```python
# train_improved_model.py
import tensorflow as tf
from tensorflow import keras

model = keras.Sequential([
    keras.layers.Input(shape=(3,)),  # 3 features
    keras.layers.Dense(64, activation='relu'),
    keras.layers.Dropout(0.3),
    keras.layers.Dense(32, activation='relu'),
    keras.layers.Dropout(0.2),
    keras.layers.Dense(16, activation='relu'),
    keras.layers.Dense(3, activation='softmax')  # 3 classes
])

model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy', 'precision', 'recall']
)

# Train with validation split
history = model.fit(
    X_train, y_train,
    validation_split=0.2,
    epochs=100,
    batch_size=32,
    callbacks=[
        keras.callbacks.EarlyStopping(patience=10),
        keras.callbacks.ModelCheckpoint('best_model.h5', save_best_only=True)
    ]
)

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

with open('water_model_v2.tflite', 'wb') as f:
    f.write(tflite_model)
```

**Option B: Ensemble Model (Best Accuracy)**
```python
# Combine multiple models for better predictions
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import VotingClassifier

rf = RandomForestClassifier(n_estimators=100)
gb = GradientBoostingClassifier(n_estimators=100)
lr = LogisticRegression()

ensemble = VotingClassifier(
    estimators=[('rf', rf), ('gb', gb), ('lr', lr)],
    voting='soft'
)

ensemble.fit(X_train, y_train)
print(f"Ensemble accuracy: {ensemble.score(X_test, y_test)}")
```

### 4. **Add Time-Series Patterns** (Advanced)

Water quality changes over time. Capture trends:

```python
# LSTM model for temporal patterns
model = keras.Sequential([
    keras.layers.LSTM(64, input_shape=(10, 3)),  # 10 timesteps, 3 features
    keras.layers.Dense(32, activation='relu'),
    keras.layers.Dense(3, activation='softmax')
])
```

**Update Flutter app:**
```dart
// Store last 10 readings for LSTM
class PredictionService {
  static final List<List<double>> _history = [];
  
  static Future<String> getPredictionLSTM(SensorReading reading) async {
    _history.add([reading.pH, reading.tds, reading.temp]);
    if (_history.length > 10) _history.removeAt(0);
    
    if (_history.length == 10) {
      // Run LSTM model with sequence
      final input = [_history];
      final output = await _interpreter!.run(input);
      return _interpretOutput(output);
    }
    
    return 'Collecting data...';
  }
}
```

### 5. **Feature Engineering**

Create derived features to improve predictions:

```python
# Feature engineering
df['pH_deviation'] = abs(df['pH'] - 7.0)  # Distance from neutral
df['tds_temp_ratio'] = df['tds'] / df['temp']
df['is_extreme'] = ((df['pH'] < 6) | (df['pH'] > 8)).astype(int)

# Polynomial features
from sklearn.preprocessing import PolynomialFeatures
poly = PolynomialFeatures(degree=2, include_bias=False)
X_poly = poly.fit_transform(X)
```

### 6. **Hyperparameter Tuning**

Find optimal model parameters:

```python
from sklearn.model_selection import GridSearchCV

param_grid = {
    'n_estimators': [50, 100, 200],
    'max_depth': [5, 10, 15, None],
    'min_samples_split': [2, 5, 10],
    'min_samples_leaf': [1, 2, 4]
}

grid_search = GridSearchCV(
    RandomForestClassifier(),
    param_grid,
    cv=5,
    scoring='accuracy',
    n_jobs=-1
)

grid_search.fit(X_train, y_train)
print(f"Best params: {grid_search.best_params_}")
print(f"Best score: {grid_search.best_score_}")
```

### 7. **Add Confidence Calibration**

Improve prediction confidence scores:

```python
from sklearn.calibration import CalibratedClassifierCV

# Calibrate model probabilities
calibrated_model = CalibratedClassifierCV(model, cv=5)
calibrated_model.fit(X_train, y_train)

# Now probabilities are more reliable
probs = calibrated_model.predict_proba(X_test)
```

### 8. **Implement Online Learning**

Update model with new data over time:

```dart
// lib/services/feedback_service.dart
class FeedbackService {
  static Future<void> submitFeedback({
    required SensorReading reading,
    required String actualQuality,
  }) async {
    // Store feedback for retraining
    await SupabaseService().insertFeedback({
      'pH': reading.pH,
      'tds': reading.tds,
      'temp': reading.temp,
      'predicted': reading.prediction,
      'actual': actualQuality,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

**Retrain monthly:**
```python
# retrain_model.py
import schedule
import time

def retrain():
    # Fetch new feedback data
    df_feedback = fetch_feedback_from_supabase()
    
    # Combine with original data
    df_combined = pd.concat([df_original, df_feedback])
    
    # Retrain model
    model.fit(df_combined[['pH', 'tds', 'temp']], df_combined['quality'])
    
    # Convert and deploy
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    # Upload to Firebase/Supabase storage
    upload_model('water_model_v2.tflite', tflite_model)

# Schedule retraining
schedule.every().month.do(retrain)
```

## 📊 Model Evaluation Checklist

Before deploying upgraded model:

```python
from sklearn.metrics import classification_report, confusion_matrix
import matplotlib.pyplot as plt
import seaborn as sns

# Predictions
y_pred = model.predict(X_test)

# 1. Accuracy metrics
print(classification_report(y_test, y_pred, 
      target_names=['Good', 'Moderate', 'Bad']))

# 2. Confusion matrix
cm = confusion_matrix(y_test, y_pred)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
plt.title('Confusion Matrix')
plt.ylabel('Actual')
plt.xlabel('Predicted')
plt.show()

# 3. Feature importance (for tree-based models)
importance = model.feature_importances_
for i, feat in enumerate(['pH', 'TDS', 'Temp']):
    print(f"{feat}: {importance[i]:.3f}")

# 4. Cross-validation
from sklearn.model_selection import cross_val_score
scores = cross_val_score(model, X, y, cv=5)
print(f"CV Accuracy: {scores.mean():.3f} (+/- {scores.std():.3f})")
```

**Target metrics:**
- ✅ Accuracy: > 90%
- ✅ Precision (Good): > 95% (avoid false alarms)
- ✅ Recall (Bad): > 95% (catch all unsafe water)
- ✅ F1-Score: > 0.90 for all classes

## 🚀 Quick Implementation Plan

### Week 1: Data Collection
1. Set up continuous data logging
2. Manual labeling by water quality expert
3. Collect 500+ samples (aim for balanced classes)

### Week 2: Feature Engineering
1. Add 2-3 new sensors (turbidity, DO)
2. Create derived features
3. Analyze feature correlations

### Week 3: Model Training
1. Train 3-5 different models
2. Hyperparameter tuning
3. Ensemble best performers

### Week 4: Testing & Deployment
1. Test on real data
2. A/B test old vs new model
3. Deploy if accuracy improves by 5%+

## 📁 Project Structure

```
MachineLearning/
├── data/
│   ├── raw_sensor_data.csv
│   ├── labeled_data.csv
│   └── feedback_data.csv
├── models/
│   ├── water_model_v1.tflite (current)
│   ├── water_model_v2.tflite (upgraded)
│   └── ensemble_model.pkl
├── notebooks/
│   ├── 01_data_analysis.ipynb
│   ├── 02_feature_engineering.ipynb
│   └── 03_model_comparison.ipynb
├── scripts/
│   ├── train_model.py
│   ├── evaluate_model.py
│   └── convert_to_tflite.py
└── README.md
```

## 🔧 Flutter Integration

After training new model, update the app:

```dart
// lib/services/prediction_service.dart
static const String MODEL_VERSION = 'v2';

static Future<void> initializeModel(String modelPath) async {
  // Download latest model from server
  final latestModel = await checkForModelUpdates();
  if (latestModel != null) {
    modelPath = latestModel;
  }
  
  _interpreter = await Interpreter.fromAsset(modelPath);
  debugPrint('✓ Model $MODEL_VERSION loaded');
}

static Future<String?> checkForModelUpdates() async {
  // Check Supabase storage for newer model
  final response = await SupabaseService.client
    .storage
    .from('models')
    .list();
  
  // Download if newer version exists
  return null; // or path to new model
}
```

## 📈 Monitoring in Production

Add model performance tracking:

```dart
// lib/services/analytics_service.dart
class AnalyticsService {
  static Future<void> logPrediction({
    required SensorReading reading,
    required String prediction,
    required double confidence,
  }) async {
    await SupabaseService().insert('prediction_logs', {
      'timestamp': DateTime.now().toIso8601String(),
      'pH': reading.pH,
      'tds': reading.tds,
      'temp': reading.temp,
      'prediction': prediction,
      'confidence': confidence,
      'model_version': PredictionService.MODEL_VERSION,
    });
  }
}
```

## 🎓 Learning Resources

- **TensorFlow Lite**: https://www.tensorflow.org/lite/guide
- **Scikit-learn**: https://scikit-learn.org/stable/
- **Feature Engineering**: "Feature Engineering for Machine Learning" by Alice Zheng
- **Water Quality Standards**: WHO Guidelines for Drinking-water Quality

## Next Steps

1. **Run current model tests** to establish baseline accuracy
2. **Collect 100+ real samples** with expert labeling
3. **Try adding turbidity sensor** (cheap, high impact)
4. **Retrain with new data** and compare results
5. **Deploy if accuracy improves**

Good luck upgrading your model! 🚀
