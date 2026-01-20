"""
Fix TFLite Model Compatibility
Converts a TFLite model to be compatible with older TFLite runtimes
"""
import tensorflow as tf
import sys
from pathlib import Path

def convert_model_for_compatibility(input_path, output_path):
    """Convert TFLite model to be compatible with mobile runtimes"""
    
    print(f"Loading model from: {input_path}")
    
    # Check if model exists
    if not Path(input_path).exists():
        print(f"❌ Model file not found: {input_path}")
        return False
    
    try:
        # Load the model
        with open(input_path, 'rb') as f:
            tflite_model = f.read()
        
        # Get interpreter to check model details
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"✓ Model loaded successfully")
        print(f"  Input shape: {input_details[0]['shape']}")
        print(f"  Output shape: {output_details[0]['shape']}")
        
        # The issue is that the model was exported with a newer TF version
        # We need to load the original Keras model and re-export it
        print("\n⚠ To fix compatibility, you need to:")
        print("1. Load your original Keras model (.h5 or SavedModel)")
        print("2. Re-export with compatibility settings")
        print("\nIf you have the original model, run this script with:")
        print(f"  python {sys.argv[0]} <path_to_keras_model.h5>")
        
        return False
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def convert_from_keras(keras_model_path, output_path):
    """Convert Keras model to compatible TFLite format"""
    
    print(f"Loading Keras model from: {keras_model_path}")
    
    try:
        # Load Keras model
        model = tf.keras.models.load_model(keras_model_path)
        print("✓ Keras model loaded")
        print(f"  Input shape: {model.input_shape}")
        print(f"  Output shape: {model.output_shape}")
        
        # Convert with compatibility settings
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        
        # Set compatibility options (downgrade to older op versions)
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS  # Use only standard built-in ops
        ]
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # IMPORTANT: Set lower target version for compatibility
        converter._experimental_lower_tensor_list_ops = False
        
        print("\nConverting model with compatibility settings...")
        tflite_model = converter.convert()
        
        # Save compatible model
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✓ Compatible model saved to: {output_path}")
        print(f"  File size: {len(tflite_model) / 1024:.2f} KB")
        
        # Test the converted model
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        print("✓ Model loads successfully in TFLite interpreter")
        
        return True
        
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # Paths
    original_tflite = r"C:\Users\HP\Documents\SEM 6\fyp\MachineLearning\water_model_improved.tflite"
    keras_model = r"C:\Users\HP\Documents\SEM 6\fyp\MachineLearning\water_model.h5"
    output_path = r"C:\Users\HP\swai_dashboard\assets\models\water_model_improved.tflite"
    
    if len(sys.argv) > 1:
        keras_model = sys.argv[1]
    
    print("=" * 60)
    print("TFLite Model Compatibility Fixer")
    print("=" * 60)
    
    # Check if Keras model exists
    if Path(keras_model).exists():
        print(f"\n📦 Found Keras model: {keras_model}")
        success = convert_from_keras(keras_model, output_path)
        if success:
            print("\n✅ Model conversion complete!")
            print("Run: flutter clean && flutter pub get && flutter run")
    else:
        print(f"\n⚠ Keras model not found: {keras_model}")
        print("\nSearching for model files...")
        
        # Search for model files
        ml_dir = Path(r"C:\Users\HP\Documents\SEM 6\fyp\MachineLearning")
        if ml_dir.exists():
            h5_files = list(ml_dir.glob("*.h5"))
            pb_files = list(ml_dir.glob("saved_model"))
            
            if h5_files:
                print(f"\nFound .h5 models:")
                for f in h5_files:
                    print(f"  - {f}")
                print(f"\nRun: python {sys.argv[0]} <model_path>")
            elif pb_files:
                print(f"\nFound SavedModel format:")
                for f in pb_files:
                    print(f"  - {f}")
            else:
                print("\n❌ No Keras models found")
                print("\nYou'll need to re-train or re-export your model with:")
                print("  TensorFlow version: <= 2.12")
                print("  Or use compatibility converter settings")
