plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.jivo.quick"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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
        // Launcher name per flavor, used by AndroidManifest.xml (D-06: "Jivo").
        manifestPlaceholders["appLabel"] = "Jivo"
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
            manifestPlaceholders["appLabel"] = "Jivo Dev"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appLabel"] = "Jivo Staging"
        }
        create("prod") {
            dimension = "environment"
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
    // MainActivity's Mappls preflight calls the SDK's own config check
    // (com.mappls.sdk.core.MapplsInitialiser). The runtime copy comes from
    // mappls_gl; this must stay the exact version mappls_gl 2.0.7 resolves
    // (mappls-android-sdk 9.0.4 -> rest-apis 6.0.3 -> mappls-core 1.0.2).
    compileOnly("com.mappls.sdk:mappls-core:1.0.2")
}

// Mappls must never start at app launch (README "Why Mappls starts lazily").
// mappls_gl's MapplsMapsPlugin calls Mappls.getInstance() in
// onAttachedToEngine, and the SDK then validates its config on a background
// thread and throws an uncaught IllegalStateException when the config is
// missing or not registered for this package/fingerprint, killing the app.
// The flutter tool writes GeneratedPluginRegistrant.java (gitignored) before
// Gradle runs, so remove the plugin's registration block from it here.
// MainActivity registers the plugin later, only after the config passed the
// SDK's own check. Idempotent; fails the build if the block can't be removed.
val generatedPluginRegistrant: File =
    file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
val stripMapplsAutoRegistration by tasks.registering {
    description = "Removes MapplsMapsPlugin from GeneratedPluginRegistrant (lazy Mappls start)."
    val registrant = generatedPluginRegistrant
    doLast {
        if (!registrant.isFile) return@doLast
        val original = registrant.readText()
        val block = Regex(
            """\n[ \t]*try \{\s*flutterEngine\.getPlugins\(\)\.add\(""" +
                """new com\.mappls\.sdk\.maps\.flutter\.MapplsMapsPlugin\(\)\);""" +
                """\s*\} catch \(Exception e\) \{[^}]*\}""",
        )
        val stripped = original.replace(block, "")
        if (stripped.contains("MapplsMapsPlugin")) {
            throw GradleException(
                "MapplsMapsPlugin is still registered in ${registrant.path}: the " +
                    "generated registrant's format changed. Update " +
                    "stripMapplsAutoRegistration in android/app/build.gradle.kts, " +
                    "or the app crashes at launch without a valid Mappls config.",
            )
        }
        if (stripped != original) {
            registrant.writeText(stripped)
            logger.lifecycle("Mappls: removed MapplsMapsPlugin from GeneratedPluginRegistrant.")
        }
    }
}
stripMapplsAutoRegistration.configure {
    mustRunAfter(tasks.matching { it.name.startsWith("compileFlutterBuild") })
}
tasks.named("preBuild") { dependsOn(stripMapplsAutoRegistration) }
tasks
    .matching {
        it.name.startsWith("compile") &&
            (it.name.endsWith("JavaWithJavac") || it.name.endsWith("Kotlin"))
    }.configureEach { dependsOn(stripMapplsAutoRegistration) }
