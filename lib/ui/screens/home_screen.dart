import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travel_tracker/database/database_helper.dart';
import 'package:travel_tracker/models/transaction_model.dart';
import 'package:travel_tracker/services/location_service.dart';
import 'package:travel_tracker/services/transaction_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper();
  final _locationService = LocationService();
  late TransactionService _transactionService;

  Trip? _activeTrip;
  List<Transaction> _transactions = [];
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _transactionService = context.read<TransactionService>();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request permissions
    await _transactionService.checkPermissions();
    await _locationService.requestLocationPermissions();

    // Load active trip
    _loadActiveTrip();

    // Set up listeners
    _transactionService.transactionStream.listen((transaction) {
      _handleNewTransaction(transaction);
    });

    _transactionService.locationStream.listen((location) {
      _handleNewLocation(location);
    });
  }

  Future<void> _loadActiveTrip() async {
    final trip = await _db.getActiveTrip();
    if (mounted) {
      setState(() => _activeTrip = trip);
      if (trip != null) {
        _loadTransactions(trip.id ?? '');
      }
    }
  }

  Future<void> _loadTransactions(String tripId) async {
    final transactions = await _db.getTripExpenses(tripId);
    if (mounted) {
      setState(() => _transactions = transactions);
    }
  }

  Future<void> _handleNewTransaction(Transaction transaction) async {
    if (_activeTrip == null) return;

    // Capture location immediately
    final location = await _locationService.getHighAccuracyLocation();

    if (location != null) {
      final transactionWithLocation = transaction.copyWith(
        tripId: _activeTrip!.id ?? '',
        latitude: location.latitude,
        longitude: location.longitude,
      );

      await _db.saveExpense(transactionWithLocation);
      await _loadTransactions(_activeTrip!.id ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${transaction.merchantName}: ₹${transaction.amount}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleNewLocation(LocationData location) {
    print('Location update: ${location.latitude}, ${location.longitude}');
  }

  Future<void> _startTrip() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Trip'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Trip name (e.g., Goa Vacation)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final tripId = await _db.createTrip(nameController.text);
                _activeTrip = await _db.getTrip(tripId);
                await _transactionService.startTracking();

                if (mounted) {
                  setState(() => _isTracking = true);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _endTrip() async {
    if (_activeTrip == null) return;

    await _transactionService.stopTracking();
    await _db.endTrip(_activeTrip!.id ?? '');

    // Batch geocode all expenses
    await _locationService.batchGeocodeTrip(_activeTrip!.id ?? '');

    if (mounted) {
      setState(() {
        _isTracking = false;
        _activeTrip = null;
      });
    }
  }

  @override
  void dispose() {
    _transactionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Tracker 🧭'),
        elevation: 0,
      ),
      body: _activeTrip == null ? _buildNoCapsule() : _buildTripView(),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildNoCapsule() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No active trip',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start a trip to begin tracking your expenses and locations',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _startTrip,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Trip'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripView() {
    final total = _transactions.fold<double>(0, (sum, t) => sum + t.amount);

    return Column(
      children: [
        // Trip header
        Container(
          color: Colors.blue.shade50,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeTrip!.tripName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Spent', style: TextStyle(color: Colors.grey)),
                      Text(
                        '₹${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Transactions', style: TextStyle(color: Colors.grey)),
                      Text(
                        '${_transactions.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Transactions list
        Expanded(
          child: _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No transactions yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = _transactions[index];
                    return ListTile(
                      leading: Icon(
                        _getCategoryIcon(transaction.category),
                        color: Colors.blue,
                      ),
                      title: Text(transaction.merchantName),
                      subtitle: Text(transaction.resolvedAddress ?? 'Capturing location...'),
                      trailing: Text(
                        '₹${transaction.amount}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFab() {
    if (_activeTrip == null) {
      return FloatingActionButton(
        onPressed: _startTrip,
        child: const Icon(Icons.add),
      );
    } else {
      return FloatingActionButton(
        onPressed: _endTrip,
        backgroundColor: Colors.red,
        child: const Icon(Icons.stop),
      );
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'stay':
        return Icons.hotel;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.attach_money;
    }
  }
}
