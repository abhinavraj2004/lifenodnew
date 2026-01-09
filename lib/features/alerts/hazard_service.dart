import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

class HazardService {
  static Map<String, dynamic> lastKnownData = {
    "dam": "Idukki",
    "level": "2398 ft",
    "risk": "HIGH",
    "updated": "6 hours ago"
  };

  static Future<Map<String, dynamic>> getHazardData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      // Mock fetch from API
      await Future.delayed(const Duration(seconds: 1));
      lastKnownData = {
        "dam": "Idukki",
        "level": "2401 ft",
        "risk": "CRITICAL",
        "updated": "Just now"
      };
    }
    return lastKnownData;
  }

  static Future<bool> isInFloodZone() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      // Mock: High flood risk if lat < 10 (just for demo)
      return position.latitude < 10.0;
    } catch (_) {
      return false;
    }
  }
}
