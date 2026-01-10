import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// List of all permissions required by the app
  static List<Permission> get requiredPermissions {
    final permissions = <Permission>[
      Permission.location,
      Permission.microphone,
    ];

    // Add Bluetooth permissions only on Android 12+ (API 31+)
    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
      ]);
    }

    return permissions;
  }

  /// Check if all permissions are granted
  Future<bool> areAllPermissionsGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      for (final permission in requiredPermissions) {
        try {
          final status = await permission.status.timeout(
            const Duration(seconds: 2),
            onTimeout: () => PermissionStatus.denied,
          );
          if (!status.isGranted) {
            return false;
          }
        } catch (e) {
          debugPrint('Error checking permission $permission: $e');
          // If we can't check a permission, assume it's not granted
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error in areAllPermissionsGranted: $e');
      return false;
    }
  }

  /// Request all permissions and return status
  Future<PermissionResult> requestAllPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return PermissionResult(allGranted: true, statuses: {});
    }

    final Map<Permission, PermissionStatus> statuses = {};
    bool allGranted = true;

    try {
      for (final permission in requiredPermissions) {
        try {
          final status = await permission.request().timeout(
                const Duration(seconds: 5),
                onTimeout: () => PermissionStatus.denied,
              );
          statuses[permission] = status;

          if (!status.isGranted) {
            allGranted = false;
          }
        } catch (e) {
          debugPrint('Error requesting permission $permission: $e');
          statuses[permission] = PermissionStatus.denied;
          allGranted = false;
        }
      }
    } catch (e) {
      debugPrint('Error in requestAllPermissions: $e');
      allGranted = false;
    }

    return PermissionResult(allGranted: allGranted, statuses: statuses);
  }

  /// Open app settings for manual permission granting
  Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  /// Get human-readable name for permission
  static String getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.bluetoothScan:
        return 'Bluetooth Scan';
      case Permission.bluetoothConnect:
        return 'Bluetooth Connect';
      case Permission.bluetoothAdvertise:
        return 'Bluetooth Advertise';
      case Permission.location:
        return 'Location';
      case Permission.nearbyWifiDevices:
        return 'Nearby Wi-Fi Devices';
      case Permission.microphone:
        return 'Microphone';
      default:
        return permission.toString();
    }
  }
}

class PermissionResult {
  final bool allGranted;
  final Map<Permission, PermissionStatus> statuses;

  PermissionResult({required this.allGranted, required this.statuses});

  List<Permission> get deniedPermissions => statuses.entries
      .where((e) => !e.value.isGranted)
      .map((e) => e.key)
      .toList();

  List<Permission> get permanentlyDeniedPermissions => statuses.entries
      .where((e) => e.value.isPermanentlyDenied)
      .map((e) => e.key)
      .toList();
}
