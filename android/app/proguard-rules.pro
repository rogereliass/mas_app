# ============================================================
# MAS App - ProGuard / R8 Rules
# ============================================================

# ============================================================
# Flutter
# ============================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ============================================================
# Kotlin
# ============================================================
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ============================================================
# Supabase / Realtime / Postgrest / Gotrue
# ============================================================
-keep class io.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.supabase.**
-dontwarn io.github.jan.supabase.**

# Ktor (used internally by Supabase SDK)
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**

# OkHttp (used internally by Ktor under Android)
-keep class okhttp3.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**

# ============================================================
# Firebase Core & Messaging
# ============================================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ============================================================
# Hive (local storage)
# Keep all model adapters from being stripped
# ============================================================
-keep class com.hive.** { *; }
-keep class * extends com.hive.hive.HiveAdapter { *; }
# Keep any data classes stored in Hive (adjust package if needed)
-keepclassmembers class * {
    @com.hive.annotation.HiveField *;
}
-dontwarn com.hive.**

# ============================================================
# flutter_secure_storage
# ============================================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ============================================================
# encrypt (uses PointyCastle / crypto primitives)
# ============================================================
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# ============================================================
# shared_preferences
# ============================================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ============================================================
# url_launcher
# ============================================================
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# ============================================================
# path_provider / open_filex / device_info_plus
# ============================================================
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class com.crazecoder.openfile.** { *; }
-keep class dev.fluttercommunity.plus.device_info.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**
-dontwarn com.crazecoder.openfile.**
-dontwarn dev.fluttercommunity.plus.device_info.**

# ============================================================
# Syncfusion PDF Viewer
# ============================================================
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# ============================================================
# YouTube Player
# ============================================================
-keep class com.pierfrancescosoffritti.androidyoutubeplayer.** { *; }
-dontwarn com.pierfrancescosoffritti.androidyoutubeplayer.**

# ============================================================
# audioplayers
# ============================================================
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ============================================================
# Preserve all serialization metadata (important for JSON/Supabase)
# ============================================================
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep all classes with @JsonSerializable / @JsonKey annotations
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ============================================================
# Security: prevent exposing internal stack traces
# ============================================================
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
