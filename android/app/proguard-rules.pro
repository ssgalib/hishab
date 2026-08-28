# ONNX Runtime's native JNI layer resolves its Java helper classes by exact
# name via FindClass (e.g. ai/onnxruntime/TensorInfo). If R8 renames them,
# FindClass returns null and the JNI code aborts the process during
# OrtSession.run. Keep everything under the package unrenamed.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
