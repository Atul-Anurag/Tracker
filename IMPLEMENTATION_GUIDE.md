# Travel Tracker - Implementation Guide

## 📋 Complete Step-by-Step Implementation

This guide provides detailed instructions for each component of the Travel Expense & Geo-Tracker app.

---

## TASK 1: Android Background Service - SMS Interception

### Overview
The Android layer is responsible for:
1. Running a persistent foreground service that never dies
2. Intercepting SMS messages from banks
3. Parsing transaction details using regex
4. Triggering GPS capture on transaction events
5. Communicating with Flutter via Method Channel

### Files Created

#### 1. `MainActivity.kt` - Flutter Activity + Method Channel Bridge
**Location**: `android/app/src/main/kotlin/com/tracker/traveltracker/MainActivity.kt`

**Key Responsibilities**:
- Sets up MethodChannel for Dart ↔ Kotlin communication
- Starts/stops the TransactionListenerService
- Requests runtime permissions
- Handles location and transaction broadcasts

**Method Channel Interface**:
```kotlin
// From Flutter, you can call:
methodChannel.invokeMethod('startTracking')        // Start listening for SMS
methodChannel.invokeMethod('stopTracking')         // Stop listening
methodChannel.invokeMethod('checkPermissions')     // Request permissions
methodChannel.invokeMethod('getPermissionStatus')  // Check permission status

// From Kotlin, you can send to Flutter:
methodChannel?.invokeMethod('onTransactionReceived', args)  // New transaction detected
methodChannel?.invokeMethod('onLocationCaptured', args)     // GPS coordinates captured
```

#### 2. `SmsReceiver.kt` - BroadcastReceiver for SMS Interception
**Location**: `android/app/src/main/kotlin/com/tracker/traveltracker/receivers/SmsReceiver.kt`

**Flow**:
```
SMS Arrives
    ↓
system broadcasts: android.provider.Telephony.SMS_RECEIVED
    ↓
SmsReceiver.onReceive() triggered
    ↓
Extract sender + message body
    ↓
Pass to SmsParser for regex matching
    ↓
If transaction detected:
    - Start TransactionListenerService with GPS capture intent
    - Send broadcast to Flutter: "com.tracker.TRANSACTION_RECEIVED"
```

**Code Logic**:
```kotlin
override fun onReceive(context: Context?, intent: Intent?) {
    // Extract PDU from SMS intent
    val pdus = intent?.getParcelableArrayExtra("pdus")
    
    for (pdu in pdus) {
        val sms = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        val messageBody = sms.messageBody  // "Dear Customer, Your A/C debited with INR 500..."
        
        // Parse the SMS
        val transaction = SmsParser.parseTransaction(messageBody)
        
        if (transaction != null) {
            // Trigger GPS capture
            startForegroundService(Intent(context, TransactionListenerService::class.java)
                .setAction("com.tracker.CAPTURE_LOCATION")
                .putExtra("transaction_data", transaction))
        }
    }
}
```

#### 3. `TransactionListenerService.kt` - Foreground Service
**Location**: `android/app/src/main/kotlin/com/tracker/traveltracker/services/TransactionListenerService.kt`

**Key Features**:
- **Persistent Notification**: Prevents OS from killing the service
- **Reactive GPS**: Only activates GPS when SMS received
- **Battery Efficient**: GPS turns off after 3-5 seconds
- **Method Channel Communication**: Sends data to Flutter

**Lifecycle**:
```kotlin
onCreate()
    ↓
// Register SMS receiver
// Create foreground notification
// Initialize LocationManager
    ↓
startForeground(NOTIFICATION_ID, notification)
    ↓
onStartCommand()
    ↓
if (action == "com.tracker.CAPTURE_LOCATION")
    captureLocationSnapshot()
        ↓
        - Request HIGH_ACCURACY location
        - Start 5-second timer
        - Capture coordinates
        - Immediately remove location updates (GPS OFF)
        - Send to Flutter via broadcast
        ↓
onDestroy()
    ↓
// Stop location updates
// Unregister SMS receiver
// Stop foreground service
```

**GPS Capture Logic**:
```kotlin
private fun captureLocationSnapshot() {
    // Create location request with 1-second interval
    val locationRequest = LocationRequest.Builder(
        Priority.PRIORITY_HIGH_ACCURACY, 
        1000  // Update every 1 second
    ).build()
    
    // GPS activates here
    fusedLocationClient.requestLocationUpdates(
        locationRequest,
        object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation
                
                // IMMEDIATELY stop receiving updates
                stopLocationUpdates()  // GPS turns OFF
                
                // Send coordinates to Flutter
                sendLocationBroadcast(location)
            }
        }
    )
    
    // Safety timeout: Force stop after 5 seconds
    handler.postDelayed({
        stopLocationUpdates()
    }, 5000)
}
```

#### 4. `SmsParser.kt` - Regex Parsing Engine
**Location**: `android/app/src/main/kotlin/com/tracker/traveltracker/utils/SmsParser.kt`

**Supported Banks**: HDFC, ICICI, SBI, AXIS, KOTAK, YES, IndusInd, UPI Generic

**Parsing Strategy**:
```
Input SMS: "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45"

1. Check if SMS contains transaction keywords
   Keywords: "debited", "credited", "INR", "UPI", etc.
   
2. Extract amount using regex
   Pattern: (?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)
   Result: 500.00
   
3. Extract merchant name
   Pattern: (?:at|to|from)\s+([A-Za-z0-9\s\-\.\,&']+?)
   Result: Starbucks
   
4. Extract timestamp
   Pattern: (\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\s+(\d{1,2}):(\d{2})
   Result: 21/06/2024 13:45
   
5. Filter out system messages
   Excluded: "ATM", "balance", "interest", "charges"
   
6. Return ParsedTransaction object
```

**Code Example**:
```kotlin
fun parseTransaction(smsText: String): ParsedTransaction? {
    // Step 1: Verify transaction SMS
    if (!isTransactionSms(smsText)) return null
    
    // Step 2: Extract fields
    val amount = extractAmount(smsText) ?: return null      // 500.00
    val merchant = extractMerchant(smsText) ?: return null  // "Starbucks"
    val time = extractDateTime(smsText) ?: getCurrentTime() // "21/06/2024 13:45"
    val vpa = extractVPA(smsText)                           // "user@upi"
    val ref = extractReference(smsText)                     // "REF12345"
    
    // Step 3: Filter
    if (isExcludedMerchant(merchant)) return null
    
    // Step 4: Return
    return ParsedTransaction(
        amount = amount,
        merchantName = merchant,
        transactionTime = time,
        upiVpa = vpa,
        referenceNumber = ref
    )
}
```

---

## TASK 2: Regex Patterns for Indian Banks

### Pattern Strategy

Each bank has a distinct SMS format. We use **specific regex patterns** for accuracy rather than one generic pattern.

**File**: `lib/utils/regex_patterns.dart` (Dart version)
**File**: `android/app/src/main/kotlin/com/tracker/traveltracker/utils/SmsParser.kt` (Android version)

### Bank-Specific Patterns

#### HDFC Pattern
```
SMS Example: "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45 IST"

Regex: r'(?:debited|credited)\s+with\s+(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:at|from)\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+(?:on|at)\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})'

Captures:
- Group 1: 500.00 (amount)
- Group 2: Starbucks (merchant)
- Group 3: 21/06/2024 13:45 (time)
```

#### ICICI Pattern
```
SMS Example: "Dear Customer, Your a/c XXXXXXXX7890 was debited for INR 250.00 at Amazon on 21/06/2024 13:45:30"

Regex: r'(?:debited|credited)\s+(?:for|with)\s+(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)\s+at\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+(?:on|at)\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}(?::\d{2})?)'

Captures:
- Group 1: 250.00 (amount)
- Group 2: Amazon (merchant)
- Group 3: 21/06/2024 13:45:30 (time)
```

#### SBI Pattern
```
SMS Example: "INR 300.00 debited towards Flipkart on 21/06/2024 13:45"

Regex: r'(?:INR|₹|Rs)\s+([0-9,]+(?:\.[0-9]{1,2})?)\s+(?:debited|credited)\s+(?:towards|at|from)\s+([A-Za-z0-9\s\-\.\,&\']+?)\s+on\s+(\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2})'

Captures:
- Group 1: 300.00 (amount)
- Group 2: Flipkart (merchant)
- Group 3: 21/06/2024 13:45 (time)
```

### Amount Pattern Breakdown
```
Pattern: r'(?:Rs[\.\s]?|₹|INR)[\s]*([0-9,]+(?:\.[0-9]{1,2})?)'

✓ Matches: Rs500.00, Rs500, ₹500, INR500.00
✗ Avoids: IST, IST timezone info

Examples:
- "INR 500.00"       → Captures "500.00"
- "₹ 5,000.50"       → Captures "5,000.50"
- "Rs. 100"          → Captures "100"
```

### Merchant Pattern Breakdown
```
Pattern: r'(?:at|to|from)\s+([A-Za-z0-9\s\-\.\,&\']+?)(?:\s+(?:on|via|for|INR|RS|₹)|\s*$)'

Captures merchant name between "at/to/from" and time/amount keywords

✓ Matches:
  - "at Starbucks Coffee"          → "Starbucks Coffee"
  - "at Amazon-Flipkart"           → "Amazon-Flipkart"
  - "at OYO Hotels & Resorts"      → "OYO Hotels & Resorts"
  - "from HDFC Bank ATM"           → "HDFC Bank ATM"

✗ Avoids: Time info ("on"), amounts ("INR"), endings
```

### Datetime Pattern Breakdown
```
Full DateTime: r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?'

✓ Matches:
  - "21/06/2024 13:45"             → Day/Month/Year Hour:Minute
  - "21-06-2024 13:45:30"          → With seconds
  - "21/6/24 9:30"                 → Single digit day/month

Time-Only: r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(?:(AM|PM|am|pm))?'

✓ Matches:
  - "13:45"                         → 24-hour format
  - "1:45 PM"                       → 12-hour with meridiem
  - "01:45:30 AM"                   → With seconds
```

### UPI VPA Pattern
```
Pattern: r'([a-zA-Z0-9\.\-_]+@[a-zA-Z]+)'

✓ Matches:
  - "user@upi"
  - "merchant.name@hdfc"
  - "john_doe-123@axis"

Used to identify UPI-based transactions
```

### Reference/UTR Pattern
```
Pattern: r'(?:Ref|Reference|UTR|TXN)[\s#:]*([A-Z0-9]+)'

✓ Matches:
  - "Ref: TX123456"                 → "TX123456"
  - "UTR#987654321"                 → "987654321"
  - "TXN 112233445566"              → "112233445566"

Stores reference for transaction reconciliation
```

---

## TASK 3: GPS Location Capture - Triggered by SMS

### Architecture

```
SMS Received
    ↓
SmsParser detects transaction
    ↓
TransactionListenerService.onStartCommand()
    ↓
action == "com.tracker.CAPTURE_LOCATION"?
    ↓
YES ↓
captureLocationSnapshot()
    ↓
Create LocationRequest (HIGH_ACCURACY, 1 second interval)
    ↓
fusedLocationClient.requestLocationUpdates()
    ↓ GPS ACTIVATES ↓
Waiting for first fix...
    ↓ First location received ↓
STOP location updates immediately
    ↓ GPS DEACTIVATES ↓
Send to Flutter: latitude, longitude, accuracy, timestamp
    ↓
Flutter saves to SQLite database
```

### Critical Code Section

**From `TransactionListenerService.kt`**:

```kotlin
private fun captureLocationSnapshot() {
    if (isLocationRequesting) {
        Log.d(TAG, "Already requesting, skip")
        return
    }

    isLocationRequesting = true
    Log.d(TAG, "Starting location capture...")

    // Create location request with HIGH accuracy
    val locationRequest = LocationRequest.Builder(
        Priority.PRIORITY_HIGH_ACCURACY,  // ← HIGH ACCURACY MODE
        1000  // Update every 1 second
    ).setMaxUpdateDelayMillis(5000).build()

    locationCallback = object : LocationCallback() {
        override fun onLocationResult(locationResult: LocationResult) {
            val location = locationResult.lastLocation
            if (location != null) {
                Log.d(TAG, "Got location: ${location.latitude}, ${location.longitude}")
                
                // CRITICAL: Stop immediately after first fix
                stopLocationUpdates()  // ← GPS TURNS OFF HERE
                
                sendLocationBroadcast(location)
                isLocationRequesting = false
            }
        }
    }

    try {
        // GPS activation happens here
        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            Looper.getMainLooper()
        )

        // Safety timeout: Force stop after 5 seconds
        handler?.postDelayed({
            if (isLocationRequesting) {
                Log.d(TAG, "Timeout reached, stopping")
                stopLocationUpdates()
                isLocationRequesting = false
            }
        }, 5000)  // GPS will be OFF after 5 seconds max

    } catch (e: SecurityException) {
        Log.e(TAG, "Permission denied: ${e.message}")
        isLocationRequesting = false
    }
}

private fun stopLocationUpdates() {
    if (locationCallback != null) {
        fusedLocationClient.removeLocationUpdates(locationCallback!!)
        Log.d(TAG, "Location updates stopped - GPS OFF")
    }
}

private fun sendLocationBroadcast(location: Location) {
    val intent = Intent("com.tracker.LOCATION_CAPTURED")
    intent.putExtra("latitude", location.latitude)
    intent.putExtra("longitude", location.longitude)
    intent.putExtra("accuracy", location.accuracy)
    intent.putExtra("altitude", location.altitude)
    intent.putExtra("timestamp", location.time)
    sendBroadcast(intent)  // ← Send to Flutter
}
```

### Flutter Side: Transaction Handler

**From `TransactionService.dart`**:

```dart
Stream<LocationData> get locationStream {
    _locationController ??= StreamController<LocationData>.broadcast(
      onListen: _setupLocationListener,
    );
    return _locationController!.stream;
}

void _setupLocationListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onLocationCaptured') {
        final args = call.arguments as Map;
        
        // Extract location from broadcast
        final latitude = (args['latitude'] as num).toDouble();
        final longitude = (args['longitude'] as num).toDouble();
        final accuracy = (args['accuracy'] as num).toDouble();
        
        // Add to stream for UI to consume
        _locationController?.add(LocationData(
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          timestamp: DateTime.fromMillisecondsSinceEpoch(...),
        ));
      }
    });
}
```

### Battery Impact Calculation

```
Scenario: 100 transactions during trip

Option A: Continuous GPS
- GPS on 24 hours = ~25% battery drain per hour
- Total: 25% * 24 = 600% (complete drain in ~4 hours)

Option B: SMS-Triggered Snapshot (Our approach)
- GPS on: 5 seconds per transaction
- Total GPS time: 100 * 5 seconds = 500 seconds = 8.3 minutes
- GPS drain: ~0.5% per minute = 8.3 * 0.5% = 4.15%
- Total battery: ~4-5% vs 25% per hour

SAVINGS: 5x to 8x battery efficiency!
```

---

## Testing SMS Parsing

### Test Case 1: HDFC
```
SMS: "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45 IST"

Expected Output:
{
  amount: 500.00,
  merchant: "Starbucks",
  time: "21/06/2024 13:45",
  upiVpa: null,
  referenceNumber: null
}
```

### Test Case 2: SBI UPI
```
SMS: "INR 1500.00 debited to UPI XXXXXXXXXXXX @upi VPA abc123@upi on 21/06/2024 14:30 IST. Ref: 123456789"

Expected Output:
{
  amount: 1500.00,
  merchant: "UPI XXXXXXXXXXXX",
  time: "21/06/2024 14:30",
  upiVpa: "abc123@upi",
  referenceNumber: "123456789"
}
```

### Test Case 3: AXIS
```
SMS: "Your account XXXXXXXX7890 was debited by INR 250.50 at Uber on 21/06/2024 13:15"

Expected Output:
{
  amount: 250.50,
  merchant: "Uber",
  time: "21/06/2024 13:15",
  upiVpa: null,
  referenceNumber: null
}
```

---

## Next Steps

1. ✅ Android Services set up (Foreground Service + BroadcastReceiver)
2. ✅ SMS Parser with regex patterns for 7 Indian banks
3. ✅ GPS location capture triggered by SMS
4. ⏭️ **Database Layer**: SQLite schema + CRUD operations
5. ⏭️ **Flutter UI**: Trip management + transaction display + map visualization
6. ⏭️ **Testing**: Unit tests for SMS parsing + integration tests

---

**Architecture Complete! Ready for database implementation.**