package com.tracker.traveltracker

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.SupportMapFragment
import com.tracker.traveltracker.services.TransactionListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.tracker.traveltracker/transaction"
        private const val PERMISSION_CODE = 100
    }

    private val locationBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.tracker.LOCATION_CAPTURED" -> {
                    val latitude = intent.getDoubleExtra("latitude", 0.0)
                    val longitude = intent.getDoubleExtra("longitude", 0.0)
                    val accuracy = intent.getFloatExtra("accuracy", 0f)
                    val timestamp = intent.getLongExtra("timestamp", 0L)

                    Log.d(TAG, "Location broadcast received: $latitude, $longitude, accuracy: $accuracy")

                    // Send to Flutter layer
                    val args = mapOf(
                        "latitude" to latitude,
                        "longitude" to longitude,
                        "accuracy" to accuracy.toDouble(),
                        "timestamp" to timestamp
                    )
                    methodChannel?.invokeMethod("onLocationCaptured", args)
                }
                "com.tracker.TRANSACTION_RECEIVED" -> {
                    val amount = intent.getDoubleExtra("amount", 0.0)
                    val merchant = intent.getStringExtra("merchant") ?: "Unknown"
                    val time = intent.getStringExtra("time") ?: ""
                    val rawSms = intent.getStringExtra("raw_sms") ?: ""

                    Log.d(TAG, "Transaction broadcast received: ₹$amount at $merchant")

                    val args = mapOf(
                        "amount" to amount,
                        "merchant" to merchant,
                        "time" to time,
                        "raw_sms" to rawSms
                    )
                    methodChannel?.invokeMethod("onTransactionReceived", args)
                }
            }
        }
    }

    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up method channel for communication between Flutter and Android
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    startTracking()
                    result.success("Tracking started")
                }
                "stopTracking" -> {
                    stopTracking()
                    result.success("Tracking stopped")
                }
                "checkPermissions" -> {
                    checkAndRequestPermissions()
                    result.success("Permissions checked")
                }
                "getPermissionStatus" -> {
                    val status = getPermissionStatus()
                    result.success(status)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register broadcast receivers
        val intentFilter = IntentFilter()
        intentFilter.addAction("com.tracker.LOCATION_CAPTURED")
        intentFilter.addAction("com.tracker.TRANSACTION_RECEIVED")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(locationBroadcastReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(locationBroadcastReceiver, intentFilter)
        }
    }

    /**
     * Start the background tracking service
     */
    private fun startTracking() {
        Log.d(TAG, "Starting transaction tracking service...")
        val serviceIntent = Intent(this, TransactionListenerService::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    /**
     * Stop the background tracking service
     */
    private fun stopTracking() {
        Log.d(TAG, "Stopping transaction tracking service...")
        val serviceIntent = Intent(this, TransactionListenerService::class.java)
        stopService(serviceIntent)
    }

    /**
     * Check and request necessary permissions
     */
    private fun checkAndRequestPermissions() {
        val requiredPermissions = arrayOf(
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_SMS,
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.FOREGROUND_SERVICE,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            requiredPermissions.plus(Manifest.permission.FOREGROUND_SERVICE_LOCATION)
        }

        val permissionsToRequest = requiredPermissions.filter {
            ActivityCompat.checkSelfPermission(this, it) != android.content.pm.PackageManager.PERMISSION_GRANTED
        }.toTypedArray()

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissionsToRequest, PERMISSION_CODE)
        }
    }

    /**
     * Get current permission status
     */
    private fun getPermissionStatus(): Map<String, Boolean> {
        return mapOf(
            "SMS_READ" to (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "LOCATION_FINE" to (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "LOCATION_COARSE" to (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == android.content.pm.PackageManager.PERMISSION_GRANTED),
            "FOREGROUND_SERVICE" to (ActivityCompat.checkSelfPermission(this, Manifest.permission.FOREGROUND_SERVICE) == android.content.pm.PackageManager.PERMISSION_GRANTED),
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(locationBroadcastReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
    }
}
