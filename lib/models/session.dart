import 'workout.dart';

/// A workout session as stored: the workout snapshot taken at start, so it
/// stays valid if the library workout is changed or deleted.
class Session {
  const Session({
    required this.id,
    this.workoutId,
    required this.workout,
    required this.startedAt,
    this.finishedAt,
  });

  final int id;

  /// Null once the library workout is deleted.
  final int? workoutId;
  final Workout workout;
  final DateTime startedAt;
  final DateTime? finishedAt;

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.id == id &&
      other.workoutId == workoutId &&
      other.workout == workout &&
      other.startedAt == startedAt &&
      other.finishedAt == finishedAt;

  @override
  int get hashCode =>
      Object.hash(id, workoutId, workout, startedAt, finishedAt);

  @override
  String toString() => 'Session($id, ${workout.name}, $startedAt)';
}
