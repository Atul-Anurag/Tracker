import 'package:intl/intl.dart';

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

  Transaction({
    this.id,
    required this.tripId,
    required this.amount,
    required this.merchantName,
    required this.transactionTime,
    this.latitude,
    this.longitude,
    this.resolvedAddress,
    this.category,
    this.rawSmsText,
    this.upiVpa,
    this.referenceNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'amount': amount,
      'merchant_name': merchantName,
      'transaction_time': transactionTime.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'resolved_address': resolvedAddress,
      'category': category,
      'raw_sms_text': rawSmsText,
      'upi_vpa': upiVpa,
      'reference_number': referenceNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString(),
      tripId: json['trip_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchantName: json['merchant_name']?.toString() ?? 'Unknown',
      transactionTime: DateTime.parse(json['transaction_time']?.toString() ?? DateTime.now().toIso8601String()),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      resolvedAddress: json['resolved_address']?.toString(),
      category: json['category']?.toString(),
      rawSmsText: json['raw_sms_text']?.toString(),
      upiVpa: json['upi_vpa']?.toString(),
      referenceNumber: json['reference_number']?.toString(),
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  /// Create a copy with updated fields
  Transaction copyWith({
    String? id,
    String? tripId,
    double? amount,
    String? merchantName,
    DateTime? transactionTime,
    double? latitude,
    double? longitude,
    String? resolvedAddress,
    String? category,
    String? rawSmsText,
    String? upiVpa,
    String? referenceNumber,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      transactionTime: transactionTime ?? this.transactionTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      resolvedAddress: resolvedAddress ?? this.resolvedAddress,
      category: category ?? this.category,
      rawSmsText: rawSmsText ?? this.rawSmsText,
      upiVpa: upiVpa ?? this.upiVpa,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, amount: ₹$amount, merchant: $merchantName, time: ${DateFormat('dd/MM/yyyy HH:mm').format(transactionTime)}, location: ($latitude, $longitude))';
  }
}

class Trip {
  final String? id;
  final String tripName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final List<Transaction> expenses;

  Trip({
    this.id,
    required this.tripName,
    DateTime? startTime,
    this.endTime,
    this.isActive = true,
    this.expenses = const [],
  }) : startTime = startTime ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_name': tripName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString(),
      tripName: json['trip_name']?.toString() ?? 'Unnamed Trip',
      startTime: DateTime.parse(json['start_time']?.toString() ?? DateTime.now().toIso8601String()),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']?.toString() ?? '') : null,
      isActive: (json['is_active'] as num?)?.toInt() == 1 ?? true,
    );
  }

  double getTotalExpense() {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }
}
