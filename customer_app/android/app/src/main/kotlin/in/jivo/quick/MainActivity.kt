package `in`.jivo.quick

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells Dart whether the Mappls SDK config was built into this APK, so
        // the app only creates a map when the SDK can authenticate.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "isConfigured") {
                    result.success(hasMapplsConfig())
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * The mappls_gl Gradle plugin turns `<appId>.a.olf` into the string
     * resource `mappls_olf_data` and `<appId>.a.conf` into the asset
     * `mappls-conf.txt`. Both are missing when the build had no config
     * (CI, fresh checkouts): see tool/setup_mappls.sh.
     */
    private fun hasMapplsConfig(): Boolean = try {
        @Suppress("DiscouragedApi")
        val olf = resources.getIdentifier(MAPPLS_OLF_RESOURCE, "string", packageName)
        olf != 0 && getString(olf).isNotEmpty() &&
            assets.open(MAPPLS_CONF_ASSET).use { it.read() != -1 }
    } catch (e: Exception) {
        false
    }

    private companion object {
        const val MAPS_CHANNEL = "in.jivo.quick/maps"
        const val MAPPLS_OLF_RESOURCE = "mappls_olf_data"
        const val MAPPLS_CONF_ASSET = "mappls-conf.txt"
    }
}
