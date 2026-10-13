import 'dart:isolate';

import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Background sync opens its own connection so it never waits behind the UI.
class SyncWriter {
  static Future<void> run(String dbPath) async {
    await Isolate.run(() => _writeBatch(dbPath));
  }

  static Future<void> _writeBatch(String dbPath) async {
    final db = await openDatabase(dbPath, version: kSchemaVersion);
    final batch = db.batch();
    for (var i = 0; i < 500; i++) {
      batch.rawUpdate(
        'UPDATE notes SET updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), i],
      );
    }
    await batch.commit(noResult: true);
    await db.close();
  }
}
