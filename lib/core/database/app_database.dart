import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'rescue.db');

    _db = await openDatabase(
      path,
      version: 3, // Increment version
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE tombstones (
              id TEXT PRIMARY KEY,
              timestamp INTEGER
            )
          ''');
        }
        if (oldVersion < 3) {
          // Add status column if it doesn't exist (for users upgrading from v1/v2)
          try {
            await db.execute('ALTER TABLE messages ADD COLUMN status TEXT');
          } catch (e) {
            // Column might already exist if fresh install went straight to v2/v3
            debugPrint('Migration v3: Column status might already exist: $e');
          }
        }
      },
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            payload TEXT,
            priority INTEGER,
            status TEXT,
            lat REAL,
            lng REAL,
            timestamp INTEGER
          )
        ''');
        // Create tombstones table for new installs
        await db.execute('''
          CREATE TABLE tombstones (
            id TEXT PRIMARY KEY,
            timestamp INTEGER
          )
        ''');
      },
    );
    return _db!;
  }

  /// Delete messages older than 1 hour
  static Future<int> cleanupOldMessages() async {
    try {
      final db = await database;
      final oneHourAgo = DateTime.now()
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;

      final count = await db.delete(
        'messages',
        where: 'timestamp < ?',
        whereArgs: [oneHourAgo],
      );

      // Also cleanup old tombstones to keep DB small
      await db.delete(
        'tombstones',
        where: 'timestamp < ?',
        whereArgs: [oneHourAgo],
      );

      if (count > 0) {
        debugPrint('AppDatabase: Cleaned up $count old messages');
      }
      return count;
    } catch (e) {
      debugPrint('AppDatabase: Error cleaning up messages: $e');
      return 0;
    }
  }

  /// Delete a specific message by ID
  static Future<int> deleteMessage(String id) async {
    try {
      final db = await database;
      return await db.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('AppDatabase: Error deleting message: $e');
      return 0;
    }
  }

  /// Add a tombstone checking if message is deleted
  static Future<void> addTombstone(String id) async {
    try {
      final db = await database;
      await db.insert(
        'tombstones',
        {
          'id': id,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('AppDatabase: Error adding tombstone: $e');
    }
  }

  /// Check if a message is tombstoned
  static Future<bool> isTombstoned(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        'tombstones',
        where: 'id = ?',
        limit: 1,
        whereArgs: [id],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('AppDatabase: Error checking tombstone: $e');
      return false;
    }
  }
}
