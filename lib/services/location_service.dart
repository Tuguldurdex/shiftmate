import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/shifts/domain/shift_model.dart';

class LocationService {
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      return null;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  bool isWithinRadius(Position current, WorkLocation workLocation) {
    final distance = calculateDistance(
      current.latitude,
      current.longitude,
      workLocation.latitude,
      workLocation.longitude,
    );
    return distance <= workLocation.radiusMeters;
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} м';
    }
    return '${(meters / 1000).toStringAsFixed(1)} км';
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final currentPositionProvider = FutureProvider<Position?>((ref) async {
  return ref.read(locationServiceProvider).getCurrentPosition();
});