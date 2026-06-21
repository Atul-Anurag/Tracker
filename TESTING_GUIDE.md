# Testing & Debugging Guide - Travel Tracker

## 🧪 Testing Strategy

### 1. Unit Testing (SMS Parsing)

#### Test the Regex Patterns

**File to test**: `lib/utils/regex_patterns.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_tracker/utils/regex_patterns.dart';

void main() {
  group('IndianBankRegexPatterns', () {
    test('Extract HDFC amount correctly', () {
      final pattern = RegExp(IndianBankRegexPatterns.hdfcPattern);
      const sms = "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45";
      
      final match = pattern.firstMatch(sms);
      expect(match, isNotNull);
      expect(match?.group(1), contains('500.00'));
    });

    test('Extract merchant name correctly', () {
      final pattern = RegExp(IndianBankRegexPatterns.merchantPattern);
      const sms = "at Starbucks Coffee on 21/06/2024";
      
      final match = pattern.firstMatch(sms);
      expect(match, isNotNull);
      expect(match?.group(1)?.trim(), equals('Starbucks Coffee'));
    });

    test('Extract amount with ₹ symbol', () {
      final pattern = RegExp(IndianBankRegexPatterns.amountPattern);
      const sms = "debited ₹ 1,500.50 at Amazon";
      
      final match = pattern.firstMatch(sms);
      expect(match, isNotNull);
      expect(match?.group(1), contains('1,500.50'));
    });
  });
}
```

**Run tests**:
```bash
flutter test
```

### 2. Integration Testing (Android SMS Interception)

#### Test SMS Receiver

**Simulate SMS on Android Emulator**:

```bash
# Option 1: Using Android Emulator console
telnet localhost 5554
sms send 1234567890 "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45"

# Option 2: Using adb
adb shell am broadcast -a android.provider.Telephony.SMS_RECEIVED \
  --es pdus "00010102..." \
  -n com.android.phone/com.tracker.traveltracker.receivers.SmsReceiver
```

**Expected Result**:
- SMS received notification
- Transaction appears in app list
- Location capture triggered in logs

### 3. Functional Testing (End-to-End)

#### Test Scenario 1: Complete Trip

1. **Open app**
   - ✓ Permissions dialog appears
   - ✓ Grant all permissions

2. **Start trip**
   - ✓ Tap "Start Trip"
   - ✓ Enter trip name
   - ✓ Tap "Start"
   - ✓ Foreground service notification appears

3. **Simulate transaction**
   - ✓ Send SMS via emulator console
   - ✓ App detects transaction
   - ✓ Location appears in list

4. **End trip**
   - ✓ Tap red "Stop" button
   - ✓ Foreground service stops
   - ✓ Batch geocoding processes

5. **Verify database**
   - ✓ Trip marked as ended
   - ✓ All expenses saved
   - ✓ Addresses resolved

---

## 🐛 Debugging Checklist

### Android Service Issues

#### Problem: Service crashes on startup

**Debug steps**:
```bash
# Check logs
flutter logs

# Look for errors like:
# - "Unable to start service"
# - "NotificationManager error"
# - "Permission denied"

# Check manifest
cat android/app/src/main/AndroidManifest.xml
# Verify: <service android:name=".services.TransactionListenerService" />
```

#### Problem: SMS not detected

**Debug steps**:
```bash
# Check SMS receiver registration
adb shell dumpsys activity receivers | grep SmsReceiver

# Expected output:
# android.provider.Telephony.SMS_RECEIVED ...
#   com.tracker.traveltracker.receivers.SmsReceiver

# If not found, verify AndroidManifest.xml:
# <receiver android:name=".receivers.SmsReceiver"
#     android:permission="android.permission.RECEIVE_SMS">
#   <intent-filter>
#     <action android:name="android.provider.Telephony.SMS_RECEIVED" />
#   </intent-filter>
# </receiver>
```

#### Problem: GPS not capturing

**Debug steps**:
```bash
# Enable location simulation in emulator
# In Android Studio: Extended controls → Location
# Set: Latitude 15.4909, Longitude 73.8278

# Check location permissions
adb shell dumpsys package com.tracker.traveltracker | grep PERMISSION

# Should show:
# android.permission.ACCESS_FINE_LOCATION
# android.permission.ACCESS_BACKGROUND_LOCATION

# If missing, re-grant in settings
adb shell pm grant com.tracker.traveltracker android.permission.ACCESS_FINE_LOCATION
```

---

## 🔍 Log Analysis

### Important Log Tags

```bash
flutter logs --tag "MainActivity"        # Main activity logs
flutter logs --tag "SmsReceiver"         # SMS reception
flutter logs --tag "SmsParser"           # SMS parsing
flutter logs --tag "TransactionListenerService"  # GPS capture
flutter logs --tag "DatabaseHelper"      # Database operations
```

### Sample Log Output

```
I/TransactionListenerService: Service Created
I/TransactionListenerService: Foreground Service Started
I/SmsReceiver: SMS Received from: +919876543210
I/SmsReceiver: Message: Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks...
I/SmsParser: Transaction parsed: amount=500.0, merchant=Starbucks
I/SmsReceiver: Location capture triggered
I/TransactionListenerService: Starting location capture...
I/TransactionListenerService: Got location: 15.4909, 73.8278
I/TransactionListenerService: Location updates stopped - GPS OFF
I/LocationService: Location captured and saved
I/HomeScreen: Transaction received: Starbucks - ₹500
```

---

## 📊 Database Inspection

### Access SQLite Database

```bash
# Connect to device
adb shell

# Navigate to app database
cd /data/data/com.tracker.traveltracker/databases
ls -la

# Open SQLite shell
sqlite3 travel_tracker.db

# Common queries
sqlite> SELECT * FROM trips;
sqlite> SELECT * FROM expenses;
sqlite> SELECT * FROM expenses WHERE trip_id = 'trip_123';
sqlite> SELECT COUNT(*) FROM expenses;
sqlite> SELECT SUM(amount) FROM expenses WHERE trip_id = 'trip_123';

# Export data
sqlite> .mode csv
sqlite> .output expenses.csv
sqlite> SELECT * FROM expenses;
sqlite> .quit
```

---

## 🧪 Mock Testing

### Mock SMS for Testing

Create `test_sms_helper.dart`:

```dart
import 'package:travel_tracker/utils/regex_patterns.dart';

class TestSmsHelper {
  static const String HDFC_SMS = 
    "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45 IST";
  
  static const String ICICI_SMS = 
    "Dear Customer, Your a/c XXXXXXXX7890 was debited for INR 250.00 at Amazon on 21/06/2024 13:45:30";
  
  static const String SBI_SMS = 
    "INR 300.00 debited towards Flipkart on 21/06/2024 13:45";
  
  static const String AXIS_SMS = 
    "Your account XXXXXXXX7890 was debited by INR 150.00 at BigBasket on 21/06/2024 13:45";
  
  static const String UPI_SMS = 
    "Alert: UPI/NEFT transaction of INR 2,000 to abc123@upi on 21/06/2024 14:30 Ref: TX123456789";
  
  static void runTests() {
    testHdfc();
    testIcici();
    testSbi();
    testAxis();
    testUpi();
  }
  
  static void testHdfc() {
    print('Testing HDFC...');
    final pattern = RegExp(IndianBankRegexPatterns.hdfcPattern);
    final match = pattern.firstMatch(HDFC_SMS);
    
    if (match != null) {
      print('✓ HDFC matched');
      print('  Amount: ${match.group(1)}');
      print('  Merchant: ${match.group(2)}');
      print('  Time: ${match.group(3)}');
    } else {
      print('✗ HDFC failed to match');
    }
  }
  
  static void testIcici() {
    print('Testing ICICI...');
    final pattern = RegExp(IndianBankRegexPatterns.iciciBankPattern);
    final match = pattern.firstMatch(ICICI_SMS);
    
    if (match != null) {
      print('✓ ICICI matched');
      print('  Amount: ${match.group(1)}');
    } else {
      print('✗ ICICI failed to match');
    }
  }
  
  static void testSbi() {
    print('Testing SBI...');
    final pattern = RegExp(IndianBankRegexPatterns.sbiPattern);
    final match = pattern.firstMatch(SBI_SMS);
    
    if (match != null) {
      print('✓ SBI matched');
    } else {
      print('✗ SBI failed to match');
    }
  }
  
  static void testAxis() {
    print('Testing AXIS...');
    final pattern = RegExp(IndianBankRegexPatterns.axisPattern);
    final match = pattern.firstMatch(AXIS_SMS);
    
    if (match != null) {
      print('✓ AXIS matched');
    } else {
      print('✗ AXIS failed to match');
    }
  }
  
  static void testUpi() {
    print('Testing UPI...');
    final pattern = RegExp(IndianBankRegexPatterns.upiPattern);
    final match = pattern.firstMatch(UPI_SMS);
    
    if (match != null) {
      print('✓ UPI matched');
    } else {
      print('✗ UPI failed to match');
    }
  }
}

// Usage in main.dart for quick testing
void main() async {
  TestSmsHelper.runTests();
  runApp(const TravelTrackerApp());
}
```

---

## 🔧 Performance Profiling

### Monitor Battery Drain

```bash
# Enable battery statistics
adb shell dumpsys batterystats

# Clear existing stats
adb shell dumpsys batterystats --reset

# Run app for 30 minutes
# Make 10 transactions

# Dump stats again
adb shell dumpsys batterystats > battery_stats.txt

# Analyze CPU/wake locks related to GPS
grep -i "gps\|location\|foreground" battery_stats.txt
```

### Monitor Memory

```bash
# Enable memory profiling in Android Studio
# Device → Android Studio → Profiler

# Look for:
# - Memory spikes during GPS capture
# - Foreground service memory usage
# - Database connection leaks
```

---

## ✅ Pre-Release Checklist

- [ ] All unit tests passing
- [ ] SMS parsing works for all 7 banks
- [ ] GPS activates and deactivates correctly
- [ ] Database saves/retrieves data correctly
- [ ] Foreground service notification visible
- [ ] Permissions requested and granted
- [ ] No crashes in logs after 1 hour of testing
- [ ] Battery drain < 5% per 100 transactions
- [ ] Batch geocoding completes after trip ends
- [ ] Map displays all transactions correctly

---

## 🚨 Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `NotificationManager not initialized` | Service created before notification manager | Initialize in `onCreate()` before `startForeground()` |
| `Permission denied for SMS_RECEIVE` | Permission not granted | Re-request in settings or grant via adb |
| `Location timeout` | GPS not available | Enable location in emulator extended controls |
| `Database locked` | Concurrent access | Ensure only one thread accesses DB |
| `Method not found: onTransactionReceived` | Flutter method handler not set | Call `setMethodCallHandler()` in `configureFlutterEngine()` |

---

## 📝 Testing Report Template

```markdown
## Test Run: [Date] [Device]

### Device Info
- Model: [Model name]
- OS: Android [Version]
- RAM: [RAM size]
- Battery: [Start] → [End]

### Test Results
- [ ] Service startup: PASS/FAIL
- [ ] SMS detection: PASS/FAIL  
- [ ] GPS capture: PASS/FAIL
- [ ] Database save: PASS/FAIL
- [ ] UI update: PASS/FAIL
- [ ] Trip end: PASS/FAIL
- [ ] Geocoding: PASS/FAIL

### Issues Found
- [Issue 1]: [Description] [Status: Fixed/Pending]
- [Issue 2]: [Description] [Status: Fixed/Pending]

### Battery Impact
- Start: [%]
- End: [%]
- Drain: [%]
- Transactions: [#]
- Avg: [%] per transaction

### Performance
- Memory peak: [MB]
- Service CPU: [%]
- GPS activation time: [ms]

### Notes
[Any observations]
```

---

## 🎯 Ready for Production?

Before deploying to Play Store:

✅ Test on 5+ devices (different Android versions)
✅ Test with real SMS from banks (not simulated)
✅ Test for 24+ hours continuous
✅ Verify battery impact acceptable
✅ Check crash/ANR reports in Play Console beta
✅ Get privacy policy approved
✅ Configure signing certificate
✅ Set app category and content rating

---

**Happy Testing! 🚀**