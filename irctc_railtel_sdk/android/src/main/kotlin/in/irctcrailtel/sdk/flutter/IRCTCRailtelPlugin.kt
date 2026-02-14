package `in`.irctcrailtel.sdk.flutter

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * IRCTCRailtelPlugin - Native Android plugin for Face RD integration.
 *
 * Handles launching the UIDAI AadhaarFaceRD app via startActivityForResult
 * and returning the PID data back to the Flutter SDK.
 *
 * This plugin is registered automatically by Flutter's plugin system.
 */
class IRCTCRailtelPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    companion object {
        const val CHANNEL_NAME = "irctc_railtel_sdk/face_rd"
        const val FACE_RD_REQUEST_CODE = 9876
        const val FACE_RD_ACTION = "in.gov.uidai.rdservice.face.CAPTURE"
    }

    // ======================== FlutterPlugin ========================

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ======================== MethodCallHandler ========================

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isFaceRDAvailable" -> {
                result.success(checkFaceRDAvailable())
            }
            "launchFaceRD" -> {
                val pidOptions = call.argument<String>("pidOptions")
                if (pidOptions == null) {
                    result.error("INVALID_ARGS", "pidOptions is required", null)
                    return
                }
                launchFaceRD(pidOptions, result)
            }
            else -> result.notImplemented()
        }
    }

    // ======================== Face RD Logic ========================

    /**
     * Check if Face RD app is installed and can handle the CAPTURE intent.
     * On Android 11+, this requires <queries> in AndroidManifest.xml.
     */
    private fun checkFaceRDAvailable(): Boolean {
        val act = activity ?: return false
        val intent = Intent(FACE_RD_ACTION)
        val activities = act.packageManager.queryIntentActivities(
            intent, PackageManager.MATCH_DEFAULT_ONLY
        )
        return activities.isNotEmpty()
    }

    /**
     * Launch the Face RD app with PID Options and wait for result.
     * Uses startActivityForResult to get the PID data back.
     */
    private fun launchFaceRD(pidOptions: String, result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available", null)
            return
        }

        if (pendingResult != null) {
            result.error("ALREADY_IN_PROGRESS", "Face capture already in progress", null)
            return
        }

        val intent = Intent(FACE_RD_ACTION)
        val activities = act.packageManager.queryIntentActivities(
            intent, PackageManager.MATCH_DEFAULT_ONLY
        )

        if (activities.isEmpty()) {
            result.error(
                "NOT_INSTALLED",
                "Face RD app not installed. Please install AadhaarFaceRD from Play Store.",
                null
            )
            return
        }

        pendingResult = result

        // Put PID Options as extras (matching native Android SDK)
        intent.putExtra("PID_OPTIONS", pidOptions)
        intent.putExtra("request", pidOptions)

        try {
            act.startActivityForResult(intent, FACE_RD_REQUEST_CODE)
        } catch (e: Exception) {
            pendingResult = null
            result.error("LAUNCH_ERROR", "Failed to launch Face RD: ${e.message}", null)
        }
    }

    // ======================== Activity Result ========================

    /**
     * Handle the result from Face RD app.
     * Parses the PID XML response and sends it back to Flutter.
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != FACE_RD_REQUEST_CODE) return false

        val result = pendingResult
        pendingResult = null

        if (result == null) return true

        if (resultCode == Activity.RESULT_OK && data != null) {
            val extras = data.extras
            if (extras != null) {
                // Face RD returns PID data in "response" extra
                val pidData = extras.getString("response")

                if (pidData.isNullOrEmpty()) {
                    result.error("INVALID_PID", "Invalid PID XML received from Face RD", null)
                } else if (pidData.contains("errCode=\"0\"")) {
                    // Success - errCode 0 means capture successful
                    result.success(pidData)
                } else {
                    // Extract error info from PID XML
                    val errRegex = Regex("errInfo=\"(.+?)\"")
                    val match = errRegex.find(pidData)
                    val errMsg = match?.groupValues?.get(1) ?: "Face capture failed"
                    result.error("FACE_CAPTURE_ERROR", errMsg, pidData)
                }
            } else {
                result.error("NO_RESPONSE", "No response data from Face RD service", null)
            }
        } else {
            result.error("CANCELLED", "Face capture was cancelled", null)
        }

        return true
    }

    // ======================== ActivityAware ========================

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
