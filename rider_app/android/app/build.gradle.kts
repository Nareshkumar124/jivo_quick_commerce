plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.jivo.rider"
    // 37, not flutter.compileSdkVersion (36): permission_handler_android 14.x
    // requires compiling against API 37. targetSdk stays at Flutter's default.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // D-06: rider app ID. Flavors below add a suffix for non-prod builds.
        applicationId = "in.jivo.rider"
        // 26: jivo_core needs it (sentry_flutter).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Jivo Rider"
    }

    // Build with: flutter build apk --flavor <dev|staging|prod> -t lib/main_<flavor>.dart
    // The ID suffixes let all three flavors be installed side by side. No
    // versionNameSuffix: versionName is X-App-Version and must be plain semver.
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Jivo Rider Dev"
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appLabel"] = "Jivo Rider Staging"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appLabel"] = "Jivo Rider"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
