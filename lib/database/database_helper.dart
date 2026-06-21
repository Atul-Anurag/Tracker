import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:travel_tracker/models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'travel_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create trips table
    await db.execute('''
      CREATE TABLE trips (
        trip_id TEXT PRIMARY KEY,
        trip_name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create expenses table
    await db.execute('''
      CREATE TABLE expenses (
        expense_id TEXT PRIMARY KEY,
        trip_id TEXT NOT NULL,
        amount REAL NOT NULL,
        merchant_name TEXT,
        transaction_time TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        resolved_address TEXT,
        category TEXT,
        raw_sms_text TEXT,
        upi_vpa TEXT,
        reference_number TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(trip_id) REFERENCES trips(trip_id)
      )
    ''');

    // Create index for faster queries
    await db.execute(
      'CREATE INDEX idx_expenses_trip_id ON expenses(trip_id)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_time ON expenses(transaction_time)',
    );
  }

  // ==================== TRIP OPERATIONS ====================

  Future<String> createTrip(String tripName) async {
    final db = await database;
    final tripId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await db.insert('trips', {
      'trip_id': tripId,
      'trip_name': tripName,
      'start_time': DateTime.now().toIso8601String(),
      'is_active': 1,
    });

    return tripId;
  }

  Future<List<Trip>> getAllTrips() async {
    final db = await database;
    final result = await db.query('trips', orderBy: 'start_time DESC');
    
    return result.map((trip) => Trip.fromJson(trip)).toList();
  }

  Future<Trip?> getTrip(String tripId) async {
    final db = await database;
    final result = await db.query(
      'trips',
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );

    if (result.isEmpty) return null;
    return Trip.fromJson(result.first);
  }

  Future<Trip?> getActiveTrip() async {
    final db = await database;
    final result = await db.query(
      'trips',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Trip.fromJson(result.first);
  }

  Future<void> endTrip(String tripId) async {
    final db = await database;
    await db.update(
      'trips',
      {
        'end_time': DateTime.now().toIso8601String(),
        'is_active': 0,
      },
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
  }

  // ==================== EXPENSE OPERATIONS ====================

  Future<String> saveExpense(Transaction expense) async {
    final db = await database;
    final expenseId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await db.insert('expenses', {
      'expense_id': expenseId,
      ...expense.toJson(),
      'expense_id': expenseId,
    });

    return expenseId;
  }

  Future<List<Transaction>> getTripExpenses(String tripId) async {
    final db = await database;
    final result = await db.query(
      'expenses',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'transaction_time DESC',
    );

    return result.map((exp) => Transaction.fromJson(exp)).toList();
  }

  Future<void> updateExpense(Transaction expense) async {
    final db = await database;
    await db.update(
      'expenses',
      expense.toJson(),
      where: 'expense_id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> updateExpenseLocation(
    String expenseId,
    double latitude,
    double longitude,
    String? address,
  ) async {
    final db = await database;
    await db.update(
      'expenses',
      {
        'latitude': latitude,
        'longitude': longitude,
        'resolved_address': address,
      },
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  Future<void> deleteExpense(String expenseId) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  Future<List<Transaction>> getExpensesWithoutLocation(String tripId) async {
    final db = await database;
    final result = await db.query(
      'expenses',
      where: 'trip_id = ? AND latitude IS NULL',
      whereArgs: [tripId],
    );

    return result.map((exp) => Transaction.fromJson(exp)).toList();
  }

  // ==================== BATCH OPERATIONS ====================

  Future<void> saveExpenseBatch(List<Transaction> expenses) async {
    final db = await database;
    final batch = db.batch();

    for (final expense in expenses) {
      final expenseId = DateTime.now().millisecondsSinceEpoch.toString();
      batch.insert('expenses', {
        'expense_id': expenseId,
        ...expense.toJson(),
      });
    }

    await batch.commit();
  }

  // ==================== ANALYTICS ====================

  Future<double> getTotalExpenseForTrip(String tripId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE trip_id = ?',
      [tripId],
    );

    if (result.isEmpty) return 0.0;
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getCategoryBreakdown(String tripId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM expenses WHERE trip_id = ? GROUP BY category',
      [tripId],
    );

    final breakdown = <String, double>{};
    for (final row in result) {
      final category = row['category']?.toString() ?? 'Uncategorized';
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      breakdown[category] = total;
    }

    return breakdown;
  }

  Future<int> getExpenseCount(String tripId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE trip_id = ?',
      [tripId],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  // ==================== CLEANUP ====================

  Future<void> deleteTrip(String tripId) async {
    final db = await database;
    // Delete expenses first (foreign key constraint)
    await db.delete('expenses', where: 'trip_id = ?', whereArgs: [tripId]);
    // Then delete trip
    await db.delete('trips', where: 'trip_id = ?', whereArgs: [tripId]);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('trips');
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }
}
