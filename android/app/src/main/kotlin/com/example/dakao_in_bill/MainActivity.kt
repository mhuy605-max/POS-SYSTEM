package com.example.dakao_in_bill

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "dakao_in_bill/printer"
    private val permissionRequestCode = 5801
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val socketLock = Any()
    private val ioLock = Any()
    private var socket: BluetoothSocket? = null
    private var connectingSocket: BluetoothSocket? = null
    private var connectedAddress: String? = null
    private var connectionGeneration = 0L
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handlePrinterCall)
    }

    private fun handlePrinterCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(currentState())
            "requestPermissions" -> requestBluetoothPermissions(result)
            "listPairedDevices" -> listPairedDevices(result)
            "connect" -> {
                val address = call.argument<String>("address")
                if (address.isNullOrBlank()) {
                    result.error("notConfigured", "Chưa chọn máy in.", null)
                } else {
                    runPrinterIo(result) { connectBlocking(address) }
                }
            }
            "write" -> {
                val address = call.argument<String>("address")
                val bytes = call.argument<ByteArray>("bytes")
                if (address.isNullOrBlank() || bytes == null) {
                    result.error("notConfigured", "Thiếu máy in hoặc dữ liệu in.", null)
                } else {
                    runPrinterIo(result) { writeBlocking(address, bytes) }
                }
            }
            "disconnect" -> {
                closeSocket()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun currentState(): Map<String, Any?> {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: return status("unavailable")
        if (!hasBluetoothPermission()) return status("permissionDenied")
        if (!adapter.isEnabled) return status("disabled")
        val active = synchronized(socketLock) { socket?.isConnected == true }
        return if (active) {
            status("connected", connectedAddress)
        } else {
            status("disconnected")
        }
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || hasBluetoothPermission()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permissionPending", "Yêu cầu quyền Bluetooth đang chờ.", null)
            return
        }
        permissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
            ),
            permissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        permissionResult?.success(granted)
        permissionResult = null
    }

    private fun listPairedDevices(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("bluetoothUnavailable", "Thiết bị không hỗ trợ Bluetooth.", null)
            return
        }
        if (!hasBluetoothPermission()) {
            result.error("permissionDenied", "Chưa cấp quyền Bluetooth.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetoothDisabled", "Bluetooth đang tắt.", null)
            return
        }
        val devices = adapter.bondedDevices
            .sortedWith(compareBy({ it.name ?: "" }, { it.address }))
            .map { mapOf("name" to (it.name ?: "Máy in Bluetooth"), "address" to it.address) }
        result.success(devices)
    }

    private fun runPrinterIo(
        result: MethodChannel.Result,
        operation: () -> Map<String, Any?>,
    ) {
        Thread {
            val value = try {
                operation()
            } catch (error: SecurityException) {
                failed("permissionDenied", "Chưa cấp quyền Bluetooth.")
            } catch (error: Throwable) {
                failed("connectionFailed", error.message ?: "Không thể kết nối máy in.")
            }
            runOnUiThread { result.success(value) }
        }.start()
    }

    private fun connectBlocking(address: String): Map<String, Any?> = synchronized(ioLock) {
        connectWithoutIoLock(address)
    }

    private fun connectWithoutIoLock(address: String): Map<String, Any?> {
        val problem = adapterProblem()
        if (problem != null) return problem
        val start = synchronized(socketLock) {
            if (socket?.isConnected == true && connectedAddress == address) {
                return status("connected", address)
            }
            connectionGeneration += 1
            val value = socket
            socket = null
            connectedAddress = null
            value to connectionGeneration
        }
        val existing = start.first
        val generation = start.second
        closeQuietly(existing)
        val adapter = BluetoothAdapter.getDefaultAdapter()
        adapter.cancelDiscovery()
        val device = adapter.getRemoteDevice(address)
        val candidate = device.createRfcommSocketToServiceRecord(sppUuid)
        val registered = synchronized(socketLock) {
            if (connectionGeneration != generation) {
                false
            } else {
                connectingSocket = candidate
                true
            }
        }
        if (!registered) {
            closeQuietly(candidate)
            return failed("disconnected", "Kết nối máy in đã bị ngắt.")
        }
        return try {
            candidate.connect()
            val accepted = synchronized(socketLock) {
                if (connectionGeneration != generation || connectingSocket !== candidate) {
                    false
                } else {
                    connectingSocket = null
                    socket = candidate
                    connectedAddress = address
                    true
                }
            }
            if (accepted) {
                status("connected", address, device.name)
            } else {
                closeQuietly(candidate)
                failed("disconnected", "Kết nối máy in đã bị ngắt.")
            }
        } catch (error: Throwable) {
            synchronized(socketLock) {
                if (connectingSocket === candidate) connectingSocket = null
                if (socket === candidate) {
                    socket = null
                    connectedAddress = null
                }
            }
            closeQuietly(candidate)
            failed("connectionFailed", error.message ?: "Không thể kết nối máy in.")
        }
    }

    private fun writeBlocking(address: String, bytes: ByteArray): Map<String, Any?> =
        synchronized(ioLock) {
            val connection = connectWithoutIoLock(address)
            if (connection["state"] != "connected") {
                return failed(
                    connection["code"] as? String ?: "connectionFailed",
                    connection["message"] as? String ?: "Không thể kết nối máy in.",
                )
            }
            val activeSocket = synchronized(socketLock) { socket }
                ?: return failed("disconnected", "Máy in đã ngắt kết nối.")
            var transmissionStarted = false
            try {
                val output = activeSocket.outputStream
                var offset = 0
                while (offset < bytes.size) {
                    val length = minOf(512, bytes.size - offset)
                    transmissionStarted = true
                    output.write(bytes, offset, length)
                    offset += length
                }
                output.flush()
                mapOf("kind" to "sent")
            } catch (error: IOException) {
                synchronized(socketLock) {
                    if (socket === activeSocket) {
                        socket = null
                        connectedAddress = null
                    }
                }
                closeQuietly(activeSocket)
                if (transmissionStarted) {
                    mapOf(
                        "kind" to "unknown",
                        "code" to "unknownOutcome",
                        "message" to "Kết nối mất khi đang gửi; hóa đơn có thể đã được in một phần.",
                    )
                } else {
                    failed("writeFailed", error.message ?: "Không thể ghi dữ liệu máy in.")
                }
            }
        }

    private fun adapterProblem(): Map<String, Any?>? {
        val adapter = BluetoothAdapter.getDefaultAdapter()
            ?: return failed("bluetoothUnavailable", "Thiết bị không hỗ trợ Bluetooth.")
        if (!hasBluetoothPermission()) {
            return failed("permissionDenied", "Chưa cấp quyền Bluetooth.")
        }
        if (!adapter.isEnabled) {
            return failed("bluetoothDisabled", "Bluetooth đang tắt.")
        }
        return null
    }

    private fun hasBluetoothPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED)

    private fun closeSocket() {
        val sockets = synchronized(socketLock) {
            connectionGeneration += 1
            val values = listOfNotNull(socket, connectingSocket).distinct()
            socket = null
            connectingSocket = null
            connectedAddress = null
            values
        }
        sockets.forEach(::closeQuietly)
    }

    private fun closeQuietly(value: BluetoothSocket?) {
        try {
            value?.close()
        } catch (_: IOException) {
        }
    }

    private fun status(
        state: String,
        address: String? = null,
        name: String? = null,
    ): Map<String, Any?> = mapOf(
        "state" to state,
        "address" to address,
        "name" to name,
    )

    private fun failed(code: String, message: String): Map<String, Any?> = mapOf(
        "kind" to "failed",
        "state" to when (code) {
            "bluetoothUnavailable" -> "unavailable"
            "bluetoothDisabled" -> "disabled"
            "permissionDenied" -> "permissionDenied"
            else -> "disconnected"
        },
        "code" to code,
        "message" to message,
    )

    override fun onDestroy() {
        closeSocket()
        super.onDestroy()
    }
}
