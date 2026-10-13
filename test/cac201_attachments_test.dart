// CAC-201: "database is locked" when saving a note that has attachments.
//
// Every statement of a save must run on the same sqflite transaction. These
// tests fail (time out) while _replaceAttachments uses the outer Database
// handle instead of the transaction it is called from.
import 'package:cache_broken/db/dao.dart';
import 'package:cache_broken/db/database.dart';
import 'package:cache_broken/models/note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Evidence for NOTES.md: logs every statement with its sqflite
    // transaction id ("txn": N). Statements of a save that are missing the
    // save's txn id are running outside its transaction.
    // ignore: deprecated_member_use
    databaseFactory = databaseFactoryFfi.debugQuickLoggerWrapper();
  });

  late NotesDao dao;

  setUp(() async {
    AppDatabase.overrideDatabasePath = inMemoryDatabasePath;
    await AppDatabase.instance.close();
    dao = NotesDao(AppDatabase.instance);
  });

  Note note(int id) {
    final t = DateTime.utc(2024, 1, 1, 9);
    return Note(id: id, title: 'note $id', body: 'body $id', createdAt: t, updatedAt: t);
  }

  test('CAC-201 saving a note with attachments completes and stores them',
      () async {
    await dao.saveWithAttachments(note(10), [
      Attachment(noteId: 10, path: 'a.png', bytes: 123),
      Attachment(noteId: 10, path: 'b.pdf', bytes: 456),
    ]).timeout(const Duration(seconds: 15));

    final db = await AppDatabase.instance.db;
    final rows =
        await db.query('attachments', where: 'note_id = ?', whereArgs: [10]);
    expect(rows.map((r) => r['path']), unorderedEquals(['a.png', 'b.pdf']));
  });

  test('CAC-201 a failed save rolls back the note and its attachments',
      () async {
    final db = await AppDatabase.instance.db;
    // Make the last statement of the save (the search-index write) fail.
    await db.execute('DROP TABLE notes_fts');

    await expectLater(
      dao.saveWithAttachments(note(11), [
        Attachment(noteId: 11, path: 'c.png', bytes: 1),
      ]).timeout(const Duration(seconds: 15)),
      throwsA(isA<DatabaseException>()),
    );

    expect(await db.query('notes', where: 'id = ?', whereArgs: [11]), isEmpty);
    expect(
      await db.query('attachments', where: 'note_id = ?', whereArgs: [11]),
      isEmpty,
    );
  });
}
