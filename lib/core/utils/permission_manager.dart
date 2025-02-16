import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  /// Check if microphone permission is granted
  static Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    // First check if permission is already granted
    if (await checkMicrophonePermission()) {
      return true;
    }

    // Request permission
    final status = await Permission.microphone.request();

    // If permission is denied and can be requested again
    if (status.isDenied) {
      return false;
    }

    // If permission is permanently denied, we should direct users to app settings
    if (status.isPermanentlyDenied) {
      return false;
    }

    return status.isGranted;
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Handle permanent denial
  static Future<bool> handlePermanentDenial() async {
    final isPermanentlyDenied = await Permission.microphone.isPermanentlyDenied;
    if (isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return true;
  }
}
