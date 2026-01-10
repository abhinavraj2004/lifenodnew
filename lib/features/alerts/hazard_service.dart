import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class HazardService {
  static Map<String, dynamic> lastKnownData = {
    "dam": "Idukki",
    "level": "2398 ft",
    "risk": "HIGH",
    "updated": "6 hours ago"
  };

  // Using ADB reverse proxy: adb reverse tcp:3000 tcp:3000
  static const String apiUrl = 'http://127.0.0.1:3000/api/hazards';
  static const String backupUrl = 'http://10.0.2.2:3000/api/hazards';
  static const String backupUrl2 = 'http://192.168.0.195:3000/api/hazards';

  static Future<Map<String, dynamic>> getHazardData() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {
        http.Response response;
        // Try Port 3000
        try {
          debugPrint('HazardService: Trying port 3000...');
          response = await http
              .get(Uri.parse(apiUrl))
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // Try Port 3001
          try {
            debugPrint('HazardService: Port 3000 failed, trying 3001...');
            response = await http
                .get(Uri.parse(backupUrl))
                .timeout(const Duration(seconds: 3));
          } catch (_) {
            // Try Port 3002
            debugPrint('HazardService: Port 3001 failed, trying 3002...');
            response = await http
                .get(Uri.parse(backupUrl2))
                .timeout(const Duration(seconds: 3));
          }
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          lastKnownData = {
            "dam": data['location'] ?? "Unknown",
            "level": data['description'] ?? "Unknown",
            "risk":
                data['level'] ?? "UNKNOWN", // Mapping 'level' to 'risk' for UI
            "updated": "Just now" // Ideally parse 'updated_at'
          };
        }
      } catch (e) {
        debugPrint('HazardService: Error fetching data: $e');
      }
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
