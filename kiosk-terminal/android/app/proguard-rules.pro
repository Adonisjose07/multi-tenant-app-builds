# Stripe Terminal SDK ProGuard / R8 Rules
-keep class com.stripe.stripeterminal.** { *; }
-dontwarn com.stripe.stripeterminal.**

# SLF4J Logger
-dontwarn org.slf4j.**

# Kotlin Coroutines and OkHttp
-dontwarn kotlinx.coroutines.**
-dontwarn okhttp3.**
-dontwarn okio.**
