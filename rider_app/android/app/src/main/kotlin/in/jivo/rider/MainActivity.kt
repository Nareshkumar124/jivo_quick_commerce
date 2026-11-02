package `in`.jivo.rider

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI. Adds a small platform channel ("in.jivo.rider/device")
 * for things no plugin covers:
 *  - device facts for the permissions gate (SDK level, manufacturer for OEM
 *    auto-start guidance),
 *  - the Android 14+ full-screen-intent permission check and settings page,
 *  - showing over the lock screen ONLY when launched by an offer alert.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        applyOfferLockScreenFlags(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        applyOfferLockScreenFlags(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> result.success(
                        mapOf(
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                        ),
                    )
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                    "openFullScreenIntentSettings" -> result.success(openFullScreenIntentSettings())
                    "releaseLockScreen" -> {
                        setLockScreenFlags(false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * flutter_local_notifications launches this activity with action
     * SELECT_NOTIFICATION and the notification payload in the "payload" extra,
     * for both taps and full-screen intents. Offer alerts use an "offer:"
     * payload prefix (see offer_alert_notifications.dart).
     */
    private fun applyOfferLockScreenFlags(intent: Intent?) {
        if (intent == null || intent.action != "SELECT_NOTIFICATION") return
        val payload = intent.getStringExtra("payload") ?: return
        if (payload.startsWith(OFFER_PAYLOAD_PREFIX)) setLockScreenFlags(true)
    }

    private fun setLockScreenFlags(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun openFullScreenIntentSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:$packageName"),
                ),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private companion object {
        const val CHANNEL = "in.jivo.rider/device"
        const val OFFER_PAYLOAD_PREFIX = "offer:"
    }
}
