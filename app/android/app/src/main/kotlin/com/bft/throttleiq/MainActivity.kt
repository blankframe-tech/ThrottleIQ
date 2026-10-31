package com.bft.throttleiq

import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The OEM battery-killer guide (oem_guide_screen.dart): the phone's
        // maker, and the vendor autostart screens, which have no public
        // intent action, only these component names.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "throttleiq/oem")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "manufacturer" -> result.success(Build.MANUFACTURER)
                    "openFirst" -> {
                        val components = (call.arguments as? List<*>).orEmpty()
                        result.success(components.filterIsInstance<String>().any { tryOpen(it) })
                    }
                    else -> result.notImplemented()
                }
            }
        // The Year in Review video (year_video_encoder.dart).
        val yearVideo = YearVideoEncoder()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "throttleiq/year_video")
            .setMethodCallHandler(yearVideo::handle)
    }

    /** Starts [flat] ("package/.Activity"); false when it is missing or refused. */
    private fun tryOpen(flat: String): Boolean {
        val component = ComponentName.unflattenFromString(flat) ?: return false
        return try {
            startActivity(Intent().setComponent(component))
            true
        } catch (e: Exception) {
            false
        }
    }
}
