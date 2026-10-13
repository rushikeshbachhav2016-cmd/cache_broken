// Builds a v2.1-shaped (schema v2) database so CAC-202 and CAC-204 reproduce.
//
//   dart run tool/seed.dart --out /tmp/notes_v21.db --notes 900
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final out = _arg(args, '--out') ?? '/tmp/notes_v21.db';
  final count = int.parse(_arg(args, '--notes') ?? '900');
  File(out).existsSync() ? File(out).deleteSync() : null;

  final db = await databaseFactory.openDatabase(out,
      options: OpenDatabaseOptions(version: 2));

  await db.execute('''
    CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT ''
    )''');
  await db.execute('CREATE TABLE tags(id INTEGER PRIMARY KEY, label TEXT NOT NULL)');
  await db.execute(
      'CREATE TABLE note_tags(note_id INTEGER NOT NULL, tag_id INTEGER NOT NULL)');

  const labels = ['work', 'home', 'urgent', 'later', 'idea', 'receipt', 'travel'];
  for (var i = 0; i < labels.length; i++) {
    await db.insert('tags', {'id': i + 1, 'label': labels[i]});
  }

  final base = DateTime.utc(2024, 1, 1);
  final batch = db.batch();
  for (var i = 1; i <= count; i++) {
    final t = base.add(Duration(minutes: i * 7));
    batch.insert('notes', {
      'id': i,
      'title': 'Note $i — o\'clock ☕',
      'body': 'Body text for note $i. ' * (1 + i % 12),
      'created_at': t.toIso8601String(),
      'updated_at': t.toIso8601String(),
    });
    for (var k = 0; k < 1 + i % 4; k++) {
      batch.insert('note_tags', {'note_id': i, 'tag_id': 1 + (i + k) % labels.length});
    }
  }
  await batch.commit(noResult: true);
  await db.close();
  stdout.writeln('wrote $out with $count notes (schema v2)');
}

String? _arg(List<String> a, String k) {
  final i = a.indexOf(k);
  return (i >= 0 && i + 1 < a.length) ? a[i + 1] : null;
}
