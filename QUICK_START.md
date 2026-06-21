# Quick Start Guide - Travel Tracker

## 🚀 Get Running in 5 Minutes

### Prerequisites

- Flutter 3.0+
- Android SDK (API 21+)
- Android Device with Android 5.0+
- Google Play Services installed

### Installation

```bash
# 1. Clone repo
git clone <repo-url>
cd Tracker

# 2. Get dependencies
flutter pub get

# 3. Run the app
flutter run -v
```

### First Time Setup

When the app launches:
1. **Grant Permissions**
   - SMS permission (for detecting transactions)
   - Location permission (for GPS capture)
   - Foreground Service permission

2. **Create a Trip**
   - Tap "Start Trip"
   - Enter trip name: "My Vacation"
   - Tap "Start"

3. **Make a Transaction**
   - Use your UPI/Debit card anywhere
   - App automatically captures location
   - See transaction appear in list

---

## 📱 App Features Walkthrough

### Main Screen

```
┌────────────────────────────┐
│    Travel Tracker 🧭       │
├────────────────────────────┤
│  Goa Vacation 2024         │
│  ─────────────────────     │
│  Total: ₹5,234             │
│  Transactions: 12          │
│                            │
│  ┌──────────────────────┐  │
│  │ 🍽️  Starbucks       │  │
│  │     Baga Beach       │  │
│  │     ₹450             │  │
│  ├──────────────────────┤  │
│  │ 🚕  Uber            │  │
│  │     Panjim           │  │
│  │     ₹250             │  │
│  ├──────────────────────┤  │
│  │ 🏨  OYO Hotels      │  │
│  │     South Goa        │  │
│  │     ₹2,000           │  │
│  └──────────────────────┘  │
│                            │
│             [⏹️ Stop]       │
└────────────────────────────┘
```

### During Trip

- **Foreground Notification**: Shows "Trip Active 🧭 Tracking..."
- **Real-time Updates**: Transaction appears when SMS arrives
- **Location Auto-Capture**: GPS activates for 3-5 seconds per transaction
- **Battery Friendly**: Uses minimal battery (4-5% per 100 transactions)

### After Trip

- **Batch Geocoding**: Coordinates converted to addresses
- **Map View**: Visual timeline of all expenses on map
- **Analytics**: Spending breakdown by category

---

## 🔧 Development Workflow

### Adding a New Feature

1. **Modify Android Service** (if needed)
   ```
   android/app/src/main/kotlin/...
   └── Update SmsReceiver or TransactionListenerService
   ```

2. **Update Flutter Model** (if needed)
   ```
   lib/models/transaction_model.dart
   └── Add new fields to Transaction class
   ```

3. **Update Database** (if needed)
   ```
   lib/database/database_helper.dart
   └── Add new column to schema
   ```

4. **Update UI** (if needed)
   ```
   lib/ui/screens/home_screen.dart
   └── Update UI to show new data
   ```

5. **Test**
   ```bash
   flutter test
   flutter run
   ```

### Debugging

#### Check Android Logs
```bash
flutter logs
```

#### Test SMS Parsing
```dart
import 'package:travel_tracker/utils/regex_patterns.dart';

// Test HDFC SMS
final sms = "Dear Customer, Your A/C XXXXXXXX7890 debited with INR 500.00 at Starbucks on 21/06/2024 13:45";
// Use regex patterns to test extraction
```

#### Inspect Database
```bash
adb shell
cd /data/data/com.tracker.traveltracker/databases
sqlite3 travel_tracker.db
sqlite> SELECT * FROM trips;
sqlite> SELECT * FROM expenses;
```

#### Monitor GPS
```bash
# Simulate location in emulator
adb emu geo fix 15.4909 73.8278  # Baga Beach, Goa
```

#### Test Foreground Service
```bash
# Verify service running
adb shell dumpsys activity services
# Look for TransactionListenerService
```

---

## 🐛 Common Issues

| Issue | Fix |
|-------|-----|
| App crashes on launch | Check Flutter/Android version compatibility |
| SMS not detected | Enable SMS permission in system settings |
| Location not capturing | Enable location permission + GPS hardware |
| Addresses not showing | Wait for batch geocoding after trip ends |
| Battery draining fast | Ensure GPS stops after 5 seconds (check logs) |
| Foreground service killed | Ensure FOREGROUND_SERVICE permission granted |

---

## 📊 Testing Checklist

- [ ] Permissions requested on first launch
- [ ] Trip can be created/started
- [ ] Foreground service notification appears
- [ ] SMS received triggers location capture
- [ ] Transaction appears in list with location
- [ ] Trip can be ended
- [ ] Database saves all data
- [ ] Batch geocoding works after trip ends
- [ ] Map shows all expense locations
- [ ] Analytics calculations are correct

---

## 📚 File Reference

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies |
| `lib/main.dart` | App entry point |
| `lib/ui/screens/home_screen.dart` | Main UI |
| `lib/services/transaction_service.dart` | SMS ↔ Flutter bridge |
| `lib/services/location_service.dart` | GPS + geocoding |
| `lib/database/database_helper.dart` | SQLite management |
| `android/app/src/main/AndroidManifest.xml` | Permissions |
| `android/app/src/.../MainActivity.kt` | Activity + Method Channel |
| `android/app/src/.../SmsReceiver.kt` | SMS interception |
| `android/app/src/.../TransactionListenerService.kt` | Foreground service |
| `android/app/src/.../SmsParser.kt` | Regex parsing |

---

## 🎯 Next Steps

1. Run `flutter run` to launch the app
2. Grant all permissions
3. Create a test trip
4. Make a transaction to test SMS detection
5. End trip and view results
6. Check logs for any issues

---

**Happy coding! 🚀**