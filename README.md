# 🧭 Travel Expense & Geo-Tracker App (India)

A lightweight Flutter mobile application that tracks user spending during a trip and maps out exactly where each expense occurred using GPS-triggered location capture on transaction events.

## 🎯 Core Features

- **Start Trip Toggle**: Toggle to begin/end expense tracking
- **SMS Transaction Interception**: Automatically detects incoming transaction alerts from Indian banks
- **GPS Snapshot**: Captures device coordinates only when transactions occur (battery efficient)
- **Interactive Map Timeline**: Visual representation of all expenses mapped by location
- **Offline-First**: All data stored locally in SQLite until trip ends
- **Batch Geocoding**: Converts coordinates to readable addresses after trip ends

## 🔋 Battery Optimization Strategy

### Reactive Approach (NOT continuous tracking)
- ❌ **No continuous GPS**: GPS radio stays OFF until needed
- ✅ **Event-Triggered GPS**: GPS activates only for 3-5 seconds when SMS received
- ✅ **Immediate Shutdown**: GPS immediately deactivates after capturing coordinates
- ✅ **Battery Efficient**: ~5% battery per 100 transactions vs 20-30% with continuous GPS

## 📋 Project Structure

```
Tracker/
├── android/
│   └── app/src/main/
│       ├── kotlin/com/tracker/traveltracker/
│       │   ├── MainActivity.kt                 # Main Flutter Activity + Method Channel
│       │   ├── receivers/
│       │   │   ├── SmsReceiver.kt              # SMS BroadcastReceiver (intercepts SMS)
│       │   │   └── BootReceiver.kt             # Auto-start on device boot
│       │   ├── services/
│       │   │   └── TransactionListenerService.kt # Foreground Service (persistent)
│       │   └── utils/
│       │       └── SmsParser.kt                # Regex parsing for 7 Indian banks
│       └── AndroidManifest.xml
├── lib/
│   ├── main.dart                               # App entry point
│   ├── models/
│   │   └── transaction_model.dart              # Transaction & Trip models
│   ├── database/
│   │   └── database_helper.dart                # SQLite database layer
│   ├── services/
│   │   ├── transaction_service.dart            # Dart-Kotlin bridge (Method Channel)
│   │   └── location_service.dart               # GPS & geocoding service
│   ├── utils/
│   │   └── regex_patterns.dart                 # Bank SMS parsing patterns
│   └── ui/
│       └── screens/
│           └── home_screen.dart                # Main UI
└── pubspec.yaml                                # Dependencies
```

## 🏗️ Technical Architecture

### 1. Android Background Service Layer

```
┌─────────────────────────────────────────────────────────┐
│          TransactionListenerService (Foreground)        │
│                    (Always Running)                      │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌────────────────┐       ┌──────────────────┐         │
│  │  SMS Receiver  │       │ Location Manager │         │
│  │  (intercepts   │───▶   │ (GPS activation) │         │
│  │   SMS)         │       │ (3-5 sec only)   │         │
│  └────────────────┘       └──────────────────┘         │
│                                   │                      │
│                                   ▼                      │
│                        ┌──────────────────┐             │
│                        │ Local SQLite DB  │             │
│                        │ (offline storage)│             │
│                        └──────────────────┘             │
└─────────────────────────────────────────────────────────┘
                              ▲
                              │ Method Channel
                              ▼
           ┌─────────────────────────────────────┐
           │    Flutter App Layer (UI)           │
           │  - Trip Management                  │
           │  - Expense Display                  │
           │  - Map Visualization                │
           └─────────────────────────────────────┘
```

### 2. SMS Parsing Flow

```
Bank SMS Received
    ▼
SmsReceiver.onReceive()
    ▼
SmsParser.parseTransaction()
    ▼
Regex Pattern Match (7 banks supported)
    ▼
Extract: Amount, Merchant, Time
    ▼
Filter: Exclude system messages
    ▼
Send Broadcast: "CAPTURE_LOCATION"
    ▼
TransactionListenerService.captureLocationSnapshot()
    ▼
HIGH_ACCURACY GPS activation (5 sec)
    ▼
Coordinates captured ▶ GPS shutdown ▶ DB saved
    ▼
Send to Flutter: "onLocationCaptured"
```

## 🏦 Supported Banks & SMS Patterns

The app supports **7 major Indian banks** with dedicated regex patterns:

| Bank | Example SMS Format |
|------|-------------------|
| **HDFC** | "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45 IST" |
| **ICICI** | "Dear Customer, Your a/c XXXXXXXX7890 was debited for INR 250.00 at Amazon on 21/06/2024 13:45:30 IST" |
| **SBI** | "INR 300.00 debited towards Flipkart on 21/06/2024 13:45" |
| **AXIS** | "Your account XXXXXXXX7890 was debited by INR 150.00 at BigBasket on 21/06/2024 13:45 IST" |
| **KOTAK** | "Dear Customer, INR 200.00 debited from your account ending XXXX7890 at Uber on 21/06/2024 13:45" |
| **YES BANK** | "Alert: INR 100.00 debited from account ending 7890 at Zomato on 21/06/2024 13:45" |
| **IndusInd** | "Your account ending 7890 was debited INR 175.00 at OYO Hotels on 21/06/2024 13:45" |

Each bank pattern extracts:
- ✓ Amount (₹, Rs, INR formats)
- ✓ Merchant/Vendor name
- ✓ Transaction timestamp
- ✓ UPI VPA (if applicable)
- ✓ Reference/UTR number

## 📊 Database Schema

### Trips Table
```sql
CREATE TABLE trips (
    trip_id TEXT PRIMARY KEY,
    trip_name TEXT NOT NULL,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP
);
```

### Expenses Table
```sql
CREATE TABLE expenses (
    expense_id TEXT PRIMARY KEY,
    trip_id TEXT NOT NULL,
    amount REAL NOT NULL,
    merchant_name TEXT,
    transaction_time TIMESTAMP NOT NULL,
    latitude REAL,
    longitude REAL,
    resolved_address TEXT,        -- Batch geocoded after trip
    category TEXT,                 -- Auto-categorized
    raw_sms_text TEXT,
    upi_vpa TEXT,
    reference_number TEXT,
    created_at TIMESTAMP,
    FOREIGN KEY(trip_id) REFERENCES trips(trip_id)
);
```

## 🚀 Setup & Installation

### Prerequisites
- Flutter 3.0+
- Android SDK (API level 21+)
- Kotlin 1.7+
- Google Play Services (location)
- Android Device (Android 5.0+)

### Installation Steps

1. **Clone the repository**
```bash
git clone <repo-url>
cd Tracker
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Android (if not auto-configured)**
```bash
cd android
./gradlew clean build
cd ..
```

4. **Grant permissions in AndroidManifest.xml** (already included)
```xml
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

5. **Run the app**
```bash
flutter run
```

## 🔐 Required Permissions

The app requests these permissions at runtime:

1. **SMS Permissions**
   - `RECEIVE_SMS` - Listen for incoming transaction alerts
   - `READ_SMS` - Read SMS body for parsing

2. **Location Permissions**
   - `ACCESS_FINE_LOCATION` - High-accuracy GPS coordinates
   - `ACCESS_COARSE_LOCATION` - Fallback to network location
   - `ACCESS_BACKGROUND_LOCATION` - Capture location in background

3. **Service Permissions**
   - `FOREGROUND_SERVICE` - Run persistent notification
   - `FOREGROUND_SERVICE_LOCATION` - GPS access in foreground service

## 📱 Usage

### Starting a Trip

1. Open the app
2. Tap "Start Trip"
3. Enter trip name (e.g., "Goa Vacation")
4. Tap "Start"
5. **Foreground service activates** with persistent notification

### During Trip

- **Make a transaction** using any Indian bank's UPI/Debit card
- **Receive SMS alert** from your bank
- **App automatically**:
  - Detects the SMS
  - Activates GPS for 3-5 seconds
  - Captures your coordinates
  - Stores data locally
  - Deactivates GPS (saves battery)

### Ending a Trip

1. Tap the red "Stop" button
2. App stops listening for SMS
3. Batch geocodes all coordinates into addresses
4. Generates interactive map timeline

## 🔌 API Reference

### Method Channel (Dart ↔ Kotlin)

```dart
// Start background tracking
await platform.invokeMethod('startTracking');

// Stop background tracking
await platform.invokeMethod('stopTracking');

// Check permissions status
final status = await platform.invokeMethod('getPermissionStatus');

// Listen for transaction events
channel.setMethodCallHandler((call) {
  if (call.method == 'onTransactionReceived') {
    // Transaction detected
  }
  if (call.method == 'onLocationCaptured') {
    // Location captured
  }
});
```

### Core Services

#### TransactionService
```dart
final service = TransactionService();

// Stream of detected transactions
service.transactionStream.listen((transaction) {
  print('Transaction: ${transaction.merchantName} ₹${transaction.amount}');
});

// Stream of captured locations
service.locationStream.listen((location) {
  print('Location: ${location.latitude}, ${location.longitude}');
});
```

#### LocationService
```dart
final locationService = LocationService();

// Capture high-accuracy location (5 sec timeout)
final position = await locationService.getHighAccuracyLocation();

// Reverse geocode coordinates to address
final address = await locationService.reverseGeocode(lat, lon);

// Batch geocode all trip expenses (after trip ends)
await locationService.batchGeocodeTrip(tripId);
```

#### DatabaseHelper
```dart
final db = DatabaseHelper();

// Create new trip
final tripId = await db.createTrip('Goa Vacation');

// Save transaction with location
await db.saveExpense(transaction);

// Get trip expenses
final expenses = await db.getTripExpenses(tripId);

// Get analytics
final total = await db.getTotalExpenseForTrip(tripId);
final breakdown = await db.getCategoryBreakdown(tripId);
```

## 🎨 App Screenshots

```
┌─────────────────────┐
│ Travel Tracker 🧭   │
├─────────────────────┤
│                     │
│  No Active Trip     │
│                     │
│  [Start Trip]       │
│                     │
└─────────────────────┘

┌─────────────────────┐
│ Goa Vacation 2024   │
├─────────────────────┤
│ Total: ₹5,234       │
│ Transactions: 12    │
├─────────────────────┤
│ 🍽️ Starbucks        │
│    Baga Beach       │
│    ₹450             │
│                     │
│ 🚕 Uber            │
│    Panjim           │
│    ₹250             │
│                     │
│ 🏨 OYO Hotels      │
│    South Goa        │
│    ₹2,000           │
│                     │
│          [⏹️ Stop]   │
└─────────────────────┘
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| App not starting foreground service | Check FOREGROUND_SERVICE permission granted |
| SMS not detected | Ensure app SMS permission is enabled in Settings |
| GPS not capturing | Verify FINE_LOCATION permission + GPS hardware |
| Crashes on older Android | Ensure Android API 21+ |
| Addresses not showing | Wait after trip ends (batch geocoding in progress) |

## 🔮 Future Enhancements

- [ ] Automatic merchant categorization (Food, Transport, Stay, etc.)
- [ ] Real-time map visualization with heatmap
- [ ] Expense sharing with travel companions
- [ ] Budget alerts and analytics dashboard
- [ ] Cloud sync with Firebase (end-to-end encrypted)
- [ ] Multi-currency support
- [ ] OCR for manual receipt uploads
- [ ] Expense split calculator

## 📄 License

MIT License - See LICENSE file for details

## 👨‍💻 Contributors

- **Atul Anurag** - Core Development & Architecture

## 📞 Support

For issues or feature requests, please open an issue on GitHub.

---

**Built with ❤️ for Indian travelers**
