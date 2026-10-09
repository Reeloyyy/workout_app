import '../models/exercise.dart';

/// "60", "62.5" — no trailing ".0".
String formatWeight(double weight) {
  if (weight == weight.truncateToDouble()) return weight.toInt().toString();
  return weight.toString();
}

/// "60 kg".
String formatWeightWithUnit(double weight, WeightUnit unit) =>
    '${formatWeight(weight)} ${unit.name}';

/// Target as the player shows it: "4 × 6–8 @ 60 kg", "3 × 10", "3 × 45 s".
String formatTarget(Exercise exercise) {
  final buffer = StringBuffer('${exercise.sets} × ');
  switch (exercise.type) {
    case ExerciseType.reps:
      buffer.write(exercise.reps ?? '?');
      final repsMax = exercise.repsMax;
      if (repsMax != null && repsMax != exercise.reps) {
        buffer.write('–$repsMax');
      }
    case ExerciseType.timed:
      buffer.write('${exercise.durationSeconds ?? '?'} s');
  }
  final weight = exercise.weight;
  if (weight != null) {
    buffer.write(' @ ${formatWeightWithUnit(weight, exercise.unit)}');
  }
  return buffer.toString();
}

/// "Rest 90 s".
String formatRest(int seconds) => 'Rest $seconds s';
