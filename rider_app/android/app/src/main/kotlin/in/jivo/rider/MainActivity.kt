package `in`.jivo.rider

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.VibrationEffect
import android.os.Vibrator
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
 *  - the location app-op modes (the runtime permission alone can read
 *    "granted" while the system gives the app no location),
 *  - ringing for an offer in the app while the offer screen is in front
 *    (the heads-up notification would cover it),
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
                    // T-821: a Google map is only created when the build
                    // injected a Maps API key (build.gradle.kts).
                    "hasMapsKey" -> result.success(hasMapsKey())
                    "openFullScreenIntentSettings" -> result.success(openFullScreenIntentSettings())
                    "locationOps" -> result.success(
                        mapOf(
                            "coarse" to opMode(AppOpsManager.OPSTR_COARSE_LOCATION),
                            "fine" to opMode(AppOpsManager.OPSTR_FINE_LOCATION),
                        ),
                    )
                    "startOfferRinging" -> {
                        startOfferRinging()
                        result.success(null)
                    }
                    "stopOfferRinging" -> {
                        stopOfferRinging()
                        result.success(null)
                    }
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

    override fun onDestroy() {
        stopOfferRinging()
        super.onDestroy()
    }

    /** Whether the build has a Google Maps API key in the manifest. */
    private fun hasMapsKey(): Boolean = try {
        @Suppress("DEPRECATION")
        val info = packageManager.getApplicationInfo(
            packageName,
            android.content.pm.PackageManager.GET_META_DATA,
        )
        !info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrBlank()
    } catch (e: Exception) {
        false
    }

    /**
     * Android 14+. NotificationManager.canUseFullScreenIntent() is the API;
     * the USE_FULL_SCREEN_INTENT app-op is read as well, since some OEM builds
     * answer false while the op (what `appops get` and the settings page show)
     * is allowed (device test 2026-11-17, realme RMX5056).
     */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.canUseFullScreenIntent()) return true
        return opMode(OPSTR_USE_FULL_SCREEN_INTENT) == "allowed"
    }

    /** "allowed", "foreground", "ignored", "errored", "default" or "unknown". */
    private fun opMode(op: String): String {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(op, Process.myUid(), packageName)
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(op, Process.myUid(), packageName)
            }
        } catch (e: Exception) {
            return "unknown"
        }
        return when (mode) {
            AppOpsManager.MODE_ALLOWED -> "allowed"
            AppOpsManager.MODE_FOREGROUND -> "foreground"
            AppOpsManager.MODE_IGNORED -> "ignored"
            AppOpsManager.MODE_ERRORED -> "errored"
            AppOpsManager.MODE_DEFAULT -> "default"
            else -> "unknown"
        }
    }

    private var ringtone: Ringtone? = null
    private val ringHandler = Handler(Looper.getMainLooper())

    /**
     * API 26/27 have no Ringtone.isLooping: replay the tone whenever it has
     * finished, until stopOfferRinging() removes this callback.
     */
    private val replayTone = object : Runnable {
        override fun run() {
            val tone = ringtone ?: return
            try {
                if (!tone.isPlaying) tone.play()
            } catch (e: Exception) {
                return
            }
            ringHandler.postDelayed(this, REPLAY_CHECK_MS)
        }
    }

    private fun startOfferRinging() {
        stopOfferRinging()
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)?.apply {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = true
                play()
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P && ringtone != null) {
                ringHandler.postDelayed(replayTone, REPLAY_CHECK_MS)
            }
        } catch (e: Exception) {
            ringtone = null
        }
        try {
            vibrator()?.vibrate(VibrationEffect.createWaveform(VIBRATION, 0))
        } catch (e: Exception) {
            // No vibrator or not allowed: the sound and the screen remain.
        }
    }

    private fun stopOfferRinging() {
        ringHandler.removeCallbacks(replayTone)
        try {
            ringtone?.stop()
        } catch (e: Exception) {
            // Already released.
        }
        ringtone = null
        try {
            vibrator()?.cancel()
        } catch (e: Exception) {
            // Nothing to cancel.
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrator(): Vibrator? =
        getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

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

        /** AppOpsManager.OPSTR_USE_FULL_SCREEN_INTENT (API 34, hidden constant). */
        const val OPSTR_USE_FULL_SCREEN_INTENT = "android:use_full_screen_intent"

        /** Same pattern as the offer notification channel (0, 800, 400, 800). */
        val VIBRATION = longArrayOf(0, 800, 400, 800)

        /** API 26/27: how often the finished alarm tone is restarted. */
        const val REPLAY_CHECK_MS = 500L
    }
}
