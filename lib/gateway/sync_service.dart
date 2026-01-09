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

  Future<void> syncData() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    isSyncing.value = true;

    try {
      final db = await AppDatabase.database;
      final rows = await db.query('messages',
          where: 'status != ?', whereArgs: ['synced_to_cloud']);

      pendingCount.value = rows.length;

      if (rows.isEmpty) {
        isSyncing.value = false;
        return;
      }

      // Mock Supabase Push
      // await http.post...
      await Future.delayed(const Duration(seconds: 2)); // Simulate network

      // In real implementation:
      // final response = await http.post(Uri.parse('SUPABASE_URL'), body: jsonEncode(rows));
      // if (response.statusCode == 200) ...

      // Mark as synced
      for (final row in rows) {
        await db.update(
          'messages',
          {'status': 'synced_to_cloud'},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }

      pendingCount.value = 0;
    } catch (e) {
      print('Sync failed: $e');
    } finally {
      isSyncing.value = false;
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
