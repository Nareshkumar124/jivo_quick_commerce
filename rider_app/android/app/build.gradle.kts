import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/deployment.md §12.3): CI writes android/key.properties
// (gitignored, as are *.jks / *.keystore) with storeFile, storePassword,
// keyAlias and keyPassword. Without it, release builds keep the debug key so
// a local `flutter run --release` still works.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// Firebase Cloud Messaging (D-19). Each flavor reads its own config from
// src/<flavor>/google-services.json (dev now: Firebase project jivo-quick,
// app in.jivo.rider.dev; staging and prod get theirs from their own Firebase
// projects). The files are private and gitignored; run
// `tool/setup_firebase.sh --copy [--env dev|staging|prod]` to place them.
// Every environment uses this same mechanism; only the file differs (same
// as customer_app).
//
// Without any file (CI, a fresh checkout) the google-services plugin is not
// applied at all. With a file for some flavors only, the others build with a
// warning. A build without a config has no Firebase resources, so
// Firebase.initializeApp() fails at run time and the app runs with push off
// (NoopPushMessaging, see lib/features/notifications/data/push_setup.dart);
// offers still arrive on the rider socket and by polling.
val firebaseConfiguredFlavors: List<String> =
    listOf("dev", "staging", "prod").filter { file("src/$it/google-services.json").isFile }
if (firebaseConfiguredFlavors.isEmpty()) {
    logger.lifecycle("Firebase config not found in android/app/src/<flavor>: building with push off.")
} else {
    apply(plugin = "com.google.gms.google-services")
    extensions.configure<com.google.gms.googleservices.GoogleServicesPlugin.GoogleServicesPluginConfig> {
        missingGoogleServicesStrategy =
            com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.WARN
    }
    logger.lifecycle("Firebase config found for: ${firebaseConfiguredFlavors.joinToString()}.")
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

    signingConfigs {
        create("release") {
            if (!keystoreProperties.isEmpty) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (keystoreProperties.isEmpty) "debug" else "release",
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
