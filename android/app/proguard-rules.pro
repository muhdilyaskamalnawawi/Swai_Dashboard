# TensorFlow Lite - Keep all TFLite classes
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
-keepclassmembers enum org.tensorflow.lite.** { *; }

# TensorFlow Lite GPU Delegate - Critical for GPU inference
-keep class org.tensorflow.lite.gpu.** { *; }
-keep interface org.tensorflow.lite.gpu.** { *; }
-keepclassmembers class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate { *; }

# Keep TFLite native methods and reflection
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep TFLite model loading and core classes
-keep class org.tensorflow.lite.DataType { *; }
-keep class org.tensorflow.lite.Interpreter { *; }
-keep class org.tensorflow.lite.InterpreterApi { *; }
-keep class org.tensorflow.lite.Tensor { *; }
-keep class org.tensorflow.lite.TensorBuffer { *; }
-keep class org.tensorflow.lite.support.** { *; }

# Keep TFLite NNApi Delegate
-keep class org.tensorflow.lite.nnapi.** { *; }

# Additional rules for TFLite Flutter plugin
-keep class com.tflite.tflite_flutter.** { *; }
-keep class org.tensorflow.lite.flutter.** { *; }

# Suppress warnings
-dontwarn org.tensorflow.lite.**
-dontwarn com.google.android.gms.**
