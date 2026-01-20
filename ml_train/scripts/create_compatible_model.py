"""
Recreate a compatible TFLite model for water quality prediction
Uses simple Dense layers compatible with older TFLite runtimes
Trained on actual water quality dataset
"""
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
import pickle

# Load actual water quality dataset
csv_path = r"C:\Users\HP\Documents\SEM 6\fyp\MachineLearning\water_data.csv"
print(f"Loading dataset from: {csv_path}")

df = pd.read_csv(csv_path)
print(f"✓ Dataset loaded: {df.shape[0]} rows, {df.shape[1]} columns")
print(f"\nColumns: {list(df.columns)}")
print(f"\nFirst few rows:")
print(df.head())

# Identify feature columns and target column
# Map column names from CSV
col_mapping = {
    'Temp': 'Temperature',
    'Water_Status': 'Quality'
}
df = df.rename(columns=col_mapping)

# Define features and target
feature_cols = ['pH', 'TDS', 'Temperature']
target_col = 'Quality'

print(f"\nFeature columns: {feature_cols}")
print(f"Target column: {target_col}")

# Extract features and labels
X = df[feature_cols].values
y_raw = df[target_col].values

# Encode labels (convert string labels to numeric if needed)
label_encoder = LabelEncoder()
y = label_encoder.fit_transform(y_raw)
num_classes = len(label_encoder.classes_)

print(f"\nLabel mapping:")
for i, label in enumerate(label_encoder.classes_):
    print(f"  {i}: {label}")

# Convert to one-hot encoding
y_onehot = tf.keras.utils.to_categorical(y, num_classes)

# Split into train/test sets
X_train, X_test, y_train, y_test = train_test_split(
    X, y_onehot, test_size=0.2, random_state=42, stratify=y
)

print(f"\nDataset split:")
print(f"  Training samples: {X_train.shape[0]}")
print(f"  Testing samples: {X_test.shape[0]}")
print(f"  Features: {X_train.shape[1]}")
print(f"  Classes: {num_classes}")

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

print(f"\n✓ Features scaled")
print(f"  Training mean: {scaler.mean_}")
print(f"  Training std: {scaler.scale_}")

# Create simple model (compatible with older TFLite)
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(X_train.shape[1],)),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(16, activation='relu'),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(8, activation='relu'),
    tf.keras.layers.Dense(num_classes, activation='softmax')
])

model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

print("\n" + "="*60)
print("Model Architecture:")
print("="*60)
model.summary()

# Train model
print("\n" + "="*60)
print("Training Model...")
print("="*60)
history = model.fit(
    X_train_scaled, y_train, 
    validation_data=(X_test_scaled, y_test),
    epochs=100, 
    batch_size=16,
    verbose=1
)

# Evaluate model
print("\n" + "="*60)
print("Evaluating Model...")
print("="*60)
test_loss, test_accuracy = model.evaluate(X_test_scaled, y_test, verbose=0)
print(f"✓ Test accuracy: {test_accuracy*100:.2f}%")
print(f"  Test loss: {test_loss:.4f}")

# Convert to TFLite with compatibility settings
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# IMPORTANT: Use only standard built-in ops for compatibility
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = [tf.lite.Optimize.DEFAULT]

print("\nConverting to TFLite format...")
tflite_model = converter.convert()

# Save model
output_path = r"C:\Users\HP\swai_dashboard\assets\models\water_model_improved.tflite"
with open(output_path, 'wb') as f:
    f.write(tflite_model)

print(f"✓ Model saved to: {output_path}")
print(f"  File size: {len(tflite_model) / 1024:.2f} KB")

# Save scaler for future use
scaler_path = r"C:\Users\HP\swai_dashboard\assets\models\scaler.pkl"
with open(scaler_path, 'wb') as f:
    pickle.dump(scaler, f)
print(f"✓ Scaler saved to: {scaler_path}")

# Save label encoder
encoder_path = r"C:\Users\HP\swai_dashboard\assets\models\label_encoder.pkl"
with open(encoder_path, 'wb') as f:
    pickle.dump(label_encoder, f)
print(f"✓ Label encoder saved to: {encoder_path}")
print(f"  Classes: {list(label_encoder.classes_)}")

# Test the model
interpreter = tf.lite.Interpreter(model_content=tflite_model)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print("\n✓ Model verification:")
print(f"  Input shape: {input_details[0]['shape']}")
print(f"  Output shape: {output_details[0]['shape']}")
print(f"  Input dtype: {input_details[0]['dtype']}")
print(f"  Output dtype: {output_details[0]['dtype']}")

# Test prediction with a few samples
print(f"\n" + "="*60)
print("Sample Predictions:")
print("="*60)
for i in range(min(5, len(X_test_scaled))):
    test_input = X_test_scaled[i:i+1].astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    
    predicted_class = np.argmax(output[0])
    predicted_label = label_encoder.classes_[predicted_class]
    actual_label = label_encoder.classes_[np.argmax(y_test[i])]
    confidence = output[0][predicted_class] * 100
    
    print(f"Sample {i+1}:")
    print(f"  Features: {X_test[i]}")
    print(f"  Predicted: {predicted_label} ({confidence:.1f}% confidence)")
    print(f"  Actual: {actual_label}")
    print(f"  {'✓ Correct' if predicted_label == actual_label else '✗ Incorrect'}")
    print()

print("="*60)
print("✅ Compatible model created successfully!")
print("="*60)
print(f"\nModel Performance:")
print(f"  Accuracy: {test_accuracy*100:.2f}%")
print(f"  File size: {len(tflite_model) / 1024:.2f} KB")
print(f"  Classes: {list(label_encoder.classes_)}")
print("\nNext steps:")
print("1. Run: flutter clean && flutter pub get")
print("2. Run: flutter run")
print("3. Check console for: '✓ TFLite model loaded successfully'")
print("\n✓ Model trained on actual water quality data!")
