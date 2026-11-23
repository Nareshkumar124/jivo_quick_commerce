package `in`.jivo.quick

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Cold start on some phones (camera cut-out, Android 12+ splash screen):
    // the first insets Flutter gets can have a 0 status-bar top, and the
    // corrected ones only arrive after some later window change, so Home's
    // header drew under the status bar until the customer navigated. Ask
    // the system to send the insets again whenever the window gains focus
    // (after the splash screen is gone, and on return from background).
    // Harmless when they are already right: Flutter only rebuilds on a change.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) window.decorView.requestApplyInsets()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dart asks this before it shows a Google map (DL-80): a map is only
        // created when the build injected a Maps API key into the manifest
        // (android/app/build.gradle.kts, README "Google Maps key"). Without
        // one the app keeps its no-map fallback.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "prepare") {
                    result.success(hasMapsKey())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun hasMapsKey(): Boolean = try {
        @Suppress("DEPRECATION")
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        !info.metaData?.getString(MAPS_KEY_META).isNullOrBlank()
    } catch (e: Exception) {
        false
    }

    private companion object {
        const val MAPS_CHANNEL = "in.jivo.quick/maps"
        const val MAPS_KEY_META = "com.google.android.geo.API_KEY"
    }
}
