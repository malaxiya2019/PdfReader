# ML Kit Text Recognition - keep all language-specific options
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }
-keepclassmembers class com.google.mlkit.vision.text.** { *; }

# Keep Syncfusion PDF
-keep class com.syncfusion.** { *; }

# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
