import '../../../models/exercise.dart';
import '../../../models/set_log.dart';
import '../../../core/format.dart';
import 'session_state.dart';

/// The set that follows the current rest, or null if nothing is left.
({String name, int setNumber, int sets})? upNext(SessionState state) {
  final index = state.upNextIndex;
  if (index == null) return null;
  final exercise = state.workout.exercises[index];
  return (
    name: exercise.name,
    setNumber: state.setsDone(index) + 1,
    sets: exercise.sets,
  );
}

/// Rest alert body: "Set 3 of 4 — Bench Press".
String? restAlertBody(SessionState state) {
  final next = upNext(state);
  if (next == null) return null;
  return 'Set ${next.setNumber} of ${next.sets} — ${next.name}';
}

/// Rest view line: "Up next: Bench Press — set 3 of 4".
String? upNextLabel(SessionState state) {
  final next = upNext(state);
  if (next == null) return null;
  return 'Up next: ${next.name} — set ${next.setNumber} of ${next.sets}';
}

/// A logged set: "60 kg × 8", "× 8" (no weight) or "45 s".
String formatSetLog(SetLog log) {
  final duration = log.durationSeconds;
  if (duration != null) return '$duration s';
  final weight = log.weight;
  final unit = log.unit;
  final reps = log.reps;
  final repsText = reps == null ? '' : '× $reps';
  if (weight == null || unit == null) return repsText;
  return '${formatWeightWithUnit(weight, unit)} $repsText'.trim();
}

/// The target for one set: "6–8 reps @ 60 kg", "10 reps", "45 s".
String formatSetTarget(Exercise exercise) {
  final weight = exercise.weight;
  final weightText = weight == null
      ? ''
      : ' @ ${formatWeightWithUnit(weight, exercise.unit)}';
  switch (exercise.type) {
    case ExerciseType.timed:
      return '${exercise.durationSeconds} s$weightText';
    case ExerciseType.reps:
      final repsMax = exercise.repsMax;
      final reps = repsMax != null && repsMax != exercise.reps
          ? '${exercise.reps}–$repsMax'
          : '${exercise.reps}';
      return '$reps reps$weightText';
  }
}
