# AGENTS.md — Workout App (Flutter MVP)

This file tells a coding agent how to build this app. Read all of it before writing code.
The product spec lives in `docs/workout_app_mvp.pdf` (optional). If it disagrees with this file, **this file wins**.

---

## 1. What we are building

A personal workout app for Android and iOS, built with Flutter. The user creates workouts
by **pasting or importing JSON** instead of filling in forms, then performs them in a
**guided player** with automatic rest timers, a breathing cue, and set logging.

- Local-first: no backend, no accounts, no network calls.
- One user (the developer) for now. Build for real daily use, not for demos.
- The MVP is done when every item in [§9 Acceptance criteria](#9-acceptance-criteria) passes.

### Out of scope — do not build these

Watch apps (Apple Watch / Wear OS), heart rate, motivational quote notifications,
a form-based workout editor, accounts, cloud sync, supersets/circuits (store the
`group` field, ignore it in the player), charts, exercise images or videos, analytics,
ads, in-app purchases. If a task seems to need one of these, stop and ask.

---

## 2. Working rules for the agent

1. **Work milestone by milestone** ([§8](#8-milestones)). Finish a milestone's exit
   checks before starting the next. Do not scaffold future milestones early.
2. **After every change, run:**
   ```bash
   dart format .
   flutter analyze          # must report zero issues
   flutter test             # must pass
   ```
   After changing drift tables, also run code generation (see [§3](#3-setup-and-commands)).
3. **Tests come with the code.** Every pure-Dart class in `lib/features/import/` and
   `lib/features/player/domain/` gets unit tests in the same change.
4. **No new dependencies** beyond [§4](#4-tech-stack) without a written reason in the
   commit message. Prefer the Dart/Flutter SDK.
5. **Add packages with `flutter pub add <name>`** so the latest compatible version is
   used. Follow each package's README for Android/iOS setup — do not guess.
6. **Do not edit generated files** (`*.g.dart`). Regenerate them.
7. **Keep commits small** and named by milestone, e.g. `M1: validate exercise fields`.
8. **When the spec is ambiguous**, pick the simplest behaviour that satisfies the
   acceptance criteria, write the decision in `docs/DECISIONS.md` (one line each), and continue.
9. Never invent features, copy text, or settings not described here.

---

## 3. Setup and commands

```bash
# one-time (if the repo is empty) — already done; the Flutter app is the repo root.
# App ID on both platforms: io.github.reeloyyy.workoutapp (set by hand after create;
# never change it — the app's data is tied to it).
flutter create --org io.github.reeloyyy --project-name workout_app --platforms=android,ios .

# dependencies
flutter pub add flutter_riverpod go_router drift drift_flutter path_provider \
  flutter_local_notifications timezone flutter_timezone file_picker wakelock_plus
flutter pub add --dev build_runner drift_dev

# code generation (drift)
dart run build_runner build --delete-conflicting-outputs

# checks
dart format . && flutter analyze && flutter test

# run on a connected phone
flutter run
```

Platform setup the agent must do (verify against package READMEs):

- **Android** (`android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle*`):
  - `POST_NOTIFICATIONS` permission (Android 13+), requested at runtime.
  - `SCHEDULE_EXACT_ALARM` permission for on-time rest alerts. If the user has not
    granted it, fall back to an inexact schedule and keep the in-app timer working.
  - `RECEIVE_BOOT_COMPLETED` and the receivers `flutter_local_notifications` documents,
    so weekly reminders survive a reboot.
  - Enable core library desugaring if `flutter_local_notifications` requires it.
- **iOS**: request notification authorisation through `flutter_local_notifications`;
  set the `UNUserNotificationCenter` delegate as its README describes.

---

## 4. Tech stack

| Concern | Choice | Notes |
|---|---|---|
| Language | Dart, sound null safety | Strict analysis (see below). |
| State | `flutter_riverpod` | Use `Notifier` / `AsyncNotifier`. No `StateNotifier`, no `ChangeNotifier`. |
| Navigation | `go_router` | All routes in `lib/app/router.dart`. |
| Database | `drift` + `drift_flutter` | SQLite. Schema migrations from day one. |
| Notifications | `flutter_local_notifications`, `timezone`, `flutter_timezone` | Rest alerts and weekly reminders. |
| File import | `file_picker` | Clipboard via `package:flutter/services.dart`. |
| Screen awake | `wakelock_plus` | On only while a session is active. |
| Tests | `flutter_test` | Unit + widget tests. |

`analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  exclude:
    - "**/*.g.dart"

linter:
  rules:
    - prefer_final_locals
    - prefer_const_constructors
    - avoid_print
    - require_trailing_commas
```

---

## 5. Architecture

### 5.1 Folder layout

```
lib/
  main.dart                      # init timezone, notifications, ProviderScope
  app/
    router.dart                  # go_router config
    theme.dart                   # Material 3 theme, light + dark
  core/
    clock.dart                   # Clock interface + SystemClock
    widgets/                     # shared widgets (Stepper, BigButton, EmptyState)
  data/
    db/
      app_database.dart          # drift database + tables
      app_database.g.dart        # generated
    repositories/
      workout_repository.dart
      session_repository.dart
  features/
    import/
      domain/
        workout_parser.dart      # PURE DART: String -> ImportResult
        import_error.dart
      ui/
        import_screen.dart
        import_preview_screen.dart
    library/
      ui/ library_screen.dart, workout_detail_screen.dart
    player/
      domain/
        session_state.dart       # PURE DART: immutable state
        session_controller.dart  # PURE DART: state machine
        rest_duration.dart
      ui/
        player_screen.dart, rest_view.dart, breathing_circle.dart
        session_summary_screen.dart
      player_providers.dart      # Riverpod glue between controller, repo, notifications
    history/
      ui/ history_screen.dart, session_detail_screen.dart
    settings/
      ui/ settings_screen.dart
  models/
    workout.dart                 # PURE DART domain models
    exercise.dart
    set_log.dart
    session.dart
  services/
    notification_service.dart    # wraps flutter_local_notifications
    settings_service.dart        # unit, reminders, sound/vibration (stored in drift)
test/
  fixtures/                      # JSON files used by parser tests
  import/workout_parser_test.dart
  player/session_controller_test.dart
  data/repositories_test.dart    # in-memory drift database
  widgets/                       # widget tests for import + player
docs/
  DECISIONS.md
```

### 5.2 Rules that must hold

- **`features/import/domain/` and `features/player/domain/` and `models/` import no
  Flutter packages** — only `dart:` libraries and each other. These hold all the logic
  and are where the tests are. A future watch app will reuse the session controller.
- **Widgets contain no workout logic.** They read state and call intent methods
  (`completeSet()`, `skipRest()`, `addRestTime()`).
- **Time comes from an injected `Clock`.** Never call `DateTime.now()` outside
  `SystemClock`. Tests use a `FakeClock` they can advance.
- **Domain models are immutable** with `copyWith`, `==` and `hashCode`. Write these by
  hand; do not add `freezed`.
- **Repositories convert** between drift rows and domain models. UI never touches drift types.

### 5.3 Key interfaces (implement these shapes)

```dart
// core/clock.dart
abstract interface class Clock { DateTime now(); }
class SystemClock implements Clock { @override DateTime now() => DateTime.now(); }

// features/import/domain/import_error.dart
class ImportIssue {
  final String path;        // e.g. "workouts[0].exercises[2].durationSeconds"
  final String message;     // plain-language, shown to the user
  final bool isWarning;     // warnings do not block import
}

// features/import/domain/workout_parser.dart
sealed class ImportResult {}
class ImportSuccess extends ImportResult {
  final List<Workout> workouts;
  final List<ImportIssue> warnings;
}
class ImportFailure extends ImportResult {
  final List<ImportIssue> errors;   // ALL errors found, never just the first
  final List<ImportIssue> warnings;
}
ImportResult parseWorkouts(String json, {required WeightUnit defaultUnit});
String exportWorkouts(List<Workout> workouts); // pretty-printed, 2-space indent

// features/player/domain/session_controller.dart
class SessionController {
  SessionController({required Workout workout, required Clock clock, SessionState? resumeFrom});
  SessionState get state;
  Stream<SessionState> get changes;

  void selectExercise(int exerciseIndex);
  void startTimedSet();                       // timed exercises only
  SetLog completeSet({int? reps, double? weight, int? durationSeconds});
  void skipRest();
  void addRestTime(Duration extra);           // +15 s button
  void tick();                                // called ~4x/sec by the UI; ends rest when due
  void finish();
}
```

`completeSet` returns the `SetLog` so the provider layer can persist it immediately.

---

## 6. Workout JSON format (schema version 1)

This format is the product. Do not change the meaning of a field without bumping
`schemaVersion`. Save this example as `test/fixtures/valid_push_day.json`.

```json
{
  "schemaVersion": 1,
  "workouts": [
    {
      "name": "Push Day A",
      "description": "Chest, shoulders, triceps",
      "tags": ["push", "upper"],
      "defaultRestSeconds": 90,
      "exercises": [
        {
          "name": "Bench Press",
          "type": "reps",
          "sets": 4,
          "reps": 6,
          "repsMax": 8,
          "weight": 60,
          "unit": "kg",
          "restSeconds": 120,
          "notes": "Pause briefly on the chest"
        },
        { "name": "Overhead Press", "type": "reps", "sets": 3, "reps": 10 },
        { "name": "Plank", "type": "timed", "sets": 3, "durationSeconds": 45, "restSeconds": 60 }
      ]
    }
  ]
}
```

### 6.1 Fields

**Root**

| Field | Type | Required | Rules |
|---|---|---|---|
| `schemaVersion` | int | yes | Must be `1`. If greater, fail with: *"This file needs a newer version of the app."* |
| `workouts` | array | yes | ≥ 1 workout. |

**Workout**

| Field | Type | Required | Rules |
|---|---|---|---|
| `name` | string | yes | 1–60 chars after trim. |
| `description` | string | no | ≤ 300 chars. |
| `tags` | string[] | no | ≤ 10 items, each 1–30 chars. |
| `defaultRestSeconds` | int | no | 0–600. Default `90`. |
| `exercises` | array | yes | ≥ 1 exercise. |

**Exercise**

| Field | Type | Required | Rules |
|---|---|---|---|
| `name` | string | yes | 1–60 chars after trim. |
| `type` | string | no | `"reps"` or `"timed"`. Default `"reps"`. |
| `sets` | int | yes | 1–20. |
| `reps` | int | if `reps` | 1–200. Target, or lower bound of a range. |
| `repsMax` | int | no | ≥ `reps`, ≤ 200. Only for `reps` type. |
| `durationSeconds` | int | if `timed` | 1–3600. |
| `weight` | number | no | ≥ 0, ≤ 2000. |
| `unit` | string | no | `"kg"` or `"lb"`. Default: app setting. |
| `restSeconds` | int | no | 0–600. Overrides workout default. |
| `notes` | string | no | ≤ 300 chars. |
| `group` | string | no | Reserved for supersets. Store it; the player ignores it. |

### 6.2 Parser behaviour

- Strip a UTF-8 BOM and surrounding whitespace before decoding.
- If the text is not valid JSON, return one error with the parser's message and, when
  available, line and column: *"Not valid JSON (line 12, column 5): Unexpected character."*
- Validate the whole document and return **every** error in one result.
- Accept integers written as `90.0` for int fields; reject `90.5`.
- Wrong type → error, e.g. *"`sets` must be a whole number."*
- Unknown fields → **warning**, not error: *"Unknown field `tempo` was ignored."*
- `reps` set on a timed exercise, or `durationSeconds` on a reps exercise → warning, value ignored.
- User-facing messages name the location in words, built from the path:
  *"Push Day A › exercise 3 (Plank): `durationSeconds` is required for timed exercises."*
  If the workout name is missing, use *"Workout 1"*.
- Export produces JSON that re-imports to an identical `Workout` (round-trip test required).
  Omit fields that hold their default value.

### 6.3 Required parser tests (fixtures in `test/fixtures/`)

| Fixture | Expected |
|---|---|
| `valid_push_day.json` | Success, 1 workout, 3 exercises, Bench rest = 120, OHP rest = 90. |
| `invalid_syntax.json` (trailing comma) | Failure, 1 error mentioning line/column. |
| `missing_fields.json` (no `sets` on ex. 1, no `durationSeconds` on a timed ex.) | Failure, exactly 2 errors, both located. |
| `future_version.json` (`schemaVersion: 2`) | Failure, "newer version" message. |
| `unknown_field.json` (extra `tempo`) | Success with 1 warning. |
| `bad_ranges.json` (`sets: 0`, `repsMax < reps`, `restSeconds: 900`) | Failure, 3 errors. |
| Round trip | `parse(export(parse(valid)))` equals `parse(valid)`. |

---

## 7. Features in detail

### 7.1 Screens and routes

| Route | Screen | Behaviour |
|---|---|---|
| `/` | Library | Saved workouts: name, exercise count, "last done" date. FAB → Import. Empty state explains import and has **"Add sample workout"** (imports the fixture above). Banner to resume an unfinished session if one exists. |
| `/import` | Import | Multiline text field (monospace). Buttons: **Paste**, **Choose file** (`.json`), **Validate**. Errors and warnings listed under the field. |
| `/import/preview` | Import preview | Read-only list of each workout and its exercises as the player shows them. **Save** / **Back**. If a name already exists, dialog: *Replace*, *Keep both* (append " (2)", or the next free number: " (3)", …), *Cancel*. |
| `/workout/:id` | Workout detail | Exercises with sets × reps (or duration), weight, rest. Buttons: **Start**, **Export** (copy JSON to clipboard + snackbar), **Delete** (confirm). |
| `/session/:id` | Player | See §7.2. Back button asks "Leave workout? Progress is saved." |
| `/session/:id/summary` | Summary | Duration, sets completed, total volume (Σ reps × weight, reps type only; one total per unit if kg and lb are mixed, no conversion). **Done** → `/`. |
| `/history` | History | Sessions newest first: workout name, date, duration, sets. |
| `/history/:id` | Session detail | Logged sets grouped by exercise. |
| `/settings` | Settings | Default unit, reminder days + time, rest-end sound on/off, vibration on/off. |

Bottom navigation: **Workouts** (`/`), **History**, **Settings**. Hidden on player screens.

### 7.2 Workout player

**Layout**
- Header: workout name, elapsed time, **Finish** button.
- Scrollable list of exercise cards: name, target ("4 × 6–8 @ 60 kg" or "3 × 45 s"),
  progress ("2/4"), done check mark.
- Weights are shown in each exercise's own unit. No kg ↔ lb conversion anywhere.
- Tapping a card selects it as the active exercise and expands it. Any order is allowed.
- Expanded card shows one row per set: set number, **last time** value (e.g. "60 kg × 8",
  or "× 8" when no weight was logged), reps stepper, weight stepper, and a large **Done**
  button for the next pending set.
- Exercise with no weight (no JSON `weight` and no previous logged weight): show a small
  **Add weight** control in place of the weight stepper. Tapping it reveals the stepper
  (starting at 0) for that exercise for the rest of the session, so bodyweight exercises
  can be loaded later (e.g. weighted dips).
- Steppers pre-fill from: last logged value for this exercise name → JSON target → empty.
  Weight steps: 2.5 kg or 5 lb. Reps step: 1.
- Timed exercise: **Start** begins a countdown of `durationSeconds`; it auto-completes at zero
  (vibrate), or the user taps **Done** early (logs actual seconds). The countdown stores its
  end time, like rest (see *Timer correctness*). A timed set in progress is not persisted:
  after a resume the exercise is active again and the set must be restarted. Only rest
  gets a lock-screen notification, not the end of a timed set.
- Tap targets ≥ 56 dp. Keep the screen awake while the player is open.

**State machine** (in `SessionController`)

```
idle ──selectExercise──▶ performing ──completeSet──▶ resting ──(time up | skip)──▶ next step
next step:
  exercise has sets left      → performing (same exercise)
  exercise has no sets left   → idle, card marked done, next unfinished exercise highlighted
  whole workout has no sets   → finished (no rest; go to summary)
selectExercise during rest    → allowed; rest continues, the new exercise becomes active
any state ──finish──▶ finished
```

- Rest duration = `exercise.restSeconds ?? workout.defaultRestSeconds ?? 90`.
- No rest after the final set of the whole workout. Rest **does** follow the last set of
  a non-final exercise (the user is moving to the next one).
- Rest of 0 seconds → skip the rest view.
- `addRestTime` adds 15 s to the end time.

**Rest view** (full screen over the player)
- Big countdown (mm:ss) inside a progress ring.
- Breathing circle: scales up over 4 s with text "Breathe in", down over 6 s with
  "Breathe out", looping. Use an `AnimationController`; respect reduced-motion
  (`MediaQuery.disableAnimations`) by showing text only.
- "Up next: Bench Press — set 3 of 4". Up next is the active exercise if it has sets left,
  otherwise the first unfinished exercise in list order.
- Buttons: **+15 s**, **Skip**.

**Timer correctness — mandatory**
- Store `restEndsAt` (a `DateTime`), never a decrementing counter.
- Remaining time is always `restEndsAt - clock.now()`, recomputed on every tick and when
  the app resumes (`AppLifecycleListener`).
- When rest starts: schedule a local notification at `restEndsAt`
  (title "Rest over", body "Set 3 of 4 — Bench Press"). On skip, +15 s, or finish:
  cancel/reschedule it. Use one fixed notification ID for the rest alert.
- **The notification is the alert in every app state, including the foreground.** Do not
  cancel it when the app is open, and do not play sound or vibration from app code.
  - Android: post it on a high-importance channel, so it shows as a heads-up with sound
    and vibration while the app is open. Channel sound/vibration cannot change after the
    channel is created, so create one channel per combination of the *rest-end sound* and
    *vibration* settings and schedule on the channel matching the current settings.
  - iOS: set the foreground presentation options (alert/banner, sound) so the notification
    still shows and plays its sound while the app is open; `presentSound` follows the
    *rest-end sound* setting.
- When rest ends, the in-app rest view closes on its own (driven by `tick()` and
  `restEndsAt`), independently of the notification.

**Persistence — mandatory**
- Create the `sessions` row when the player opens.
- Insert each `SetLog` the moment it is completed (before updating UI is fine; do not batch).
- Persist the controller's resumable state (active exercise, `restEndsAt`) in the session row.
- On app start, a session with `finished_at IS NULL` triggers the resume banner. Resuming
  rebuilds the controller from the session's logs. Discarding marks it finished with zero
  additional sets.

### 7.3 Reminders

- Settings: weekday toggles (Mon–Sun) and one time of day. Off by default.
- Schedule one weekly repeating notification per selected day
  (`matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`), in the local
  time zone from `flutter_timezone`. Reminder IDs: 100–106.
- Text: title "Time to train", body = name of the least recently performed workout
  (or "Open your workouts" if none). Reschedule all reminders whenever settings change
  or a session finishes.
- Tapping a notification opens `/`.
- Ask for notification permission when the user first enables reminders or first
  starts a workout — never on first launch.

### 7.4 Data model (drift)

| Table | Columns |
|---|---|
| `workouts` | `id` PK, `name`, `description?`, `tags_json`, `default_rest_seconds`, `created_at`, `updated_at` |
| `exercises` | `id` PK, `workout_id` FK (cascade delete), `position`, `name`, `type`, `sets`, `reps?`, `reps_max?`, `duration_seconds?`, `weight?`, `unit?`, `rest_seconds?`, `notes?`, `group_key?` |
| `sessions` | `id` PK, `workout_id?` (set null on delete), `workout_name`, `workout_snapshot_json`, `started_at`, `finished_at?`, `active_exercise_index?`, `rest_ends_at?` |
| `set_logs` | `id` PK, `session_id` FK (cascade), `exercise_position`, `exercise_name`, `set_number`, `reps?`, `weight?`, `unit?`, `duration_seconds?`, `completed_at` |
| `settings` | single row: `unit`, `reminder_days_mask`, `reminder_minutes`, `sound_on`, `vibration_on` |

- `workout_snapshot_json` stores the exported workout at session start, so history and
  resume still work if the workout is edited or deleted.
- "Last time" = most recent `set_logs` rows with the same `exercise_name` (case-insensitive,
  trimmed) from a different session, matched by `set_number`.
- Index `set_logs(exercise_name, completed_at)`.
- `schemaVersion` of the database starts at 1; every change adds a migration and a
  migration test.

---

## 8. Milestones

Each milestone ends with: format, analyze, tests green, and the app running on a device.

Verification is Android-only for the MVP. Use the emulator only for quick UI checks;
lock-screen, battery-saver and reboot checks must be done on the real Android phone.
iOS is configured from the package READMEs but not run; everything unverified on iOS is
listed in `docs/DECISIONS.md`.

### M0 — Project setup
- [ ] `flutter create`, dependencies, `analysis_options.yaml`, platform permissions.
- [ ] `Clock`, theme (Material 3, light/dark, seed colour `#1F5FA8`), router with
      placeholder screens and bottom navigation.
- [ ] `docs/DECISIONS.md` created.
- **Exit:** app launches; all tabs navigate; `flutter analyze` clean.

### M1 — Models, parser, import
- [ ] Domain models with `copyWith`/equality.
- [ ] `parseWorkouts` and `exportWorkouts` with all rules in §6.2.
- [ ] All fixtures and tests in §6.3.
- [ ] Import and preview screens (in-memory only).
- **Exit:** pasting the example shows a correct preview; bad fixtures show all errors.

### M2 — Database and library
- [ ] Drift database, repositories, repository tests with an in-memory database.
- [ ] Save from preview (with duplicate-name dialog), library list, detail, delete, export.
- [ ] Empty state with "Add sample workout".
- **Exit:** workouts survive an app restart; export → import round-trips.

### M3 — Player and rest timer
- [ ] `SessionController` + full unit tests using `FakeClock` (any-order selection,
      rest duration fallback, no rest after final set, skip, +15 s, timed sets, finish).
- [ ] Player UI, rest view, breathing circle, wakelock.
- [ ] `NotificationService`: permission, schedule/cancel rest alert, foreground sound/vibration.
- **Exit:** a full workout can be completed on a phone; locking the phone during rest
  still produces the alert on time.

### M4 — Logging, history, resume
- [ ] Set logs persisted immediately; session snapshot; resume banner; discard.
- [ ] "Last time" values and stepper pre-fill.
- [ ] Summary, history list, session detail.
- **Exit:** killing the app mid-workout and reopening offers resume with no lost sets.

### M5 — Settings and reminders
- [ ] Settings screen and persistence; unit used as default for imports and display.
- [ ] Weekly reminders scheduled, rescheduled, and cancelled correctly; survive reboot (Android).
- **Exit:** a reminder set for two minutes from now fires (test by temporarily setting day/time).

### M6 — Hardening
- [ ] Widget tests: import happy path, import error list, player completes a set and shows rest.
- [ ] Manual test pass of every item in §9 on a real Android or iOS device; record results
      in `docs/TEST_LOG.md`.
- **Exit:** all acceptance criteria pass.

---

## 9. Acceptance criteria

1. The example JSON imports with no errors and previews 3 exercises.
2. A missing required field produces an error naming the workout, exercise, and field.
3. A file with two mistakes reports both in one validation.
4. `schemaVersion: 2` is rejected with the "newer version" message.
5. Exercises can be performed in any order by tapping them.
6. Completing a set starts rest with duration = exercise → workout default → 90 s.
7. Locking the phone during rest and unlocking later shows the correct remaining time.
8. With the phone locked, a notification with sound/vibration arrives within ~2 s of rest ending.
9. Killing the app mid-workout and reopening offers resume with all logged sets intact.
10. The second time an exercise is performed, previous reps and weight are shown.
11. Exporting a workout and re-importing it produces an identical workout.
12. A reminder set for a weekday and time fires on that day and time.
13. `flutter analyze` reports no issues and `flutter test` passes.

---

## 10. UI and copy guidelines

- Material 3, system light/dark mode. Large type for numbers in the player and rest view.
- Plain, short copy. No exclamation marks, no motivational slogans.
- Every error the user sees says what is wrong and where. Never show a raw exception.
- Support text scaling up to 1.5× without overflow on player and rest screens.
- All interactive elements have semantic labels for screen readers.

---

## 11. Later (do not build now)

Kept here so the architecture leaves room for them:
supersets/circuits via `group`, an AI prompt that produces valid JSON, import from link/QR,
a small in-app editor, progress charts and personal records, opt-in motivational
notifications based on streaks, backup/restore and sync, Wear OS then Apple Watch apps
driving `SessionController` (rest timer, heart rate, start/finish sets), store release.