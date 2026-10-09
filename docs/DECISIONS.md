# Decisions

One line per decision. Decisions that change the spec are also written into `docs/AGENTS.md`.

## Project

- 2026-10-08 — Earlier FitTrack prototype archived on branch `archive/fittrack`; app rebuilt from scratch.
- 2026-10-08 — Flutter app is the repo root (no `workout/` subfolder). Package name `workout_app`.
- 2026-10-08 — App ID `io.github.reeloyyy.workoutapp` on Android and iOS. Do not change it: data is tied to it.
- 2026-10-08 — Display name "Workout App" on both platforms.
- 2026-10-08 — Flutter upgraded to 3.47.7: `flutter_riverpod` 3.4, `go_router` 18, `drift` 2.35. No code changes were needed. Riverpod 3 pauses providers for widgets that are not visible; keep that in mind for the player overlay (M3).
- 2026-10-08 — `flutter_local_notifications` stays on stable 22.3.x (`pub upgrade --major-versions` picked 23.0.0-dev). Its Linux plugin needs `dbus` 0.7, which holds `wakelock_plus` at 1.7.x (1.8.1 needs `dbus` 0.8). Revisit when notifications 23 is stable.
- 2026-10-08 — Android AGP raised to 8.12.1 (minimum for `wakelock_plus`; ≥ 8.11.1 required by `flutter_local_notifications`).
- 2026-10-08 — iOS deployment target raised to 14.0 (required by `file_picker`).
- 2026-10-08 — Exact alarms use `SCHEDULE_EXACT_ALARM` (user-grantable), not `USE_EXACT_ALARM`; inexact fallback when not granted.
- 2026-10-08 — `main.dart` does not initialise timezone or notifications yet; added in M3/M5 when first used.
- 2026-10-08 — Verification is Android-only (real phone for lock-screen/battery-saver/reboot, emulator for UI). iOS is configured, not run.

## M1 — Import

- 2026-10-08 — `Exercise.unit` is never null: JSON value, else the default unit. Export always writes `unit` (written into AGENTS.md §6.2).
- 2026-10-08 — Strings are trimmed; empty optional strings and `null` values count as absent (AGENTS.md §6.2).
- 2026-10-08 — `schemaVersion` > 1 reports only the "newer version" error; other fields are not checked (AGENTS.md §6.2).
- 2026-10-08 — An invalid `type` skips the type-specific "required" checks to avoid follow-on errors; present values are still range-checked.
- 2026-10-08 — Only the BOM is stripped before decoding (surrounding whitespace is valid JSON), so line/column match the text the user sees.
- 2026-10-08 — Field names in backticks are shown in monospace without backticks (AGENTS.md §6.2). Each issue row is one screen-reader item ("Error, …" / "Warning, …").
- 2026-10-08 — New copy needed by the import screen: "The clipboard has no text.", "This file is not UTF-8 text.", "The file could not be opened.", "Workout N is not a JSON object.", and "The file must be a JSON object with `schemaVersion` and `workouts`."
- 2026-10-08 — Choose file loads the file into the text field; the user still taps Validate. Success opens the preview; warnings show on both screens.
- 2026-10-08 — Import screens live under the Workouts tab, so the bottom navigation stays visible.
- 2026-10-08 — Preview shows each exercise as "target · Rest N s" plus notes. The Save button arrives with the database in M2.
- 2026-10-08 — Default unit is kg until settings exist (M5, `defaultUnitProvider`).
- 2026-10-08 — `SetLog` and `Session` models are added in M3/M4 with the code that uses them.
- 2026-10-08 — Widget tests for the import happy path and error list were written in M1 (planned for M6), since they check M1's exit criteria.

## Behaviour (approved; written into AGENTS.md)

- 2026-10-08 — Rest-end alert is the scheduled notification in every app state, foreground included (no app-side sound/vibration). Android: high-importance channel, one channel per sound/vibration settings combination. iOS: foreground presentation options show it and play sound.
- 2026-10-08 — The in-app rest view closes on its own when rest ends, independently of the notification.
- 2026-10-08 — No kg ↔ lb conversion. Weights show in the exercise's unit; summary volume shows one total per unit.
- 2026-10-08 — "Keep both" on a duplicate name appends the next free number: " (2)", " (3)", ….
- 2026-10-08 — A timed set in progress is not persisted for resume; only rest gets a lock-screen notification.
- 2026-10-08 — The timed-set countdown stores its end time, like rest.
- 2026-10-08 — "Up next" = active exercise if it has sets left, else first unfinished exercise in list order.
- 2026-10-08 — Exercises without weight show an "Add weight" control that reveals the weight stepper (from 0); "last time" without weight shows "× 8".

## Unverified on iOS

- Build, launch and navigation.
- `UNUserNotificationCenter` delegate set in `AppDelegate.swift`; notification permission prompt.
- Rest alert banner and sound while the app is in the foreground.
- Rest alert timing with the phone locked.
- Weekly reminders firing at the set day and time.
- The vibration setting: iOS has no per-notification vibration control; vibration follows the system's sound settings.
- File import from the Files app.
- Wakelock while the player is open.

## M2 — Database and library

- 2026-10-08 — All five §7.4 tables are in schema v1 (the library's "last done" already needs `sessions` and `set_logs`). The v1 schema is snapshotted in `drift_schemas/`; `make-migrations` generates migration tests from v2 on.
- 2026-10-08 — `exercises.unit` is NOT NULL, matching `Exercise.unit` (AGENTS.md §7.4).
- 2026-10-08 — DateTimes are stored as ISO-8601 text in UTC; repositories return local time (AGENTS.md §7.4).
- 2026-10-08 — Foreign keys are switched on (`PRAGMA foreign_keys = ON`) every time the database opens, so cascades and set-null work.
- 2026-10-08 — The settings row is created with defaults: kg, no reminder days, 18:00, sound on, vibration on.
- 2026-10-08 — "Last done" = end time of the latest finished session with ≥ 1 logged set, so discarded sessions do not count (AGENTS.md §7.1).
- 2026-10-08 — The library is sorted by name, case-insensitive (AGENTS.md §7.1).
- 2026-10-08 — Several workouts in one file: one dialog per name clash, Cancel saves nothing, everything is saved in one transaction; names repeated inside the file are numbered without asking (AGENTS.md §7.1).
- 2026-10-08 — Numbered names are shortened to stay within 60 characters so they still re-import (AGENTS.md §7.1).
- 2026-10-08 — Replace keeps the workout's id and creation time, so past sessions stay linked.
- 2026-10-08 — The detail screen shows Export and Delete as app-bar icons with tooltips. Start arrives with the player in M3.
- 2026-10-08 — "Add sample workout" loads `assets/sample_workout.json`, a copy of `test/fixtures/valid_push_day.json` (a test checks they match).
- 2026-10-08 — New copy: "No workouts yet", "Workouts are added as JSON. Tap Import, then paste the JSON or choose a .json file.", "N exercises · Last done <date>" / "Not done yet", "Workout saved." / "N workouts saved.", "Name already exists", "A workout named "X" is already saved.", "Delete workout?", ""X" will be removed. Its history is kept.", "Workout JSON copied to the clipboard.", and the "could not be saved / loaded / deleted / added" errors.
- 2026-10-08 — `build_runner` 2.16 removed `--delete-conflicting-outputs`; the commands in AGENTS.md §3 and the README are updated.

## M3 — Player and rest timer

- 2026-10-08 — `tick()` returns `SetLog?`: the log of a timed set it auto-completed, so the provider can save it like `completeSet`'s (AGENTS.md §5.3).
- 2026-10-08 — `SessionController` takes an optional `startedAt` (the session row's start time) (AGENTS.md §5.3).
- 2026-10-08 — Intents that do not apply in the current phase throw `StateError`; the UI only offers the ones that apply. Selecting a finished exercise is ignored (AGENTS.md §7.2).
- 2026-10-08 — The rest view has **Change exercise**, a list of unfinished exercises; it is the UI path to selecting during rest (AGENTS.md §7.2).
- 2026-10-08 — Finish asks for confirmation only when sets remain (AGENTS.md §7.2).
- 2026-10-08 — Rest alert rules live in `PlayerNotifier`: schedule when rest starts, reschedule on +15 s or when the next exercise changes, cancel on Skip and Finish, and do nothing when rest simply runs out.
- 2026-10-08 — Rest alert channels use `AndroidNotificationCategory.alarm` with max importance. Sound and vibration are both on until settings exist (M5).
- 2026-10-08 — Exact alarms: if not allowed, Start shows "Rest alerts may arrive late. Allow alarms for on-time alerts." with **Allow** (opens the system setting). Otherwise alerts are scheduled inexact.
- 2026-10-08 — The session row is created when Start is tapped, in M3 rather than M4, because the player route needs its id. Until M4, logged sets live only in memory: leaving the player loses them, and Finish returns to `/` (no summary yet).
- 2026-10-08 — Timed exercises: **Start** runs the countdown and **Done** stops it early. There are no weight controls; the exercise's JSON weight is logged. On auto-complete the phone vibrates (`HapticFeedback.vibrate`).
- 2026-10-08 — Steppers: reps 0–200 in steps of 1; weight 0–2000 in steps of 2.5 kg / 5 lb; each stepper is labelled ("Reps", "Weight"). Stepper values carry over to the next set of the same exercise.
- 2026-10-08 — The player rebuilds only when the clock moved, so the 250 ms ticker costs nothing when time is frozen in tests.
- 2026-10-08 — New copy: "Rest", "Change exercise", "Finish workout?", "N sets are not done.", "Leave", "Workout finished.", "Set N", "N reps", "Add weight", "This workout could not be opened / started.", "Rest alerts" (channel), "Tells you when a rest is over." (channel description).
- 2026-10-08 — An architecture test enforces §5.2: no package imports in models and domain folders, and no `DateTime.now()` outside `SystemClock`.
