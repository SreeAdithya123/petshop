# R8 / ProGuard rules for PETSTA release builds (minify + shrinkResources).
# The Flutter engine, androidx and the Flutter plugins ship their own consumer
# rules; these cover what is left (Supabase's HTTP stack, Kotlin, Play Core).

# ---- Flutter -------------------------------------------------------------
# Embedding classes are looked up from native code (JNI) and by the
# GeneratedPluginRegistrant, so they must keep their names.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter references the Play Core split-install classes for deferred
# components; the app does not use deferred components and does not bundle
# Play Core, so R8 must not fail on the missing classes.
-dontwarn com.google.android.play.core.**

# ---- Stack traces ----------------------------------------------------------
# Keep line numbers so obfuscated native crash reports can be symbolicated with
# the mapping file Gradle writes to build/app/outputs/mapping/release/.
-keepattributes SourceFile,LineNumberTable,Signature,InnerClasses,EnclosingMethod,*Annotation*
-renamesourcefileattribute SourceFile

# ---- Supabase / networking ---------------------------------------------------
# Supabase talks to the backend over dart:io (Dart side), but the Android HTTP
# stack (OkHttp / Okio, used by WebView-adjacent and plugin code) probes for
# optional TLS providers that are not present on every device.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**

# ---- Kotlin ------------------------------------------------------------------
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
