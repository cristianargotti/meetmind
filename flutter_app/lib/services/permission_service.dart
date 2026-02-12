import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request.
enum PermissionResult {
  /// Permission granted.
  granted,

  /// Permission denied (can be re-requested).
  denied,

  /// Permission permanently denied (must open app settings).
  permanentlyDenied,

  /// Permission restricted by the system (e.g., parental controls).
  restricted,
}

/// Service for handling device permissions.
///
/// Wraps the `permission_handler` package with typed results
/// and platform-aware logic.
class PermissionService {
  /// Create a PermissionService instance.
  const PermissionService();

  /// Request microphone permission.
  ///
  /// Returns a [PermissionResult] indicating the outcome.
  Future<PermissionResult> requestMicPermission() async {
    final PermissionStatus status = await Permission.microphone.request();

    debugPrint('[PermissionService] Mic permission: ${status.name}');

    if (status.isGranted) {
      return PermissionResult.granted;
    } else if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    } else if (status.isRestricted) {
      return PermissionResult.restricted;
    }
    return PermissionResult.denied;
  }

  /// Check if microphone permission is currently granted.
  Future<bool> isMicGranted() async {
    final PermissionStatus status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Open the app's system settings page.
  ///
  /// Used when permission is permanently denied.
  Future<bool> openSettings() async {
    return openAppSettings();
  }
}
