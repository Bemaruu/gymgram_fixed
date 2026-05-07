# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Supabase / Ktor / OkHttp / Coroutines
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn io.ktor.**

# Kotlin coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class ** {
    @kotlinx.serialization.SerialName <fields>;
}

# Mixpanel
-keep class com.mixpanel.** { *; }
-dontwarn com.mixpanel.**

# image_picker / video_player
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }

# Reflection general (JSON, etc.)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Evitar strip de clases con nombres dinámicos
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
