package `in`.jivo.quick

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.mappls.sdk.core.MapplsInitialiser
import com.mappls.sdk.maps.flutter.MapplsMapsPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dart asks this only when a screen needs a map (map pin picker,
        // location options), never at launch. The Mappls plugin is not in
        // GeneratedPluginRegistrant (stripped at build time, see
        // android/app/build.gradle.kts): it is registered here, and only once
        // the SDK config passed the SDK's own check. Otherwise the SDK would
        // throw on its background thread and kill the app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "prepare") {
                    MapplsPreflight.check(applicationContext) { configOk ->
                        result.success(configOk && registerMappls(flutterEngine))
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Main thread. One plugin instance per engine. */
    private fun registerMappls(engine: FlutterEngine): Boolean = try {
        if (!engine.plugins.has(MapplsMapsPlugin::class.java)) {
            engine.plugins.add(MapplsMapsPlugin())
        }
        true
    } catch (e: Exception) {
        Log.w(TAG, "Mappls unavailable: plugin registration failed (${e.javaClass.simpleName})")
        false
    }

    private companion object {
        const val MAPS_CHANNEL = "in.jivo.quick/maps"
    }
}

private const val TAG = "JivoMaps"

/**
 * Whether the Mappls SDK config in this APK is usable, decided once per
 * process (the config can't change at run time).
 *
 * 1. The mappls_gl Gradle plugin turns `<appId>.a.olf` into the string
 *    resource `mappls_olf_data` and `<appId>.a.conf` into the asset
 *    `mappls-conf.txt`. Both are missing when the build had no config (CI,
 *    fresh checkouts): see tool/setup_mappls.sh. Then the SDK is never
 *    touched.
 * 2. Otherwise run the SDK's own config check, `MapplsInitialiser.initialise`,
 *    on a worker thread inside try/catch. It is the call that throws "Please
 *    apply plugin…" / "You are using Invalid Configuration…" when the SDK
 *    starts itself, so a config that fails here never reaches the SDK's
 *    uncaught background start.
 *
 * Logs never include the config contents.
 */
private object MapplsPreflight {
    private const val OLF_RESOURCE = "mappls_olf_data"
    private const val CONF_ASSET = "mappls-conf.txt"

    private val mainHandler = Handler(Looper.getMainLooper())

    // Main thread only.
    private var verdict: Boolean? = null
    private val waiting = mutableListOf<(Boolean) -> Unit>()

    /** Calls [done] on the main thread. */
    fun check(context: Context, done: (Boolean) -> Unit) {
        verdict?.let {
            done(it)
            return
        }
        waiting += done
        if (waiting.size > 1) return // a check is already running
        val app = context.applicationContext
        thread(name = "mappls-preflight", isDaemon = true) {
            val ok = configBuiltIn(app) && configAccepted(app)
            mainHandler.post {
                verdict = ok
                val callbacks = waiting.toList()
                waiting.clear()
                callbacks.forEach { it(ok) }
            }
        }
    }

    private fun configBuiltIn(context: Context): Boolean {
        val present = try {
            @Suppress("DiscouragedApi")
            val olf = context.resources.getIdentifier(OLF_RESOURCE, "string", context.packageName)
            olf != 0 && context.getString(olf).isNotEmpty() &&
                context.assets.open(CONF_ASSET).use { it.read() != -1 }
        } catch (e: Exception) {
            false
        }
        if (!present) Log.i(TAG, "Mappls unavailable: no SDK config in this build")
        return present
    }

    private fun configAccepted(context: Context): Boolean = try {
        MapplsInitialiser.getInstance().initialise(context)
        true
    } catch (e: Throwable) {
        Log.w(TAG, "Mappls unavailable: ${e.javaClass.simpleName}: ${e.message}")
        false
    }
}
