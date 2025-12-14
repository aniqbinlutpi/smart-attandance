import 'package:permission_handler/permission_handler.dart';

/// Service for handling app permissions
/// Manages camera and location permissions required for face recognition
class PermissionService {
  /// Request camera permission
  /// Returns true if permission is granted
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request location permission
  /// Returns true if permission is granted
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Request both camera and location permissions
  /// Returns true only if both are granted
  static Future<bool> requestAllPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;

    return cameraGranted && locationGranted;
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    final camera = await Permission.camera.status;
    final location = await Permission.location.status;
    return camera.isGranted && location.isGranted;
  }

  /// Check camera permission status
  static Future<PermissionStatus> getCameraPermissionStatus() async {
    return await Permission.camera.status;
  }

  /// Check location permission status
  static Future<PermissionStatus> getLocationPermissionStatus() async {
    return await Permission.location.status;
  }

  /// Open app settings
  /// Useful when user has permanently denied permissions
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Check if camera permission is permanently denied
  static Future<bool> isCameraPermissionPermanentlyDenied() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  /// Check if location permission is permanently denied
  static Future<bool> isLocationPermissionPermanentlyDenied() async {
    final status = await Permission.location.status;
    return status.isPermanentlyDenied;
  }

  /// Get user-friendly permission status message
  static String getPermissionStatusMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Permission granted';
      case PermissionStatus.denied:
        return 'Permission denied. Please grant permission to continue.';
      case PermissionStatus.permanentlyDenied:
        return 'Permission permanently denied. Please enable in settings.';
      case PermissionStatus.restricted:
        return 'Permission restricted by system.';
      case PermissionStatus.limited:
        return 'Permission granted with limitations.';
      case PermissionStatus.provisional:
        return 'Permission granted provisionally.';
    }
  }

  /// Request permission with user-friendly error handling
  /// Returns a map with success status and optional error message
  static Future<Map<String, dynamic>> requestCameraWithFeedback() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return {'success': true, 'message': 'Camera permission granted'};
    } else if (status.isPermanentlyDenied) {
      return {
        'success': false,
        'message':
            'Camera permission permanently denied. Please enable in settings.',
        'openSettings': true,
      };
    } else {
      return {
        'success': false,
        'message': 'Camera permission is required for face recognition.',
      };
    }
  }

  /// Request location permission with user-friendly error handling
  static Future<Map<String, dynamic>> requestLocationWithFeedback() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      return {'success': true, 'message': 'Location permission granted'};
    } else if (status.isPermanentlyDenied) {
      return {
        'success': false,
        'message':
            'Location permission permanently denied. Please enable in settings.',
        'openSettings': true,
      };
    } else {
      return {
        'success': false,
        'message': 'Location permission is required to verify office location.',
      };
    }
  }
}
