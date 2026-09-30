# FixPose release keeps — R8 fullMode (AGP 9.1.0). Auto-included by the
# Flutter Gradle Plugin when this file exists; no build.gradle edit needed.
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod
-dontwarn android.**
-dontwarn io.flutter.plugin.**
-keep class io.flutter.embedding.** { *; }
-keep class com.fixpose.fixpose.MainActivity { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
# ML Kit + GMS + CameraX (Pigeon ProxyApis use reflection)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.camera.** { *; }
-keep class io.flutter.plugins.camerax.** { *; }
# GSON (flutter_local_notifications vendor requirement)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * { @com.google.gson.annotations.SerializedName <fields>; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
# sqlite/drift/jni/secure-storage
-keep class com.github.dart_lang.jni.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class app.cash.sqldelight.** { *; }
