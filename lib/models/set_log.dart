import 'exercise.dart';

/// One completed set.
class SetLog {
  const SetLog({
    required this.exercisePosition,
    required this.exerciseName,
    required this.setNumber,
    this.reps,
    this.weight,
    this.unit,
    this.durationSeconds,
    required this.completedAt,
  });

  /// Index of the exercise in the workout.
  final int exercisePosition;
  final String exerciseName;

  /// 1-based.
  final int setNumber;
  final int? reps;
  final double? weight;

  /// Set when [weight] is.
  final WeightUnit? unit;

  /// Timed exercises only.
  final int? durationSeconds;
  final DateTime completedAt;

  @override
  bool operator ==(Object other) =>
      other is SetLog &&
      other.exercisePosition == exercisePosition &&
      other.exerciseName == exerciseName &&
      other.setNumber == setNumber &&
      other.reps == reps &&
      other.weight == weight &&
      other.unit == unit &&
      other.durationSeconds == durationSeconds &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
    exercisePosition,
    exerciseName,
    setNumber,
    reps,
    weight,
    unit,
    durationSeconds,
    completedAt,
  );

  @override
  String toString() =>
      'SetLog($exerciseName #$setNumber: reps $reps, weight $weight '
      '${unit?.name}, ${durationSeconds}s)';
}
