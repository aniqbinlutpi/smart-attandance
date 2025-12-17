import 'package:geolocator/geolocator.dart';

/// Service for handling location and geo-fencing
/// Manages GPS location and validates if user is within office radius
class LocationService {
  // ============================================
  // CONFIGURATION - UPDATE THESE VALUES!
  // ============================================

  /// Office coordinates
  /// TODO: Update with your actual office coordinates for production
  /// Currently set to: Home (Kampung Kerasak area) for testing
  static const double officeLat = 3.0439774709176737; // Approximate lat from screenshot
  static const double officeLng = 101.70637935352624; // Approximate lng from screenshot

  /// Allowed radius in meters
  /// Users must be within this distance to clock in/out
  /// Set to 500m for testing flexibility, reduce to 100m for production
  static const double allowedRadius = 500.0; // 500 meters for testing

  // ============================================
  // LOCATION SERVICES
  // ============================================

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location permission status
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current GPS location
  /// Throws exception if location services are disabled or permission denied
  static Future<Position> getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
          'Location services are disabled. Please enable GPS in your device settings.');
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Please enable in settings.');
    }

    // Get current position with high accuracy
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Calculate distance between two coordinates in meters
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Check if current location is within office radius
  /// Returns true if user is within allowed radius
  static Future<bool> isWithinOfficeRadius() async {
    try {
      final position = await getCurrentLocation();
      final distance = calculateDistance(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );
      return distance <= allowedRadius;
    } catch (e) {
      // If we can't get location, return false
      return false;
    }
  }

  /// Get distance from office in meters
  /// Returns null if location cannot be obtained
  static Future<double?> getDistanceFromOffice() async {
    try {
      final position = await getCurrentLocation();
      return calculateDistance(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if location is mocked (fake GPS)
  /// Returns true if location is from a mock provider
  static Future<bool> isMockLocation() async {
    try {
      final position = await getCurrentLocation();
      return position.isMocked;
    } catch (e) {
      return false;
    }
  }

  /// Format location as string
  /// Returns "latitude, longitude" format
  static String formatLocation(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  /// Format distance in user-friendly format
  /// Returns "50m" or "1.2km"
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Get detailed location validation result
  /// Returns a map with validation status and details
  static Future<Map<String, dynamic>> validateLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'valid': false,
          'error': 'location_disabled',
          'message':
              'Location services are disabled. Please enable GPS in your device settings.',
        };
      }

      // Get current location
      final position = await getCurrentLocation();

      // Check if location is mocked
      if (position.isMocked) {
        return {
          'valid': false,
          'error': 'mock_location',
          'message':
              'Mock location detected. Please disable fake GPS apps and try again.',
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }

      // Calculate distance from office
      final distance = calculateDistance(
        officeLat,
        officeLng,
        position.latitude,
        position.longitude,
      );

      // Check if within radius
      final withinRadius = distance <= allowedRadius;

      if (withinRadius) {
        return {
          'valid': true,
          'distance': distance,
          'distanceFormatted': formatDistance(distance),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'message': 'Location verified. You are at the office.',
        };
      } else {
        return {
          'valid': false,
          'error': 'outside_radius',
          'distance': distance,
          'distanceFormatted': formatDistance(distance),
          'latitude': position.latitude,
          'longitude': position.longitude,
          'message':
              'You are ${formatDistance(distance)} away from the office. You must be within ${formatDistance(allowedRadius)} to clock in/out.',
        };
      }
    } catch (e) {
      return {
        'valid': false,
        'error': 'unknown',
        'message': 'Failed to get location: ${e.toString()}',
      };
    }
  }

  /// Get office location as Position object
  static Position getOfficeLocation() {
    return Position(
      latitude: officeLat,
      longitude: officeLng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  /// Get location permission status message
  static String getPermissionStatusMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return 'Location permission granted (always)';
      case LocationPermission.whileInUse:
        return 'Location permission granted (while in use)';
      case LocationPermission.denied:
        return 'Location permission denied';
      case LocationPermission.deniedForever:
        return 'Location permission permanently denied';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location permission';
    }
  }
}
