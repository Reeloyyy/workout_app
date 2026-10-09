import 'equality.dart';
import 'exercise.dart';

class Workout {
  Workout({
    required this.name,
    this.description,
    List<String> tags = const [],
    this.defaultRestSeconds = defaultRest,
    required List<Exercise> exercises,
  }) : tags = List.unmodifiable(tags),
       exercises = List.unmodifiable(exercises);

  /// Rest used when neither the exercise nor the workout sets one.
  static const int defaultRest = 90;

  final String name;
  final String? description;
  final List<String> tags;
  final int defaultRestSeconds;
  final List<Exercise> exercises;

  /// Rest after a set of [exercise]: the exercise's own rest, else the
  /// workout default.
  int restSecondsFor(Exercise exercise) =>
      exercise.restSeconds ?? defaultRestSeconds;

  Workout copyWith({
    String? name,
    Object? description = unset,
    List<String>? tags,
    int? defaultRestSeconds,
    List<Exercise>? exercises,
  }) {
    return Workout(
      name: name ?? this.name,
      description: identical(description, unset)
          ? this.description
          : description as String?,
      tags: tags ?? this.tags,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      exercises: exercises ?? this.exercises,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Workout &&
      other.name == name &&
      other.description == description &&
      sameItems(other.tags, tags) &&
      other.defaultRestSeconds == defaultRestSeconds &&
      sameItems(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(
    name,
    description,
    Object.hashAll(tags),
    defaultRestSeconds,
    Object.hashAll(exercises),
  );

  @override
  String toString() => 'Workout($name, ${exercises.length} exercises)';
}
