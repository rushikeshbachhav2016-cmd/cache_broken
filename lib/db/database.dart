import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Schema history
///   v1  notes(id, title, body, created_at)
///   v2  + notes.updated_at, + tags, + note_tags
///   v3  + full text search (notes_fts), + attachments      <- shipped in app 2.2.0
///
/// notes_fts uses FTS4, not FTS5: Android's built-in SQLite (used by sqflite)
/// does not include the FTS5 module on many devices ("no such module: fts5").
const int kSchemaVersion = 3;

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static String? overrideDatabasePath;

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path =
        overrideDatabasePath ?? p.join(await getDatabasesPath(), 'notes.db');
    return openDatabase(
      path,
      version: kSchemaVersion,
      onCreate: _createV3,
      onUpgrade: _upgrade,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _createV3(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    await db.execute('CREATE TABLE tags(id INTEGER PRIMARY KEY, label TEXT NOT NULL)');
    await db.execute('''
      CREATE TABLE note_tags(
        note_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE attachments(
        note_id INTEGER NOT NULL,
        path TEXT NOT NULL,
        bytes INTEGER NOT NULL
      )''');
    await db.execute(
        'CREATE VIRTUAL TABLE notes_fts USING fts4(title, body)');
  }

  Future<void> _upgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute("ALTER TABLE notes ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''");
      await db.execute('UPDATE notes SET updated_at = created_at');
      await db.execute('CREATE TABLE tags(id INTEGER PRIMARY KEY, label TEXT NOT NULL)');
      await db.execute('''
        CREATE TABLE note_tags(
          note_id INTEGER NOT NULL,
          tag_id INTEGER NOT NULL
        )''');
    }
    if (from < 3) {
      await db.execute('''
        CREATE TABLE attachments(
          note_id INTEGER NOT NULL,
          path TEXT NOT NULL,
          bytes INTEGER NOT NULL
        )''');

      // Build the search index from the live table before we reshape it.
      await db.execute(
          'CREATE VIRTUAL TABLE notes_fts USING fts4(title, body)');
      await db.execute(
          'INSERT INTO notes_fts(rowid, title, body) SELECT id, title, body FROM notes');

      // Reshape notes: id must become a plain INTEGER PRIMARY KEY (it was
      // AUTOINCREMENT in v1) and every column needs NOT NULL for the new
      // sync code. SQLite cannot ALTER those, so copy through a new table.
      await db.execute('''
        CREATE TABLE notes_new(
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          body TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )''');
      await db.execute('''
        INSERT INTO notes_new(id, title, created_at, updated_at)
        SELECT id, title, created_at, updated_at FROM notes''');
      await db.execute('DROP TABLE notes');
      await db.execute('ALTER TABLE notes_new RENAME TO notes');
    }
  }
}
