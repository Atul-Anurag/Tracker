import 'dart:async';
import 'package:flutter/services.dart';
import 'package:travel_tracker/database/database_helper.dart';
import 'package:travel_tracker/models/transaction_model.dart';
import 'package:travel_tracker/services/location_service.dart';

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();

  factory TransactionService() {
    return _instance;
  }

  TransactionService._internal();

  static const platform = MethodChannel('com.tracker.traveltracker/transaction');

  final _db = DatabaseHelper();
  final _locationService = LocationService();
  
  StreamController<Transaction>? _transactionController;
  StreamController<LocationData>? _locationController;

  Stream<Transaction> get transactionStream {
    _transactionController ??= StreamController<Transaction>.broadcast(
      onListen: _setupTransactionListener,
      onCancel: _cancelTransactionListener,
    );
    return _transactionController!.stream;
  }

  Stream<LocationData> get locationStream {
    _locationController ??= StreamController<LocationData>.broadcast(
      onListen: _setupLocationListener,
      onCancel: _cancelLocationListener,
    );
    return _locationController!.stream;
  }

  void _setupTransactionListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onTransactionReceived') {
        final args = call.arguments as Map;
        print('Transaction received: ${args['merchant']} - ₹${args['amount']}');
        
        _transactionController?.add(Transaction(
          tripId: '', // Will be set by caller
          amount: (args['amount'] as num).toDouble(),
          merchantName: args['merchant'] ?? 'Unknown',
          transactionTime: DateTime.now(),
          rawSmsText: args['raw_sms'],
        ));
      }
    });
  }

  void _setupLocationListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onLocationCaptured') {
        final args = call.arguments as Map;
        _locationController?.add(LocationData(
          latitude: (args['latitude'] as num).toDouble(),
          longitude: (args['longitude'] as num).toDouble(),
          accuracy: (args['accuracy'] as num).toDouble(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (args['timestamp'] as num).toInt(),
          ),
        ));
      }
    });
  }

  void _cancelTransactionListener() {
    _transactionController?.close();
    _transactionController = null;
  }

  void _cancelLocationListener() {
    _locationController?.close();
    _locationController = null;
  }

  /// Start tracking transactions and locations
  Future<void> startTracking() async {
    try {
      await platform.invokeMethod('startTracking');
      print('✓ Tracking started');
    } catch (e) {
      print('✗ Error starting tracking: $e');
    }
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    try {
      await platform.invokeMethod('stopTracking');
      print('✓ Tracking stopped');
    } catch (e) {
      print('✗ Error stopping tracking: $e');
    }
  }

  /// Check and request permissions
  Future<void> checkPermissions() async {
    try {
      await platform.invokeMethod('checkPermissions');
      print('✓ Permissions checked');
    } catch (e) {
      print('✗ Error checking permissions: $e');
    }
  }

  /// Save transaction with location to database
  Future<void> saveTransactionWithLocation(
    Transaction transaction,
    double latitude,
    double longitude,
  ) async {
    try {
      final updatedTransaction = transaction.copyWith(
        latitude: latitude,
        longitude: longitude,
      );

      await _db.saveExpense(updatedTransaction);
      print('✓ Transaction saved: ${updatedTransaction.merchantName}');
    } catch (e) {
      print('✗ Error saving transaction: $e');
    }
  }

  /// Get all transactions for a trip
  Future<List<Transaction>> getTransactions(String tripId) async {
    return await _db.getTripExpenses(tripId);
  }

  /// Clean up resources
  void dispose() {
    _transactionController?.close();
    _locationController?.close();
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() => 'LocationData($latitude, $longitude, accuracy: $accuracy)';
}
