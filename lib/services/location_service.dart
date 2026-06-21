import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:travel_tracker/database/database_helper.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  final _db = DatabaseHelper();

  /// Request location permissions
  Future<bool> requestLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location with high accuracy
  /// This is called only when SMS transaction is detected
  Future<Position?> getHighAccuracyLocation({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      // Enable location service if available
      if (!await isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        return null;
      }

      // Request location with HIGH accuracy and timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: timeout,
      ).timeout(
        timeout,
        onTimeout: () => null,
      );

      if (position != null) {
        print('✓ Location captured: ${position.latitude}, ${position.longitude}');
      }

      return position;
    } catch (e) {
      print('✗ Error getting location: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to address
  /// Called in batch after trip ends (not during transaction)
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return _formatAddress(place);
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }

    return null;
  }

  /// Format placemark into readable address
  String _formatAddress(Placemark place) {
    final parts = <String>[];

    if (place.name != null && place.name!.isNotEmpty) parts.add(place.name!);
    if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
    if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.postalCode != null && place.postalCode!.isNotEmpty) parts.add(place.postalCode!);

    return parts.join(', ');
  }

  /// Calculate distance between two coordinates (in km)
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Batch geocode all expenses in a trip (call after trip ends)
  Future<void> batchGeocodeTrip(String tripId) async {
    try {
      final expenses = await _db.getExpensesWithoutLocation(tripId);

      for (final expense in expenses) {
        if (expense.latitude != null && expense.longitude != null) {
          final address = await reverseGeocode(
            expense.latitude!,
            expense.longitude!,
          );

          await _db.updateExpenseLocation(
            expense.id ?? '',
            expense.latitude!,
            expense.longitude!,
            address,
          );

          // Add delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      print('✓ Batch geocoding completed for trip: $tripId');
    } catch (e) {
      print('✗ Error batch geocoding: $e');
    }
  }
}
