import 'package:permission_handler/permission_handler.dart';

/// Service to handle notification permissions for Android 13+ (API 33+)
class NotificationPermissionService {
  NotificationPermissionService._();
  static final NotificationPermissionService instance =
      NotificationPermissionService._();

  /// Check if notification permission is granted
  Future<bool> isGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Request notification permission
  /// Returns true if granted, false otherwise
  Future<bool> request() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Check if we should show rationale for notification permission
  Future<bool> shouldShowRationale() async {
    return await Permission.notification.shouldShowRequestRationale;
  }

  /// Open app settings if permission is permanently denied
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Request notification permission with rationale handling
  /// Returns true if granted, false otherwise
  Future<bool> requestWithRationale({
    required Function() onShowRationale,
  }) async {
    // Check current status
    final status = await Permission.notification.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      // Permission permanently denied, need to open settings
      return false;
    }

    // Check if we should show rationale
    if (await shouldShowRationale()) {
      onShowRationale();
    }

    // Request permission
    return await request();
  }
}
