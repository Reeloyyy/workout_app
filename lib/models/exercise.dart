import 'equality.dart';

enum ExerciseType {
  reps,
  timed;

  static ExerciseType? fromJson(String value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

enum WeightUnit {
  kg,
  lb;

  static WeightUnit? fromJson(String value) {
    for (final unit in values) {
      if (unit.name == value) return unit;
    }
    return null;
  }
}

/// One exercise of a workout, as described by the workout JSON.
class Exercise {
  const Exercise({
    required this.name,
    this.type = ExerciseType.reps,
    required this.sets,
    this.reps,
    this.repsMax,
    this.durationSeconds,
    this.weight,
    required this.unit,
    this.restSeconds,
    this.notes,
    this.group,
  });

  final String name;
  final ExerciseType type;
  final int sets;

  /// Target reps, or the lower bound of a range. Reps exercises only.
  final int? reps;

  /// Upper bound of a rep range. Reps exercises only.
  final int? repsMax;

  /// Timed exercises only.
  final int? durationSeconds;
  final double? weight;

  /// Unit for [weight]. Always set (from the JSON or the app's default unit)
  /// so a weight can be added later to an exercise that has none.
  final WeightUnit unit;

  /// Overrides the workout's default rest when set.
  final int? restSeconds;
  final String? notes;

  /// Reserved for supersets. Stored, ignored by the player.
  final String? group;

  Exercise copyWith({
    String? name,
    ExerciseType? type,
    int? sets,
    Object? reps = unset,
    Object? repsMax = unset,
    Object? durationSeconds = unset,
    Object? weight = unset,
    WeightUnit? unit,
    Object? restSeconds = unset,
    Object? notes = unset,
    Object? group = unset,
  }) {
    return Exercise(
      name: name ?? this.name,
      type: type ?? this.type,
      sets: sets ?? this.sets,
      reps: identical(reps, unset) ? this.reps : reps as int?,
      repsMax: identical(repsMax, unset) ? this.repsMax : repsMax as int?,
      durationSeconds: identical(durationSeconds, unset)
          ? this.durationSeconds
          : durationSeconds as int?,
      weight: identical(weight, unset) ? this.weight : weight as double?,
      unit: unit ?? this.unit,
      restSeconds: identical(restSeconds, unset)
          ? this.restSeconds
          : restSeconds as int?,
      notes: identical(notes, unset) ? this.notes : notes as String?,
      group: identical(group, unset) ? this.group : group as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Exercise &&
      other.name == name &&
      other.type == type &&
      other.sets == sets &&
      other.reps == reps &&
      other.repsMax == repsMax &&
      other.durationSeconds == durationSeconds &&
      other.weight == weight &&
      other.unit == unit &&
      other.restSeconds == restSeconds &&
      other.notes == notes &&
      other.group == group;

  @override
  int get hashCode => Object.hash(
    name,
    type,
    sets,
    reps,
    repsMax,
    durationSeconds,
    weight,
    unit,
    restSeconds,
    notes,
    group,
  );

  @override
  String toString() => 'Exercise($name, ${type.name}, sets: $sets)';
}
