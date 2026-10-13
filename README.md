# cache_broken — Notes (v2.2.0)

> **This project does not build.** `flutter pub get` fails, and the Android build fails
> twice more after that. Read `BUILD-GAUNTLET.md` at the root of the pack before you start.
> One value in the Android config looks wrong and is not what is failing.

```bash
flutter create . --platforms=android,ios --project-name cache_broken
flutter pub get
flutter test
TZ=Pacific/Chatham flutter test     # you will want this
flutter run --profile
```

`tool/seed.dart` builds a v2.1-shaped database with 900 notes so you can reproduce
CAC-202 and CAC-204 locally:

```bash
dart run tool/seed.dart --out /tmp/notes_v21.db --notes 900
```

Then point the app at it (see `lib/db/database.dart`, `overrideDatabasePath`).

## Open tickets

CAC-201 … CAC-206. See the brief.
