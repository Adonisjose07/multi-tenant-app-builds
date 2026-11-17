plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val customAppId = (project.findProperty("appId") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("ANDROID_APP_ID")?.takeIf { it.isNotBlank() }
    ?: "com.multitenant.kiosk"

val customAppName = (project.findProperty("appName") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("ANDROID_APP_NAME")?.takeIf { it.isNotBlank() }
    ?: "Kiosk Terminal"

android {
    namespace = "com.elorigen.kiosk"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = customAppId
        manifestPlaceholders["appName"] = customAppName
        minSdk = 30
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "/META-INF/*.md"
        }
    }
}

dependencies {
    // Stripe Terminal Local Mobile SDK (Tap to Pay on Android)
    implementation("com.stripe:stripeterminal-localmobile:3.8.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

flutter {
    source = "../.."
}
