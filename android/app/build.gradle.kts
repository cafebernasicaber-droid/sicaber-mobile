plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.cafe_don_berna"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.cafe_don_berna"
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            //
            // ⚠️ Login con Google (ver AppState._googleSignIn en
            // lib/data/services/app_state.dart): la huella SHA-1 registrada
            // hoy en Google Cloud Console es la de esta misma key de debug.
            // El día que "release" pase a firmar con una keystore propia,
            // hay que sacar el SHA-1 de ESA keystore y agregarlo como huella
            // adicional al mismo cliente OAuth — si no, el login con Google
            // fallará SOLO en los APK firmados con la keystore nueva.
            signingConfig = signingConfigs.getByName("debug")
            // Ver proguard-rules.pro: sin este archivo, minifyReleaseWithR8
            // fallaba (no un warning, error duro) por clases opcionales de
            // google_mlkit_text_recognition que esta app nunca usa.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
