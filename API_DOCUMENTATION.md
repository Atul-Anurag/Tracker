# API Documentation - Travel Tracker

## Flutter Layer APIs

### 1. TransactionService

**Purpose**: Manages transaction detection and location capture streams

#### Streams

```dart
/// Stream of detected transactions from SMS
Stream<Transaction> get transactionStream

/// Stream of captured GPS locations
Stream<LocationData> get locationStream
```

#### Methods

```dart
/// Start background tracking service
Future<void> startTracking()
// Activates foreground service
// Listens for incoming SMS
// Ready to capture locations

/// Stop background tracking
Future<void> stopTracking()
// Deactivates SMS listening
// Stops foreground service
// GPS turns off

/// Check and request permissions
Future<void> checkPermissions()
// Requests: SMS, Location, Foreground Service
// Shows permission dialogs to user

/// Save transaction with location
Future<void> saveTransactionWithLocation(
  Transaction transaction,
  double latitude,
  double longitude,
)
// Combines transaction data + coordinates
// Saves to local SQLite database

/// Get all transactions for trip
Future<List<Transaction>> getTransactions(String tripId)
// Retrieves all expenses for a specific trip
// Ordered by transaction time (newest first)

/// Clean up resources
void dispose()
// Closes streams
// Releases memory
// Call when leaving screen
```

#### Usage Example

```dart
class MyTrip extends StatefulWidget {
  @override
  State<MyTrip> createState() => _MyTripState();
}

class _MyTripState extends State<MyTrip> {
  late TransactionService _transactionService;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _transactionService = TransactionService();
    
    // Listen for new transactions
    _transactionService.transactionStream.listen((transaction) {
      print('New transaction: ${transaction.merchantName}');
      setState(() => _transactions.add(transaction));
    });

    // Listen for location captures
    _transactionService.locationStream.listen((location) {
      print('Location: ${location.latitude}, ${location.longitude}');
    });

    // Start tracking
    _transactionService.startTracking();
  }

  @override
  void dispose() {
    _transactionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return ListTile(
          title: Text(tx.merchantName),
          subtitle: Text('₹${tx.amount}'),
          trailing: Text(tx.resolvedAddress ?? 'Capturing...'),
        );
      },
    );
  }
}
```

---

### 2. LocationService

**Purpose**: Handles GPS capture, high-accuracy positioning, and reverse geocoding

#### Methods

```dart
/// Request location permissions
Future<bool> requestLocationPermissions()
// Shows permission request dialog
// Returns: true if granted, false if denied
// Required before calling other methods

/// Check if location services are enabled
Future<bool> isLocationServiceEnabled()
// Checks device GPS is enabled
// Returns: true if enabled
// Prompts user to enable if disabled

/// Get high-accuracy location (5 sec timeout)
Future<Position?> getHighAccuracyLocation({
  Duration timeout = const Duration(seconds: 5),
})
// Activates GPS with HIGH_ACCURACY mode
// Waits max 5 seconds for location fix
// Returns null if timeout/error
// GPS automatically turns off after capture

/// Reverse geocode coordinates to address
Future<String?> reverseGeocode(
  double latitude,
  double longitude,
)
// Converts (lat, lon) to readable address
// Example: "Delhi, India" or "Starbucks, Baga Beach, Goa"
// Called in batch after trip ends (not during transaction)

/// Calculate distance between two points
double calculateDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
)
// Returns distance in kilometers
// Useful for trip analytics

/// Batch geocode all trip expenses
Future<void> batchGeocodeTrip(String tripId)
// After trip ends, converts all coordinates to addresses
// Updates database with resolved addresses
// Respects API rate limits (500ms delay between calls)
```

#### Usage Example

```dart
class LocationDemo {
  final locationService = LocationService();

  void demo() async {
    // 1. Request permissions
    final hasPermission = 
      await locationService.requestLocationPermissions();
    if (!hasPermission) return;

    // 2. Check if GPS is enabled
    final enabled = 
      await locationService.isLocationServiceEnabled();
    if (!enabled) return;

    // 3. Capture location (triggered by SMS in production)
    final position = 
      await locationService.getHighAccuracyLocation();
    
    if (position != null) {
      print('Captured: ${position.latitude}, ${position.longitude}');

      // 4. Get address
      final address = await locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      print('Address: $address');

      // 5. Calculate distance from another point
      final distance = locationService.calculateDistance(
        position.latitude,
        position.longitude,
        28.6139,  // Delhi
        77.2090,
      );
      print('Distance from Delhi: ${distance.toStringAsFixed(2)} km');
    }

    // 6. After trip ends, batch geocode all expenses
    await locationService.batchGeocodeTrip('trip_123');
  }
}
```

---

### 3. DatabaseHelper

**Purpose**: SQLite database management for trips and expenses

#### Trip Operations

```dart
/// Create new trip
Future<String> createTrip(String tripName)
// Returns: tripId for future reference
// Example: await db.createTrip('Goa Vacation 2024')

/// Get all trips
Future<List<Trip>> getAllTrips()
// Returns: List sorted by start_time (newest first)

/// Get specific trip
Future<Trip?> getTrip(String tripId)
// Returns: Trip object or null if not found

/// Get currently active trip
Future<Trip?> getActiveTrip()
// Returns: First trip with is_active=1 or null

/// End a trip
Future<void> endTrip(String tripId)
// Sets is_active=0 and end_time=now()
// Call this when user stops tracking

/// Delete trip
Future<void> deleteTrip(String tripId)
// Deletes trip and all associated expenses
```

#### Expense Operations

```dart
/// Save new expense
Future<String> saveExpense(Transaction expense)
// Returns: expenseId
// Saves transaction with all details

/// Get trip expenses
Future<List<Transaction>> getTripExpenses(String tripId)
// Returns: All expenses for trip, ordered by time

/// Update expense
Future<void> updateExpense(Transaction expense)
// Modifies existing expense record

/// Update expense location
Future<void> updateExpenseLocation(
  String expenseId,
  double latitude,
  double longitude,
  String? address,
)
// Adds location info after GPS capture

/// Delete expense
Future<void> deleteExpense(String expenseId)

/// Get expenses without location
Future<List<Transaction>> getExpensesWithoutLocation(String tripId)
// Returns: Expenses still waiting for geocoding
// Used by batch geocoding process
```

#### Batch Operations

```dart
/// Bulk insert expenses
Future<void> saveExpenseBatch(List<Transaction> expenses)
// Insert multiple expenses in one transaction
// More efficient than individual saves
```

#### Analytics

```dart
/// Get total expense for trip
Future<double> getTotalExpenseForTrip(String tripId)
// Returns: Sum of all amounts

/// Get category breakdown
Future<Map<String, double>> getCategoryBreakdown(String tripId)
// Returns: {
//   "Food": 1500.00,
//   "Transport": 800.00,
//   "Stay": 3000.00,
//   "Shopping": 200.00,
// }

/// Get expense count
Future<int> getExpenseCount(String tripId)
// Returns: Number of transactions
```

#### Cleanup

```dart
/// Clear all data
Future<void> clearAllData()
// Deletes all trips and expenses

/// Close database
Future<void> closeDatabase()
// Call in app teardown
```

#### Usage Example

```dart
final db = DatabaseHelper();

// 1. Create trip
final tripId = await db.createTrip('Goa Vacation');
print('Trip created: $tripId');

// 2. Create transactions
final transaction1 = Transaction(
  tripId: tripId,
  amount: 500.0,
  merchantName: 'Starbucks',
  transactionTime: DateTime.now(),
  latitude: 15.4909,
  longitude: 73.8278,
  resolvedAddress: 'Baga Beach, Goa',
);

await db.saveExpense(transaction1);

// 3. Query trip data
final expenses = await db.getTripExpenses(tripId);
print('Expenses: ${expenses.length}');

// 4. Get analytics
final total = await db.getTotalExpenseForTrip(tripId);
final breakdown = await db.getCategoryBreakdown(tripId);
final count = await db.getExpenseCount(tripId);

print('Total: ₹$total');
print('Categories: $breakdown');
print('Count: $count');

// 5. End trip
await db.endTrip(tripId);
```

---

## Android Layer APIs (Method Channel)

### From Flutter to Android

```dart
const platform = MethodChannel('com.tracker.traveltracker/transaction');

// Start tracking
await platform.invokeMethod('startTracking');

// Stop tracking
await platform.invokeMethod('stopTracking');

// Check permissions
await platform.invokeMethod('checkPermissions');

// Get permission status
final status = await platform.invokeMethod('getPermissionStatus');
// Returns: {
//   'SMS_READ': true,
//   'LOCATION_FINE': true,
//   'LOCATION_COARSE': true,
//   'FOREGROUND_SERVICE': true,
// }
```

### From Android to Flutter

```dart
platform.setMethodCallHandler((call) async {
  if (call.method == 'onTransactionReceived') {
    final amount = call.arguments['amount'] as double;
    final merchant = call.arguments['merchant'] as String;
    final time = call.arguments['time'] as String;
    final rawSms = call.arguments['raw_sms'] as String;
    
    print('Transaction: $merchant ₹$amount');
  }
  
  if (call.method == 'onLocationCaptured') {
    final latitude = call.arguments['latitude'] as double;
    final longitude = call.arguments['longitude'] as double;
    final accuracy = call.arguments['accuracy'] as double;
    final timestamp = call.arguments['timestamp'] as int;
    
    print('Location: $latitude, $longitude (±${accuracy}m)');
  }
});
```

---

## Data Models

### Transaction

```dart
class Transaction {
  final String? id;
  final String tripId;
  final double amount;
  final String merchantName;
  final DateTime transactionTime;
  final double? latitude;
  final double? longitude;
  final String? resolvedAddress;
  final String? category;
  final String? rawSmsText;
  final String? upiVpa;
  final String? referenceNumber;
  final DateTime createdAt;
  
  // Methods
  Map<String, dynamic> toJson()
  factory Transaction.fromJson(Map<String, dynamic> json)
  Transaction copyWith({...})
}
```

### Trip

```dart
class Trip {
  final String? id;
  final String tripName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final List<Transaction> expenses;
  
  // Methods
  double getTotalExpense()
  Map<String, dynamic> toJson()
  factory Trip.fromJson(Map<String, dynamic> json)
}
```

### LocationData

```dart
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
}
```

### ParsedTransaction (Android)

```kotlin
data class ParsedTransaction(
    val amount: Double,
    val merchantName: String,
    val transactionTime: String,
    val upiVpa: String? = null,
    val referenceNumber: String? = null
)
```

---

## Error Handling

### GPS Errors

```dart
Future<void> safeLocationCapture() async {
  try {
    final position = 
      await locationService.getHighAccuracyLocation(
        timeout: Duration(seconds: 5),
      );

    if (position == null) {
      print('Location timeout or error');
      // Fallback: Use last known location or skip
      return;
    }

    // Success
    print('Location: ${position.latitude}');
  } catch (e) {
    print('Location error: $e');
  }
}
```

### Database Errors

```dart
Future<void> safeSaveTransaction(Transaction tx) async {
  try {
    await db.saveExpense(tx);
    print('Saved successfully');
  } catch (e) {
    print('Database error: $e');
    // Retry or notify user
  }
}
```

### SMS Parsing Errors

```kotlin
try {
  val transaction = SmsParser.parseTransaction(messageBody)
  if (transaction == null) {
    Log.d("SMS", "Not a transaction SMS")
    return
  }
  // Process transaction
} catch (e: Exception) {
  Log.e("SMS", "Parsing error: ${e.message}")
}
```

---

## Performance Tips

1. **Database Indexing**: Queries on trip_id and transaction_time are indexed
2. **Batch Operations**: Use `saveExpenseBatch()` for multiple transactions
3. **Batch Geocoding**: After trip ends, not during (prevents rate limiting)
4. **Location Timeout**: 5 seconds max prevents battery drain
5. **Stream Management**: Always call `dispose()` when leaving screen

---

## Security Considerations

1. **SMS Parsing**: Only extracts transaction keywords, filters system messages
2. **Location Privacy**: Coordinates stored locally, never auto-synced
3. **Permissions**: Requested at runtime with clear explanations
4. **SMS Access**: Limited to transaction detection, not storage
5. **Foreground Service**: Visible notification shows service is running

---

**API Documentation Complete!**