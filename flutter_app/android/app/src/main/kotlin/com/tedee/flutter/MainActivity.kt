package com.tedee.flutter

import android.graphics.Color
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import timber.log.Timber
import tedee.mobile.sdk.ble.bluetooth.ILockConnectionListener
import tedee.mobile.sdk.ble.bluetooth.LockConnectionManager
import tedee.mobile.sdk.ble.bluetooth.error.DeviceNeedsResetError
import tedee.mobile.sdk.ble.extentions.getReadableLockCommandResult
import tedee.mobile.sdk.ble.extentions.getReadableLockNotification
import tedee.mobile.sdk.ble.extentions.getReadableLockState
import tedee.mobile.sdk.ble.extentions.getReadableStatus
import tedee.mobile.sdk.ble.extentions.print

class MainActivity : FlutterActivity(), ILockConnectionListener {
    private val CHANNEL = "com.tedee.flutter/lock"
    private var methodChannel: MethodChannel? = null

    private val lockConnectionManager by lazy { LockConnectionManager(this) }
    private val tedeeFlutterBridge by lazy { TedeeFlutterBridge(this, lockConnectionManager) }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Timber for logging
        if (!Timber.forest().any()) {
            Timber.plant(Timber.DebugTree())
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val serialNumber = call.argument<String>("serialNumber")
                    val deviceId = call.argument<String>("deviceId")
                    val name = call.argument<String>("name")
                    val keepConnection = call.argument<Boolean>("keepConnection") ?: true

                    if (serialNumber == null || deviceId == null || name == null) {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }

                    connectToLock(serialNumber, deviceId, name, keepConnection, result)
                }
                "disconnect" -> {
                    lockConnectionManager.disconnect()
                    result.success(null)
                }
                "openLock" -> {
                    scope.launch {
                        try {
                            val response = lockConnectionManager.sendCommand(0x51.toByte())
                            val readable = response?.getReadableLockCommandResult() ?: "No response"
                            result.success(readable)
                        } catch (e: Exception) {
                            result.error("OPEN_FAILED", e.message, null)
                        }
                    }
                }
                "closeLock" -> {
                    scope.launch {
                        try {
                            val response = lockConnectionManager.sendCommand(0x50.toByte())
                            val readable = response?.getReadableLockCommandResult() ?: "No response"
                            result.success(readable)
                        } catch (e: Exception) {
                            result.error("CLOSE_FAILED", e.message, null)
                        }
                    }
                }
                "pullSpring" -> {
                    scope.launch {
                        try {
                            val response = lockConnectionManager.sendCommand(0x52.toByte())
                            val readable = response?.getReadableLockCommandResult() ?: "No response"
                            result.success(readable)
                        } catch (e: Exception) {
                            result.error("PULL_FAILED", e.message, null)
                        }
                    }
                }
                "getLockState" -> {
                    scope.launch {
                        try {
                            val response = lockConnectionManager.getLockState()
                            val readable = response?.getReadableLockStatusResult() ?: "No response"
                            result.success(readable)
                        } catch (e: Exception) {
                            result.error("GET_STATE_FAILED", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun connectToLock(
        serialNumber: String,
        deviceId: String,
        name: String,
        keepConnection: Boolean,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // Use TedeeFlutterBridge to handle certificate generation and connection
                tedeeFlutterBridge.connect(
                    serialNumber = serialNumber,
                    deviceId = deviceId,
                    name = name,
                    keepConnection = keepConnection,
                    listener = this@MainActivity
                )

                Timber.d("MainActivity: Connection successful")
                result.success(true)
            } catch (e: Exception) {
                Timber.e(e, "MainActivity: Connection failed")
                result.error("CONNECT_FAILED", e.message, null)
            }
        }
    }

    // ILockConnectionListener callbacks
    override fun onLockConnectionChanged(isConnecting: Boolean, isConnected: Boolean) {
        Timber.d("Flutter: onLockConnectionChanged - isConnecting: $isConnecting, isConnected: $isConnected")
        val status = when {
            isConnecting -> "Connecting..."
            isConnected -> "✅ Secure session established"
            else -> "Disconnected"
        }
        sendNotificationToFlutter(status)
    }

    override fun onNotification(message: ByteArray) {
        if (message.isEmpty()) return
        Timber.d("Flutter: onNotification: ${message.print()}")

        val readableNotification = message.getReadableLockNotification()
        sendNotificationToFlutter("Notification: $readableNotification")
    }

    override fun onLockStatusChanged(currentState: Byte, status: Byte) {
        Timber.d("Flutter: onLockStatusChanged - currentState: $currentState, status: $status")
        val readableState = currentState.getReadableLockState()
        val readableStatus = status.getReadableStatus()
        sendNotificationToFlutter("State: $readableState, Status: $readableStatus")
    }

    override fun onError(throwable: Throwable) {
        Timber.e(throwable, "Flutter: onError")
        when (throwable) {
            is DeviceNeedsResetError -> {
                sendNotificationToFlutter("❌ Device needs factory reset")
            }
            else -> {
                sendNotificationToFlutter("❌ Error: ${throwable.message}")
            }
        }
    }

    private fun sendNotificationToFlutter(message: String) {
        runOnUiThread {
            methodChannel?.invokeMethod("onNotification", message)
        }
    }

    override fun onDestroy() {
        lockConnectionManager.clear()
        super.onDestroy()
    }
}
