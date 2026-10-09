# workout_app

A personal workout app for Android and iOS, built with Flutter.

Workouts are created by pasting or importing JSON, then performed in a guided player
with rest timers, a breathing cue and set logging. Everything is stored on the phone;
there is no backend and no account.

## Docs

- [`docs/AGENTS.md`](docs/AGENTS.md) — the build spec: scope, architecture, the workout
  JSON format, milestones and acceptance criteria. Start here.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — decisions made where the spec was open.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift code generation
dart format . && flutter analyze && flutter test
flutter run
```
