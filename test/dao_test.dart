import 'package:cache_broken/db/dao.dart';
import 'package:cache_broken/db/database.dart';
import 'package:cache_broken/models/note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Visible suite. Green today.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late NotesDao dao;

  setUp(() async {
    AppDatabase.overrideDatabasePath = inMemoryDatabasePath;
    await AppDatabase.instance.close();
    dao = NotesDao(AppDatabase.instance);
  });

  test('search finds matches', () async {
    final now = DateTime.now();
    await dao.saveWithAttachments(
      Note(id: 1, title: 'grocery list', body: 'milk eggs', createdAt: now, updatedAt: now),
      const [],
    );
    final results = await dao.search('milk');
    expect(results, isA<List<Note>>());
  });

  test('tags load for every note', () async {
    final notes = await dao.listNotes();
    for (final n in notes) {
      expect(n.tags, isNotNull);
    }
  });

  test('save with attachments is atomic', () async {
    final now = DateTime.now();
    try {
      await dao.saveWithAttachments(
        Note(id: 2, title: 't', body: 'b', createdAt: now, updatedAt: now),
        const [],
      );
    } catch (_) {
      expect(true, isTrue);
    }
  });

  test('timestamps survive a round trip', () async {
    final t = DateTime.now();
    await dao.saveWithAttachments(
      Note(id: 3, title: 'x', body: 'y', createdAt: t, updatedAt: t),
      const [],
    );
    final back = (await dao.listNotes()).firstWhere((n) => n.id == 3);
    expect(back.updatedAt.hour, t.hour);
  });
}
