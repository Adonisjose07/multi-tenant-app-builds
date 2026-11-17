package com.elorigen.printcompanion

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.elorigen.printcompanion/bluetooth"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getPairedDevices" -> {
                    val adapter = BluetoothAdapter.getDefaultAdapter()
                    if (adapter == null) {
                        result.success(emptyList<Map<String, String>>())
                        return@setMethodCallHandler
                    }
                    try {
                        val devices = adapter.bondedDevices.map { device ->
                            mapOf(
                                "name" to (device.name ?: "Unknown Device"),
                                "address" to device.address
                            )
                        }
                        result.success(devices)
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", "Bluetooth permission not granted", e.message)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "printBluetoothBytes" -> {
                    val address = call.argument<String>("address")
                    val bytes = call.argument<ByteArray>("bytes")

                    if (address.isNullOrEmpty() || bytes == null) {
                        result.error("INVALID_ARGS", "Device address and bytes are required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        if (adapter == null) {
                            runOnUiThread { result.error("NO_BLUETOOTH", "Bluetooth is not supported on this device", null) }
                            return@Thread
                        }

                        var socket: BluetoothSocket? = null
                        var outputStream: OutputStream? = null

                        try {
                            val device: BluetoothDevice = adapter.getRemoteDevice(address)
                            adapter.cancelDiscovery()

                            socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                            socket.connect()

                            outputStream = socket.outputStream
                            outputStream.write(bytes)
                            outputStream.flush()

                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(false) }
                        } finally {
                            try { outputStream?.close() } catch (_: Exception) {}
                            try { socket?.close() } catch (_: Exception) {}
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
