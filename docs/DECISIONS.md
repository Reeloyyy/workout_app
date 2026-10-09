# Decisions

One line per decision. Decisions that change the spec are also written into `docs/AGENTS.md`.

## Project

- 2026-10-08 — Earlier FitTrack prototype archived on branch `archive/fittrack`; app rebuilt from scratch.
- 2026-10-08 — Flutter app is the repo root (no `workout/` subfolder). Package name `workout_app`.
- 2026-10-08 — App ID `io.github.reeloyyy.workoutapp` on Android and iOS. Do not change it: data is tied to it.
- 2026-10-08 — Display name "Workout App" on both platforms.
- 2026-10-08 — Installed Flutter 3.41.9 pins `meta 1.17.0`, so pub resolves `flutter_riverpod` 2.6.1 and `drift` 2.34.x (newest compatible). Riverpod 2.6 has `Notifier`/`AsyncNotifier`, which is all §4 needs. Revisit after a `flutter upgrade`.
- 2026-10-08 — Android AGP raised to 8.12.1 (minimum for `wakelock_plus`; ≥ 8.11.1 required by `flutter_local_notifications`).
- 2026-10-08 — iOS deployment target raised to 14.0 (required by `file_picker`).
- 2026-10-08 — Exact alarms use `SCHEDULE_EXACT_ALARM` (user-grantable), not `USE_EXACT_ALARM`; inexact fallback when not granted.
- 2026-10-08 — `main.dart` does not initialise timezone or notifications yet; added in M3/M5 when first used.
- 2026-10-08 — Verification is Android-only (real phone for lock-screen/battery-saver/reboot, emulator for UI). iOS is configured, not run.

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
