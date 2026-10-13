import 'package:sqflite/sqflite.dart';

import '../models/note.dart';
import 'database.dart';

class NotesDao {
  NotesDao(this._app);
  final AppDatabase _app;

  /// Saves a note and its attachments. Must be all-or-nothing.
  Future<void> saveWithAttachments(Note note, List<Attachment> files) async {
    final db = await _app.db;
    await db.transaction((txn) async {
      await txn.insert('notes', note.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _replaceAttachments(txn, note.id, files);
      await txn.insert('notes_fts',
          {'rowid': note.id, 'title': note.title, 'body': note.body},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Runs on the caller's transaction. Using the outer Database handle here
  /// (as before CAC-201) sends these statements outside the open transaction:
  /// they wait on it ("database is locked") and are not rolled back with it.
  Future<void> _replaceAttachments(
      DatabaseExecutor txn, int noteId, List<Attachment> files) async {
    if (files.isEmpty) return;
    await txn.delete('attachments', where: 'note_id = ?', whereArgs: [noteId]);
    for (final f in files) {
      await txn.insert('attachments',
          {'note_id': f.noteId, 'path': f.path, 'bytes': f.bytes});
    }
  }

  /// Backing query for the notes list.
  Future<List<Note>> listNotes({int limit = 1000}) async {
    final db = await _app.db;
    final rows = await db.query('notes', orderBy: 'updated_at DESC', limit: limit);
    final out = <Note>[];
    for (final r in rows) {
      final tagRows = await db.rawQuery(
        'SELECT t.label FROM tags t '
        'JOIN note_tags nt ON nt.tag_id = t.id '
        'WHERE nt.note_id = ?',
        [r['id']],
      );
      out.add(Note.fromRow(
        r,
        tags: tagRows.map((t) => t['label']! as String).toList(),
      ));
    }
    return out;
  }

  Future<List<Note>> search(String query) async {
    final db = await _app.db;
    if (query.trim().isEmpty) return listNotes();
    final rows = await db.rawQuery(
      'SELECT n.* FROM notes n '
      'JOIN notes_fts f ON f.rowid = n.id '
      'WHERE notes_fts MATCH ?',
      [query],
    );
    return rows.map((r) => Note.fromRow(r)).toList();
  }

  Future<int> countNotes() async {
    final db = await _app.db;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM notes');
    return (r.first['c'] as int?) ?? 0;
  }
}
