package com.elorigen.kiosk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {

    private var stripeTerminalBridge: StripeTerminalBridge? = null
    private var lockTaskBridge: LockTaskBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        stripeTerminalBridge = StripeTerminalBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        lockTaskBridge = LockTaskBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        stripeTerminalBridge?.destroy()
        stripeTerminalBridge = null
        lockTaskBridge?.destroy()
        lockTaskBridge = null
        super.onDestroy()
    }
}
