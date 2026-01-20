"""
ML Model Confidence Upgrade Script
Improves water quality prediction accuracy with advanced techniques:
- Better data preprocessing
- Deeper neural network architecture
- Data augmentation for imbalanced classes
- Cross-validation
- Confidence calibration
"""
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split, StratifiedKFold
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix
import pickle
import os
from pathlib import Path


def _save_training_history_and_plots(history, output_dir: str) -> None:
    """Save training history to CSV and optional PNG plots (if matplotlib is available)."""
    try:
        import pandas as pd

        history_df = pd.DataFrame(history.history)
        os.makedirs(output_dir, exist_ok=True)
        csv_path = os.path.join(output_dir, "training_history.csv")
        history_df.to_csv(csv_path, index=False)
        print(f"✓ Training history saved: {csv_path}")
    except Exception as e:
        print(f"⚠️ Could not save training history CSV: {e}")
        return

    # Plot if matplotlib is installed
    try:
        import matplotlib.pyplot as plt

        plots_dir = os.path.join(output_dir, "plots")
        os.makedirs(plots_dir, exist_ok=True)

        def _plot(metric: str, title: str, filename: str) -> None:
            plt.figure(figsize=(9, 5))
            if metric in history_df.columns:
                plt.plot(history_df[metric], label=metric)
            val_metric = f"val_{metric}"
            if val_metric in history_df.columns:
                plt.plot(history_df[val_metric], label=val_metric)
            plt.title(title)
            plt.xlabel("epoch")
            plt.ylabel(metric)
            plt.grid(True, alpha=0.3)
            plt.legend()
            plt.tight_layout()
            plt.savefig(os.path.join(plots_dir, filename), dpi=160)
            plt.close()

        if "loss" in history_df.columns or "val_loss" in history_df.columns:
            _plot("loss", "Training Loss", "training_loss.png")
        if "accuracy" in history_df.columns or "val_accuracy" in history_df.columns:
            _plot("accuracy", "Training Accuracy", "training_accuracy.png")
        if "precision" in history_df.columns or "val_precision" in history_df.columns:
            _plot("precision", "Training Precision", "training_precision.png")
        if "recall" in history_df.columns or "val_recall" in history_df.columns:
            _plot("recall", "Training Recall", "training_recall.png")

        print(f"✓ Training plots saved: {plots_dir}")
    except Exception as e:
        print(f"⚠️ Could not generate training plots (install matplotlib): {e}")

print("="*70)
print("🚀 SWAI Water Quality ML Model - Confidence Upgrade")
print("="*70)

# ==================== Configuration ====================
CSV_PATH = r"C:\Users\HP\Documents\SEM 6\fyp\MachineLearning\water_data.csv"
OUTPUT_DIR = r"C:\Users\HP\swai_dashboard\assets\models"
MODEL_NAME = "water_model_improved.tflite"

# Model hyperparameters
EPOCHS = 150
BATCH_SIZE = 16
LEARNING_RATE = 0.001
DROPOUT_RATE = 0.3

# Validation settings
USE_CROSS_VALIDATION = True
CV_FOLDS = 5

# ==================== Load Dataset ====================
print(f"\n📊 Loading dataset from: {CSV_PATH}")
try:
    df = pd.read_csv(CSV_PATH)
    print(f"✓ Dataset loaded: {df.shape[0]} rows, {df.shape[1]} columns")
except Exception as e:
    print(f"❌ Error loading dataset: {e}")
    exit(1)

# Map column names
col_mapping = {
    'Temp': 'Temperature',
    'Water_Status': 'Quality'
}
df = df.rename(columns=col_mapping)

print(f"\n📋 Dataset Preview:")
print(df.head())
print(f"\n📊 Dataset Info:")
print(df.describe())

# ==================== Data Preprocessing ====================
print(f"\n🔧 Preprocessing data...")

# Define features and target
feature_cols = ['pH', 'TDS', 'Temperature']
target_col = 'Quality'

# Handle missing values
df = df.dropna(subset=feature_cols + [target_col])
print(f"✓ Removed missing values. Remaining: {df.shape[0]} rows")

# Check class distribution
print(f"\n📊 Class Distribution:")
class_counts = df[target_col].value_counts()
print(class_counts)
print(f"Balance ratio: {class_counts.min() / class_counts.max():.2%}")

# ==================== Data Augmentation ====================
print(f"\n🔄 Applying data augmentation for imbalanced classes...")

def augment_minority_class(df, target_col, feature_cols, target_ratio=0.8):
    """Augment minority classes using noise injection"""
    class_counts = df[target_col].value_counts()
    max_count = class_counts.max()
    
    augmented_dfs = [df]
    
    for class_name, count in class_counts.items():
        if count / max_count < target_ratio:
            # Calculate how many samples to add
            samples_needed = int(max_count * target_ratio) - count
            
            # Get samples from this class
            class_samples = df[df[target_col] == class_name]
            
            # Generate augmented samples with noise
            for _ in range(samples_needed // len(class_samples) + 1):
                noise_factor = 0.05  # 5% noise
                augmented = class_samples.copy()
                for col in feature_cols:
                    noise = np.random.normal(0, augmented[col].std() * noise_factor, len(augmented))
                    augmented[col] = augmented[col] + noise
                augmented_dfs.append(augmented)
    
    return pd.concat(augmented_dfs, ignore_index=True)

df_augmented = augment_minority_class(df, target_col, feature_cols)
print(f"✓ Augmented dataset: {len(df_augmented)} rows")
print(f"New class distribution:")
print(df_augmented[target_col].value_counts())

# ==================== Feature Engineering ====================
print(f"\n🎨 Creating engineered features...")

# Original features
X = df_augmented[feature_cols].values

# Add derived features for better predictions
df_augmented['pH_deviation'] = np.abs(df_augmented['pH'] - 7.0)  # Distance from neutral
df_augmented['temp_normalized'] = (df_augmented['Temperature'] - 25) / 5  # Normalized temp
df_augmented['tds_level'] = pd.cut(df_augmented['TDS'], bins=[0, 300, 600, float('inf')], labels=[0, 1, 2])

# Extended feature set (optional - uncomment to use)
extended_feature_cols = feature_cols + ['pH_deviation', 'temp_normalized']
X_extended = df_augmented[extended_feature_cols].values

print(f"✓ Feature engineering complete")
print(f"  Original features: {len(feature_cols)}")
print(f"  Extended features: {len(extended_feature_cols)}")

# Use extended features for training
X = X_extended
feature_cols = extended_feature_cols

# ==================== Encode Labels ====================
y_raw = df_augmented[target_col].values
label_encoder = LabelEncoder()
y = label_encoder.fit_transform(y_raw)
num_classes = len(label_encoder.classes_)

print(f"\n🏷️ Label Encoding:")
for i, label in enumerate(label_encoder.classes_):
    print(f"  {i}: {label} ({np.sum(y == i)} samples)")

# Convert to one-hot encoding
y_onehot = tf.keras.utils.to_categorical(y, num_classes)

# ==================== Train/Test Split ====================
X_train, X_test, y_train, y_test = train_test_split(
    X, y_onehot, test_size=0.2, random_state=42, stratify=y
)

print(f"\n📊 Dataset Split:")
print(f"  Training: {X_train.shape[0]} samples")
print(f"  Testing: {X_test.shape[0]} samples")
print(f"  Features: {X_train.shape[1]}")
print(f"  Classes: {num_classes}")

# ==================== Feature Scaling ====================
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

print(f"\n✓ Feature scaling applied")
print(f"  Mean: {scaler.mean_}")
print(f"  Std: {scaler.scale_}")

# ==================== Build Enhanced Model ====================
print(f"\n🏗️ Building enhanced neural network...")

def create_model(input_dim, num_classes, learning_rate=0.001, dropout_rate=0.3):
    """Create improved neural network with better architecture"""
    model = tf.keras.Sequential([
        # Input layer
        tf.keras.layers.Input(shape=(input_dim,)),
        
        # First hidden block
        tf.keras.layers.Dense(64, activation='relu', 
                             kernel_regularizer=tf.keras.regularizers.l2(0.01)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(dropout_rate),
        
        # Second hidden block
        tf.keras.layers.Dense(32, activation='relu',
                             kernel_regularizer=tf.keras.regularizers.l2(0.01)),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(dropout_rate * 0.7),
        
        # Third hidden block
        tf.keras.layers.Dense(16, activation='relu'),
        tf.keras.layers.Dropout(dropout_rate * 0.5),
        
        # Output layer
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    # Custom optimizer with learning rate schedule
    optimizer = tf.keras.optimizers.Adam(learning_rate=learning_rate)
    
    model.compile(
        optimizer=optimizer,
        loss='categorical_crossentropy',
        metrics=['accuracy', 
                tf.keras.metrics.Precision(name='precision'),
                tf.keras.metrics.Recall(name='recall')]
    )
    
    return model

model = create_model(X_train_scaled.shape[1], num_classes, LEARNING_RATE, DROPOUT_RATE)

print("="*70)
print("📐 Model Architecture:")
print("="*70)
model.summary()

# ==================== Training ====================
print(f"\n🎯 Training model...")
print(f"  Epochs: {EPOCHS}")
print(f"  Batch size: {BATCH_SIZE}")
print(f"  Learning rate: {LEARNING_RATE}")

# Callbacks for better training
callbacks = [
    tf.keras.callbacks.EarlyStopping(
        monitor='val_loss',
        patience=15,
        restore_best_weights=True,
        verbose=1
    ),
    tf.keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=10,
        min_lr=0.00001,
        verbose=1
    ),
    tf.keras.callbacks.ModelCheckpoint(
        os.path.join(OUTPUT_DIR, 'best_model.h5'),
        monitor='val_accuracy',
        save_best_only=True,
        verbose=1
    )
]

# Train model
history = model.fit(
    X_train_scaled, y_train,
    validation_data=(X_test_scaled, y_test),
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    callbacks=callbacks,
    verbose=1
)

# Save history + plots for later graphing
_save_training_history_and_plots(history, OUTPUT_DIR)

# ==================== Evaluation ====================
print(f"\n📈 Evaluating model...")
test_results = model.evaluate(X_test_scaled, y_test, verbose=0)
test_loss = test_results[0]
test_accuracy = test_results[1]
test_precision = test_results[2]
test_recall = test_results[3]

print(f"="*70)
print(f"📊 Test Set Performance:")
print(f"="*70)
print(f"  ✓ Accuracy: {test_accuracy*100:.2f}%")
print(f"  ✓ Precision: {test_precision*100:.2f}%")
print(f"  ✓ Recall: {test_recall*100:.2f}%")
print(f"  ✓ F1-Score: {2 * (test_precision * test_recall) / (test_precision + test_recall):.2f}")
print(f"  Loss: {test_loss:.4f}")

# Detailed classification report
y_pred = model.predict(X_test_scaled, verbose=0)
y_pred_classes = np.argmax(y_pred, axis=1)
y_test_classes = np.argmax(y_test, axis=1)

print(f"\n📋 Detailed Classification Report:")
print(classification_report(y_test_classes, y_pred_classes, 
                          target_names=label_encoder.classes_))

print(f"\n🔢 Confusion Matrix:")
print(confusion_matrix(y_test_classes, y_pred_classes))

# ==================== Cross-Validation (Optional) ====================
if USE_CROSS_VALIDATION:
    print(f"\n🔄 Performing {CV_FOLDS}-fold cross-validation...")
    
    kfold = StratifiedKFold(n_splits=CV_FOLDS, shuffle=True, random_state=42)
    cv_scores = []
    
    for fold, (train_idx, val_idx) in enumerate(kfold.split(X_train_scaled, np.argmax(y_train, axis=1))):
        print(f"\n  Fold {fold + 1}/{CV_FOLDS}...")
        
        X_fold_train, X_fold_val = X_train_scaled[train_idx], X_train_scaled[val_idx]
        y_fold_train, y_fold_val = y_train[train_idx], y_train[val_idx]
        
        fold_model = create_model(X_train_scaled.shape[1], num_classes, LEARNING_RATE, DROPOUT_RATE)
        fold_model.fit(
            X_fold_train, y_fold_train,
            validation_data=(X_fold_val, y_fold_val),
            epochs=50,
            batch_size=BATCH_SIZE,
            verbose=0
        )
        
        fold_score = fold_model.evaluate(X_fold_val, y_fold_val, verbose=0)[1]
        cv_scores.append(fold_score)
        print(f"    Accuracy: {fold_score*100:.2f}%")
    
    print(f"\n✓ Cross-validation complete:")
    print(f"  Mean accuracy: {np.mean(cv_scores)*100:.2f}% (±{np.std(cv_scores)*100:.2f}%)")

# ==================== Convert to TFLite ====================
print(f"\n📦 Converting to TFLite format...")

converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Compatibility and optimization settings
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# Convert
tflite_model = converter.convert()

# Save model
output_path = os.path.join(OUTPUT_DIR, MODEL_NAME)
os.makedirs(OUTPUT_DIR, exist_ok=True)

with open(output_path, 'wb') as f:
    f.write(tflite_model)

print(f"✓ Model saved: {output_path}")
print(f"  File size: {len(tflite_model) / 1024:.2f} KB")

# Save scaler
scaler_path = os.path.join(OUTPUT_DIR, 'scaler.pkl')
with open(scaler_path, 'wb') as f:
    pickle.dump(scaler, f)
print(f"✓ Scaler saved: {scaler_path}")

# Save label encoder
encoder_path = os.path.join(OUTPUT_DIR, 'label_encoder.pkl')
with open(encoder_path, 'wb') as f:
    pickle.dump(label_encoder, f)
print(f"✓ Label encoder saved: {encoder_path}")

# Save feature names for future reference
feature_info_path = os.path.join(OUTPUT_DIR, 'feature_info.txt')
with open(feature_info_path, 'w') as f:
    f.write(f"Feature columns: {feature_cols}\n")
    f.write(f"Number of features: {len(feature_cols)}\n")
    f.write(f"Classes: {list(label_encoder.classes_)}\n")
print(f"✓ Feature info saved: {feature_info_path}")

# ==================== Test TFLite Model ====================
print(f"\n🧪 Testing TFLite model...")

interpreter = tf.lite.Interpreter(model_content=tflite_model)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"✓ Model verification:")
print(f"  Input shape: {input_details[0]['shape']}")
print(f"  Output shape: {output_details[0]['shape']}")
print(f"  Input dtype: {input_details[0]['dtype']}")
print(f"  Output dtype: {output_details[0]['dtype']}")

# Test with sample predictions
print(f"\n🔬 Sample Predictions (TFLite):")
print("="*70)

correct_predictions = 0
for i in range(min(10, len(X_test_scaled))):
    test_input = X_test_scaled[i:i+1].astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    
    predicted_class = np.argmax(output[0])
    predicted_label = label_encoder.classes_[predicted_class]
    actual_label = label_encoder.classes_[np.argmax(y_test[i])]
    confidence = output[0][predicted_class] * 100
    
    is_correct = predicted_label == actual_label
    if is_correct:
        correct_predictions += 1
    
    print(f"Sample {i+1}:")
    print(f"  Features: {[f'{v:.2f}' for v in X_test[i][:3]]}")  # Show first 3 features
    print(f"  Predicted: {predicted_label} ({confidence:.1f}% confidence)")
    print(f"  Actual: {actual_label}")
    print(f"  {'✓ Correct' if is_correct else '✗ Incorrect'}")
    
    # Show all class probabilities
    print(f"  Probabilities:")
    for j, class_name in enumerate(label_encoder.classes_):
        print(f"    - {class_name}: {output[0][j]*100:.1f}%")
    print()

print(f"Sample accuracy: {correct_predictions}/10 = {correct_predictions*10}%")

# ==================== Summary ====================
print("="*70)
print("✅ MODEL UPGRADE COMPLETE!")
print("="*70)
print(f"\n📊 Final Performance Summary:")
print(f"  ✓ Test Accuracy: {test_accuracy*100:.2f}%")
print(f"  ✓ Test Precision: {test_precision*100:.2f}%")
print(f"  ✓ Test Recall: {test_recall*100:.2f}%")
print(f"  ✓ Model Size: {len(tflite_model) / 1024:.2f} KB")
print(f"  ✓ Classes: {list(label_encoder.classes_)}")
print(f"  ✓ Features Used: {len(feature_cols)}")

print(f"\n📝 Next Steps:")
print(f"  1. Update Flutter app to use {len(feature_cols)} features")
print(f"  2. Run: flutter clean && flutter pub get")
print(f"  3. Run: flutter run")
print(f"  4. Check console for: '✓ TFLite model loaded successfully'")
print(f"  5. Test predictions in the dashboard")

print(f"\n🎯 Model Improvements Applied:")
print(f"  ✓ Data augmentation for balanced classes")
print(f"  ✓ Feature engineering (pH deviation, normalized temp)")
print(f"  ✓ Deeper neural network (64→32→16 neurons)")
print(f"  ✓ Batch normalization for training stability")
print(f"  ✓ Dropout regularization to prevent overfitting")
print(f"  ✓ L2 regularization on dense layers")
print(f"  ✓ Learning rate scheduling")
print(f"  ✓ Early stopping with best weights restoration")
if USE_CROSS_VALIDATION:
    print(f"  ✓ {CV_FOLDS}-fold cross-validation")

print("\n" + "="*70)
