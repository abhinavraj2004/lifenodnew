import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/database/app_database.dart';
import '../core/database/message_model.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ValueNotifier<bool> isSyncing = ValueNotifier(false);
  final ValueNotifier<int> pendingCount = ValueNotifier(0);

  // USER TODO: Replace with your actual endpoint
  // Use 10.0.2.2 for Android Emulator to access host's localhost:3000
  // Try port 3000 first, fallback to 3001
  // Using ADB reverse proxy: adb reverse tcp:3000 tcp:3000
  String cloudEndpoint = 'http://127.0.0.1:3000/api/sync';
  String backupEndpoint = 'http://10.0.2.2:3000/api/sync';
  String backupEndpoint2 = 'http://192.168.0.195:3000/api/sync';

  Future<void> syncData() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    isSyncing.value = true;

    try {
      final db = await AppDatabase.database;
      // FIX: Handle NULL status (older messages) explicitly
      final rows = await db.query('messages',
          where: 'status IS NULL OR status != ?',
          whereArgs: ['synced_to_cloud']);

      pendingCount.value = rows.length;

      if (rows.isEmpty) {
        isSyncing.value = false;
        return;
      }

      // Real Sync
      debugPrint('SyncService: Syncing ${rows.length} messages to cloud...');

      bool success = false;

      // Try Primary Port (3000)
      try {
        await _performSync(cloudEndpoint, rows);
        success = true;
      } catch (e) {
        debugPrint('SyncService: Port 3000 failed, trying 3001: $e');
        try {
          await _performSync(backupEndpoint, rows);
          success = true;
        } catch (e2) {
          debugPrint('SyncService: Port 3001 failed, trying 3002: $e2');
          try {
            await _performSync(backupEndpoint2, rows);
            success = true;
          } catch (e3) {
            debugPrint('SyncService: Port 3002 failed too: $e3');
          }
        }
      }

      if (!success) return;

      // Mark as synced
      for (final row in rows) {
        await db.update(
          'messages',
          {'status': 'synced_to_cloud'},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      debugPrint(
          'SyncService: Marked ${rows.length} messages as synced locally.');

      pendingCount.value = 0;
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _performSync(String url, List<Map<String, Object?>> rows) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(rows),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('SyncService: Upload success to $url');
    } else {
      throw Exception('Status ${response.statusCode}');
    }
  }

  // Auto-sync could be triggered by connectivity changes
  void initAutoSync() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncData();
      }
    });
  }
}
