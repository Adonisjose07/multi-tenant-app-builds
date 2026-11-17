pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").let {
                if (it.exists()) {
                    it.inputStream().use { stream -> properties.load(stream) }
                }
            }
            properties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_ROOT") ?: System.getenv("FLUTTER_HOME")
        }

    if (flutterSdkPath != null) {
        includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
