package com.elorigen.kiosk

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android MethodChannel bridge for Android LockTask (Kiosk Mode).
 * Pins the application to the screen and prevents users from exiting,
 * viewing notifications, or accessing OS navigation bars.
 */
class LockTaskBridge(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.elorigen.kiosk/lock_task"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startLockTask" -> handleStartLockTask(result)
            "stopLockTask" -> handleStopLockTask(result)
            "isInLockTaskMode" -> handleIsInLockTaskMode(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartLockTask(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                activity.startLockTask()
                result.success(
                    mapOf(
                        "success" to true,
                        "locked" to true
                    )
                )
            } else {
                result.success(
                    mapOf(
                        "success" to false,
                        "locked" to false,
                        "error" to "LockTask requires Android API 21+"
                    )
                )
            }
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "success" to false,
                    "locked" to false,
                    "error" to (e.message ?: e.toString())
                )
            )
        }
    }

    private fun handleStopLockTask(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                activity.stopLockTask()
                result.success(
                    mapOf(
                        "success" to true,
                        "locked" to false
                    )
                )
            } else {
                result.success(
                    mapOf(
                        "success" to false,
                        "locked" to false,
                        "error" to "LockTask requires Android API 21+"
                    )
                )
            }
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "success" to false,
                    "locked" to false,
                    "error" to (e.message ?: e.toString())
                )
            )
        }
    }

    private fun handleIsInLockTaskMode(result: MethodChannel.Result) {
        try {
            val inLockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                am?.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                am?.isInLockTaskMode ?: false
            } else {
                false
            }
            result.success(
                mapOf(
                    "inLockTaskMode" to inLockMode
                )
            )
        } catch (e: Exception) {
            result.success(
                mapOf(
                    "inLockTaskMode" to false,
                    "error" to (e.message ?: e.toString())
                )
            )
        }
    }

    fun destroy() {
        channel.setMethodCallHandler(null)
    }
}
