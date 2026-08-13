package com.example.shambabora_mobile

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.companion.AssociationInfo
import android.companion.AssociationRequest
import android.companion.BluetoothDeviceFilter
import android.companion.CompanionDeviceManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.IntentSender
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Collections
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "warehouse_app.bluetooth.print.receipt"
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val companionDeviceSetupFeature = "android.software.companion_device_setup"
    private val selectPrinterRequestCode = 7301
    private val pickerHandler = Handler(Looper.getMainLooper())
    private val directExecutor = Executor { command -> command.run() }
    private var pendingPickerResult: MethodChannel.Result? = null
    private var pickerTimeout: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPairedPrinters" -> getPairedPrinters(result)
                    "scanPrinters" -> scanPrinters(result)
                    "pickPrinter" -> pickPrinter(result)
                    "printReceipt" -> {
                        val address = call.argument<String>("address")
                        val data = call.argument<ByteArray>("data")
                        if (address.isNullOrBlank() || data == null) {
                            result.error(
                                "invalid_arguments",
                                "Printer address and receipt data are required.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        printReceipt(address, data, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != selectPrinterRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            completePickerError("printer_not_selected", "No printer was selected.")
            return
        }

        val bluetoothDevice = bluetoothDeviceFromCompanionResult(data)
        if (bluetoothDevice != null) {
            try {
                bluetoothDevice.createBond()
            } catch (_: Exception) {
            }
            completePickerSuccess(bluetoothDevice)
            return
        }

        val associationInfo = associationInfoFromResult(data)
        if (associationInfo != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            completePickerSuccess(associationInfo)
            return
        }

        completePickerError("invalid_printer", "Selected printer is invalid.")
    }

    @SuppressLint("MissingPermission")
    private fun getPairedPrinters(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("bluetooth_unavailable", "Bluetooth is not available on this device.", null)
            return
        }
        if (!hasBluetoothConnectPermission()) {
            result.error("permission_denied", "Bluetooth permission is required.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetooth_disabled", "Turn on Bluetooth before selecting a printer.", null)
            return
        }

        val devices = adapter.bondedDevices.map { device -> printerMap(device) }
        result.success(devices)
    }

    @SuppressLint("MissingPermission")
    private fun scanPrinters(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("bluetooth_unavailable", "Bluetooth is not available on this device.", null)
            return
        }
        if (!hasBluetoothConnectPermission() || !hasBluetoothScanPermission() || !hasLocationPermission()) {
            result.error("permission_denied", "Bluetooth and location permissions are required.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetooth_disabled", "Turn on Bluetooth before selecting a printer.", null)
            return
        }

        val devices = Collections.synchronizedMap(LinkedHashMap<String, Map<String, String>>())
        adapter.bondedDevices.forEach { device -> devices[device.address] = printerMap(device) }

        val latch = CountDownLatch(1)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device = bluetoothDeviceFromDiscovery(intent)
                        if (device != null) {
                            devices[device.address] = printerMap(device)
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> latch.countDown()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }

        registerBluetoothReceiver(receiver, filter)

        Thread {
            try {
                if (adapter.isDiscovering) adapter.cancelDiscovery()
                if (!adapter.startDiscovery()) {
                    latch.countDown()
                }
                latch.await(10, TimeUnit.SECONDS)
                if (adapter.isDiscovering) adapter.cancelDiscovery()

                runOnUiThread {
                    unregisterSafely(receiver)
                    result.success(devices.values.toList())
                }
            } catch (error: Exception) {
                runOnUiThread {
                    unregisterSafely(receiver)
                    result.error(
                        "scan_failed",
                        error.localizedMessage ?: "Could not scan printers.",
                        null,
                    )
                }
            }
        }.start()
    }

    @SuppressLint("MissingPermission")
    private fun pickPrinter(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("bluetooth_unavailable", "Bluetooth is not available on this device.", null)
            return
        }
        if (!hasBluetoothConnectPermission() || !hasBluetoothScanPermission()) {
            result.error("permission_denied", "Bluetooth permission is required.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetooth_disabled", "Turn on Bluetooth before selecting a printer.", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "device_picker_unavailable",
                "Android's Bluetooth device dialog is not available on this Android version.",
                null,
            )
            return
        }
        if (!packageManager.hasSystemFeature(companionDeviceSetupFeature)) {
            result.error(
                "device_picker_unavailable",
                "Android's Bluetooth device dialog is not available on this phone.",
                null,
            )
            return
        }
        if (pendingPickerResult != null) {
            result.error("picker_active", "A Bluetooth device picker is already open.", null)
            return
        }

        try {
            if (adapter.isDiscovering) adapter.cancelDiscovery()
        } catch (_: Exception) {
        }

        pendingPickerResult = result
        pickerTimeout = Runnable {
            completePickerError("printer_not_selected", "No printer was selected.")
        }
        pickerHandler.postDelayed(pickerTimeout!!, 90000)

        val printerFilter = BluetoothDeviceFilter.Builder().build()
        val request = AssociationRequest.Builder()
            .addDeviceFilter(printerFilter)
            .setSingleDevice(false)
            .build()
        val deviceManager = getSystemService(Context.COMPANION_DEVICE_SERVICE) as CompanionDeviceManager

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                deviceManager.associate(
                    request,
                    directExecutor,
                    object : CompanionDeviceManager.Callback() {
                        override fun onAssociationPending(intentSender: IntentSender) {
                            launchCompanionChooser(intentSender)
                        }

                        override fun onAssociationCreated(associationInfo: AssociationInfo) {
                            if (pendingPickerResult != null) {
                                completePickerSuccess(associationInfo)
                            }
                        }

                        override fun onFailure(errorMessage: CharSequence?) {
                            completePickerError(
                                "device_picker_failed",
                                errorMessage?.toString()
                                    ?: "Android could not find Bluetooth devices.",
                            )
                        }
                    },
                )
            } else {
                @Suppress("DEPRECATION")
                deviceManager.associate(
                    request,
                    object : CompanionDeviceManager.Callback() {
                        override fun onDeviceFound(chooserLauncher: IntentSender) {
                            launchCompanionChooser(chooserLauncher)
                        }

                        override fun onFailure(error: CharSequence?) {
                            completePickerError(
                                "device_picker_failed",
                                error?.toString()
                                    ?: "Android could not find Bluetooth devices.",
                            )
                        }
                    },
                    null,
                )
            }
        } catch (error: Exception) {
            completePickerError(
                "device_picker_failed",
                error.localizedMessage ?: "Android could not open the Bluetooth device dialog.",
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun printReceipt(address: String, data: ByteArray, result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("bluetooth_unavailable", "Bluetooth is not available on this device.", null)
            return
        }
        if (!hasBluetoothConnectPermission()) {
            result.error("permission_denied", "Bluetooth permission is required.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetooth_disabled", "Turn on Bluetooth before printing.", null)
            return
        }

        Thread {
            var socket: android.bluetooth.BluetoothSocket? = null
            try {
                adapter.cancelDiscovery()
                val device = adapter.getRemoteDevice(address)
                socket = device.createRfcommSocketToServiceRecord(sppUuid)
                socket.connect()
                socket.outputStream.use { stream ->
                    stream.write(data)
                    stream.flush()
                }
                runOnUiThread { result.success(null) }
            } catch (error: IOException) {
                runOnUiThread {
                    result.error(
                        "print_failed",
                        error.localizedMessage ?: "Could not print receipt.",
                        null,
                    )
                }
            } catch (error: IllegalArgumentException) {
                runOnUiThread {
                    result.error(
                        "invalid_printer",
                        error.localizedMessage ?: "Selected printer is invalid.",
                        null,
                    )
                }
            } finally {
                try {
                    socket?.close()
                } catch (_: IOException) {
                }
            }
        }.start()
    }

    private fun launchCompanionChooser(intentSender: IntentSender) {
        try {
            startIntentSenderForResult(
                intentSender,
                selectPrinterRequestCode,
                null,
                0,
                0,
                0,
            )
        } catch (error: IntentSender.SendIntentException) {
            completePickerError(
                "device_picker_failed",
                error.localizedMessage ?: "Android could not open the Bluetooth device dialog.",
            )
        }
    }

    private fun completePickerSuccess(device: BluetoothDevice) {
        val result = clearPendingPicker()
        result?.success(printerMap(device))
    }

    private fun completePickerSuccess(associationInfo: AssociationInfo) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val address = associationInfo.deviceMacAddress?.toString()
        if (address.isNullOrBlank()) {
            completePickerError("invalid_printer", "Selected printer does not expose a Bluetooth address.")
            return
        }
        val name = associationInfo.displayName?.toString()?.takeIf { it.isNotBlank() }
            ?: "Bluetooth Printer"
        completePickerSuccess(name, address)
    }

    private fun completePickerSuccess(name: String, address: String) {
        val result = clearPendingPicker()
        result?.success(
            mapOf(
                "name" to name,
                "address" to address,
            ),
        )
    }

    private fun completePickerError(code: String, message: String) {
        val result = clearPendingPicker()
        result?.error(code, message, null)
    }

    private fun clearPendingPicker(): MethodChannel.Result? {
        val result = pendingPickerResult
        pendingPickerResult = null
        pickerTimeout?.let { pickerHandler.removeCallbacks(it) }
        pickerTimeout = null
        return result
    }

    private fun registerBluetoothReceiver(receiver: BroadcastReceiver, filter: IntentFilter) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun printerMap(device: BluetoothDevice): Map<String, String> {
        return mapOf(
            "name" to (device.name ?: "Bluetooth Printer"),
            "address" to device.address,
        )
    }

    private fun bluetoothDeviceFromDiscovery(intent: Intent): BluetoothDevice? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }
    }

    private fun bluetoothDeviceFromCompanionResult(intent: Intent?): BluetoothDevice? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent?.getParcelableExtra(CompanionDeviceManager.EXTRA_DEVICE)
        }
    }

    private fun associationInfoFromResult(intent: Intent?): AssociationInfo? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent?.getParcelableExtra(CompanionDeviceManager.EXTRA_ASSOCIATION, AssociationInfo::class.java)
        } else {
            null
        }
    }

    private fun unregisterSafely(receiver: BroadcastReceiver) {
        try {
            unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasBluetoothScanPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasLocationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }
}
