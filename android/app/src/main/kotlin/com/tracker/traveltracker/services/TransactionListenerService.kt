package com.tracker.traveltracker.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.Priority
import com.tracker.traveltracker.MainActivity
import com.tracker.traveltracker.R
import com.tracker.traveltracker.receivers.SmsReceiver
import com.tracker.traveltracker.utils.SmsParser

/**
 * TransactionListenerService - Foreground Service
 * 
 * CRITICAL FEATURES:
 * 1. Runs with persistent notification to prevent OS termination
 * 2. Listens for incoming SMS (transaction alerts)
 * 3. On transaction detected: Wakes up GPS for 3-5 seconds (HIGH_ACCURACY)
 * 4. Captures coordinates and immediately shuts down GPS (battery efficient)
 * 5. Stores location data locally in SQLite database
 * 
 * This is a REACTIVE approach - GPS only activates on transaction trigger
 */
class TransactionListenerService : Service() {
    companion object {
        private const val TAG = "TransactionListenerService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "transaction_listener_channel"
        private const val GPS_TIMEOUT_MS = 5000L // 5 seconds to capture location
        private const val LOCATION_REQUEST_PRIORITY = Priority.PRIORITY_HIGH_ACCURACY
    }

    private lateinit var notificationManager: NotificationManager
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationManager: LocationManager
    private var smsReceiver: SmsReceiver? = null
    private var locationCallback: LocationCallback? = null
    private var handler: Handler? = null
    private var isLocationRequesting = false

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service Created")
        
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fusedLocationClient = com.google.android.gms.location.LocationServices.getFusedLocationProviderClient(this)
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        handler = Handler(Looper.getMainLooper())

        // Register SMS receiver
        smsReceiver = SmsReceiver()
        val intentFilter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(smsReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsReceiver, intentFilter)
        }

        // Create and show persistent notification
        startForeground(NOTIFICATION_ID, createNotification())
        
        Log.d(TAG, "Foreground Service Started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called with action: ${intent?.action}")

        // Check if this is a location capture request (triggered by SMS)
        if (intent?.action == "com.tracker.CAPTURE_LOCATION") {
            Log.d(TAG, "Location capture triggered")
            captureLocationSnapshot()
        }

        // Service should keep running until explicitly stopped
        return START_STICKY
    }

    /**
     * CORE FUNCTION: Capture GPS location snapshot
     * 
     * This function:
     * 1. Activates GPS with HIGH_ACCURACY priority
     * 2. Waits for 3-5 seconds for location fix
     * 3. Captures coordinates
     * 4. Immediately deactivates GPS (battery efficient)
     * 5. Stores in local SQLite database
     */
    private fun captureLocationSnapshot() {
        if (isLocationRequesting) {
            Log.d(TAG, "Location request already in progress, skipping")
            return
        }

        isLocationRequesting = true
        Log.d(TAG, "Starting location snapshot capture...")

        // Create location request with HIGH_ACCURACY and SHORT interval
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000).apply {
            setMaxUpdateDelayMillis(5000)
        }.build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                val location = locationResult.lastLocation
                if (location != null) {
                    Log.d(TAG, "Location captured: Lat=${location.latitude}, Lon=${location.longitude}")
                    
                    // Stop location updates immediately
                    stopLocationUpdates()
                    
                    // Save location to local database (handled by Flutter layer)
                    sendLocationBroadcast(location)
                    
                    isLocationRequesting = false
                }
            }
        }

        try {
            // Request location updates
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                fusedLocationClient.requestLocationUpdates(
                    locationRequest,
                    locationCallback!!,
                    Looper.getMainLooper()
                )
            } else {
                fusedLocationClient.requestLocationUpdates(
                    locationRequest,
                    locationCallback!!,
                    Looper.getMainLooper()
                )
            }

            // Auto-stop GPS after 5 seconds timeout
            handler?.postDelayed({
                if (isLocationRequesting) {
                    Log.d(TAG, "Location timeout reached, stopping updates")
                    stopLocationUpdates()
                    isLocationRequesting = false
                }
            }, GPS_TIMEOUT_MS)

        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission not granted: ${e.message}")
            isLocationRequesting = false
        }
    }

    /**
     * Stop location updates immediately (turns off GPS radio)
     */
    private fun stopLocationUpdates() {
        if (locationCallback != null) {
            try {
                fusedLocationClient.removeLocationUpdates(locationCallback!!)
                Log.d(TAG, "Location updates stopped - GPS radio turned off")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping location updates: ${e.message}")
            }
        }
    }

    /**
     * Send location data to Flutter layer via broadcast
     */
    private fun sendLocationBroadcast(location: Location) {
        val intent = Intent("com.tracker.LOCATION_CAPTURED")
        intent.putExtra("latitude", location.latitude)
        intent.putExtra("longitude", location.longitude)
        intent.putExtra("accuracy", location.accuracy)
        intent.putExtra("altitude", location.altitude)
        intent.putExtra("timestamp", location.time)
        sendBroadcast(intent)
    }

    /**
     * Create persistent notification for foreground service
     */
    private fun createNotification(): Notification {
        // Create notification channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Transaction Listener",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Listening for transaction SMS and capturing location..."
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent to open app when notification is tapped
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Trip Active 🧭")
            .setContentText("Tracking expenses and location...")
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service Destroyed")
        
        // Stop location updates
        stopLocationUpdates()
        
        // Unregister SMS receiver
        if (smsReceiver != null) {
            try {
                unregisterReceiver(smsReceiver)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver: ${e.message}")
            }
        }
        
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // This is a started service, not a bound service
    }
}
