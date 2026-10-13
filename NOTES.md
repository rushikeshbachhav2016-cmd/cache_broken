# NOTES — cache_broken

## Stage 0

_(log each layer: verbatim error, file changed, one-line reason, elapsed clock)_

## CAC-201 — `database is locked` when saving a note with attachments

**Symptom.** Saving a note that has attachments fails with
`DatabaseException(database is locked)`. Notes without attachments save fine.
Retrying sometimes works.

**Hypothesis.** `NotesDao.saveWithAttachments` opens `db.transaction((txn) …)`,
but `_replaceAttachments` fetches the outer `Database` (`_app.db`) and issues its
`DELETE`/`INSERT`s on that handle, not on `txn`. Those statements are outside the
open transaction, so they queue behind its lock. "Only with attachments" matches
the early `if (files.isEmpty) return;`: with no attachments the outer handle is
never touched.

**Experiment.** `test/cac201_attachments_test.dart`, run on sqflite_common_ffi
with `databaseFactoryFfi.debugQuickLoggerWrapper()` so every statement is logged
with its sqflite transaction id (`"txn": N`).
1. Save a note with two attachments (15 s timeout), expect both rows stored.
2. Drop `notes_fts` so the last statement of the save fails; expect the note
   and its attachments to be rolled back together.

`flutter test test/cac201_attachments_test.dart` — **before the fix (red):**

```
(paste output: INSERT INTO notes … "txn": N, then no attachments statement,
 then sqflite's "Warning database has been locked for 0:00:10 … Make sure you
 always use the transaction object …", then TimeoutException)
```

**after the fix (green):**

```
(paste output: INSERT notes, DELETE attachments, INSERT attachments ×2,
 INSERT notes_fts — all with the same "txn": N; tests passed)
```

**Root cause.** Statements belonging to one logical save were split across two
executors: the transaction (`txn`) and the outer `Database`. The outer calls
wait for the transaction's lock while the transaction waits for them to finish,
so the save deadlocks (on device this surfaces as "database is locked"). It also
broke the method's own contract ("must be all-or-nothing"): attachment writes
were never part of the transaction, so they could not be rolled back.

**Fix.** `_replaceAttachments` takes the transaction (`DatabaseExecutor txn`)
and runs every statement on it (`lib/db/dao.dart`).

**Why the naive fix is wrong.** A retry loop treats a deterministic bug as
contention: every save with attachments deadlocks, and a retry only "works"
when timing happens to let the outer statements slip in, still outside the
transaction. Saves would stay non-atomic and be slower.

**Noticed, not fixed (out of scope for this ticket).**
- Attachments are inserted with `f.noteId`, not the saved note's `noteId`.
- An empty attachment list returns early, so removing all attachments never
  deletes the old rows.
