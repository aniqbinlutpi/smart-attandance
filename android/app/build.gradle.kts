plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin MUST be last
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartattendance.smart_attendance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.smartattendance.smart_attendance"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Support for TFLite and native libraries
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64"))
        }
    }
    
    // Prevent compression of TFLite model files for proper loading
    androidResources {
        noCompress("tflite")
    }

    buildTypes {
        release {
            // Using debug signing for now (Flutter default)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // 🔒 Pin AndroidX versions (AGP 8.7 compatible)
    implementation("androidx.core:core:1.12.0")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.browser:browser:1.8.0")
}

flutter {
    source = "../.."
}
