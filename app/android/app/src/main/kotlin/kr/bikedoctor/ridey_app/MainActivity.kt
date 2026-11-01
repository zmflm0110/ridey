package kr.bikedoctor.heotgeoleumzero

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ridey/official_bike",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val launch = packageManager.getLaunchIntentForPackage("com.dki.spb_android")
            if (launch != null) {
                startActivity(launch)
                result.success(true)
                return@setMethodCallHandler
            }
            startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("market://details?id=com.dki.spb_android"),
                ),
            )
            result.success(true)
        }
    }
}
