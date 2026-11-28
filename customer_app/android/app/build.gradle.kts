import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/deployment.md §12.3): CI writes android/key.properties
// (gitignored, like the .jks it points at) with storeFile, storePassword,
// keyAlias and keyPassword. Without the file, dev/staging release falls back
// to the debug key so a local `flutter run --release` still works; a prod
// release fails instead (preProdReleaseBuild check below), so a Play build can
// never be debug-signed.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}

// Firebase Cloud Messaging (D-19). Each flavor reads its own config from
// src/<flavor>/google-services.json (dev now; staging and prod get theirs from
// their own Firebase projects). The files are private and gitignored; run
// `tool/setup_firebase.sh --copy` to place them. Every environment uses this
// same mechanism; only the file differs.
//
// Without any file (CI, a fresh checkout) the google-services plugin is not
// applied at all. With a file for some flavors only, the others build with a
// warning. A build without a config has no Firebase resources, so
// Firebase.initializeApp() fails at run time and the app runs with push off
// (NoopPushMessaging, see lib/features/notifications/data/push_setup.dart).
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

// Google Maps Android API key (DL-80). Never committed: read at build time
// from the Gradle property or env var MAPS_API_KEY, else from
// ~/.config/jivo-quick-commerce/google-maps/android-api-key.txt. Without a
// key the build still succeeds; the manifest value is empty, MainActivity
// reports no map, and the app shows its manual-address fallback.
val mapsApiKey: String = run {
    val fromProperty = (findProperty("MAPS_API_KEY") as String?)?.trim()
    val fromEnv = System.getenv("MAPS_API_KEY")?.trim()
    val keyFile = file(
        System.getProperty("user.home") +
            "/.config/jivo-quick-commerce/google-maps/android-api-key.txt",
    )
    val fromFile = if (keyFile.isFile) keyFile.readText().trim() else null
    listOf(fromProperty, fromEnv, fromFile).firstOrNull { !it.isNullOrEmpty() } ?: ""
}
logger.lifecycle(
    if (mapsApiKey.isEmpty()) "Google Maps key not found: building without maps."
    else "Google Maps key found.",
)

android {
    namespace = "in.jivo.quick"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (push channels).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Customer app ID (D-06). Flavors add .dev / .staging.
        applicationId = "in.jivo.quick"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // sentry_flutter (via jivo_core) needs API 26+. The test device matrix
        // starts at Android 10 (10-testing-strategy.md), so nothing is lost.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Launcher name per flavor, used by AndroidManifest.xml (D-06 said "Jivo";
        // renamed to "Jivo Quick Commerce" by the user, 2026-11-23).
        manifestPlaceholders["appLabel"] = "Jivo Quick Commerce"
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    // One flavor per environment (02 §4). Build with --flavor <name> and the
    // matching entry point, e.g. `flutter build apk --flavor dev -t lib/main_dev.dart`.
    // No versionNameSuffix: the version name is sent as X-App-Version and must
    // stay a plain version for the backend's force-update check.
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Jivo Quick Commerce Dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appLabel"] = "Jivo Quick Commerce Staging"
        }
        create("prod") {
            dimension = "environment"
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

// Prod release must be signed with the upload key (docs/deployment.md §12).
// Runs only when a prod release is actually built, so debug and dev/staging
// builds are unaffected.
tasks.matching { it.name == "preProdReleaseBuild" }.configureEach {
    doFirst {
        val storePath = keystoreProperties.getProperty("storeFile")
        if (!keystorePropertiesFile.exists() || storePath.isNullOrBlank()) {
            throw GradleException(
                "Prod release needs android/key.properties (storeFile, storePassword, " +
                    "keyAlias, keyPassword) and refuses the debug key. Copy it from " +
                    "~/.config/jivo-quick-commerce/android-signing/<app>/key.properties " +
                    "(see docs/deployment.md section 12).",
            )
        }
        if (!file(storePath).isFile) {
            throw GradleException("Prod release: keystore in key.properties not found: $storePath")
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

// razorpay_flutter 1.4.7 depends on com.razorpay:checkout:1.6.+, and checkout
// on com.razorpay:standard-core:latest.integration: both float, so a rebuild
// could silently pick up a newer SDK. Pin the set the release build was checked
// with (R8 keep rules, merged manifest and permissions; see README "Payments"
// and "Play Data Safety / permissions"). Bump them together, deliberately, and
// re-run those checks.
configurations.configureEach {
    resolutionStrategy.force(
        "com.razorpay:checkout:1.6.41",
        "com.razorpay:standard-core:1.7.22",
        "com.razorpay:core:1.0.22",
    )
}

dependencies {
    // Required by flutter_local_notifications; same version as rider_app.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
