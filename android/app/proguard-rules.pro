# Comprehensive ProGuard rules for Google ML Kit Text Recognition and its dependencies.
# These rules aim to prevent R8 from stripping necessary classes and methods.

# Keep all classes and members within the Google ML Kit package.
-keep class com.google.mlkit.** { *; }

# Keep all classes and members within the internal ML Kit packages that the plugin uses.
-keep class com.google.android.gms.internal.mlkit_text_recognition.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text.** { *; }

# Explicitly keep the language-specific text recognizer options that were reported as missing.
# This ensures R8 does not remove them, as they are likely dynamically referenced.
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# Broad rule to keep all public classes and members within Google Play Services (gms).
# ML Kit relies heavily on GMS, and this helps ensure all necessary parts are kept.
-keep class com.google.android.gms.** { *; }

# Keep all methods of the classes that are used by Firebase (if you are using other Firebase products).
-keep class com.google.firebase.** { *; }

# For the image_picker plugin, ensure its classes are kept.
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep all annotations, which are often used for reflection.
-keepattributes Annotations

# Keep all public and protected constructors and methods of any class
# that might be instantiated via reflection or used as a callback/listener.
-keep class * implements com.google.mlkit.vision.text.TextRecognizer { *; }
-keep class * implements com.google.mlkit.vision.common.InputImage { *; }

# Suppress warnings for missing classes that are not strictly necessary
# but might be referenced in a way R8 can't resolve.
# These are typically safe to ignore if the app works correctly after keeping the essential classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**