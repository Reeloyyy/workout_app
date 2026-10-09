import '../../../models/equality.dart';
import '../../../models/exercise.dart';
import '../../../models/set_log.dart';
import '../../../models/workout.dart';

enum SessionPhase { idle, performing, resting, finished }

/// Immutable snapshot of a workout in progress.
///
/// Times are absolute ([restEndsAt], [timedSetEndsAt]); remaining time is
/// always computed from "now", never counted down.
class SessionState {
  SessionState({
    required this.workout,
    required this.startedAt,
    this.phase = SessionPhase.idle,
    this.activeExerciseIndex,
    List<SetLog> logs = const [],
    this.restStartedAt,
    this.restEndsAt,
    this.timedSetStartedAt,
    this.timedSetEndsAt,
    this.finishedAt,
  }) : logs = List.unmodifiable(logs);

  final Workout workout;
  final DateTime startedAt;
  final SessionPhase phase;

  /// The exercise being performed, or chosen during rest. Null when idle.
  final int? activeExerciseIndex;
  final List<SetLog> logs;
  final DateTime? restStartedAt;
  final DateTime? restEndsAt;

  /// Set while a timed set's countdown runs.
  final DateTime? timedSetStartedAt;
  final DateTime? timedSetEndsAt;
  final DateTime? finishedAt;

  Exercise? get activeExercise {
    final index = activeExerciseIndex;
    return index == null ? null : workout.exercises[index];
  }

  int setsDone(int exerciseIndex) =>
      logs.where((log) => log.exercisePosition == exerciseIndex).length;

  bool isExerciseDone(int exerciseIndex) =>
      setsDone(exerciseIndex) >= workout.exercises[exerciseIndex].sets;

  bool get allSetsDone {
    for (var i = 0; i < workout.exercises.length; i++) {
      if (!isExerciseDone(i)) return false;
    }
    return true;
  }

  int get totalSets =>
      workout.exercises.fold(0, (sum, exercise) => sum + exercise.sets);

  /// First unfinished exercise in list order; highlighted when idle.
  int? get nextUnfinishedIndex {
    for (var i = 0; i < workout.exercises.length; i++) {
      if (!isExerciseDone(i)) return i;
    }
    return null;
  }

  /// What comes after the current rest: the active exercise if it has sets
  /// left, otherwise the first unfinished exercise.
  int? get upNextIndex {
    final active = activeExerciseIndex;
    if (active != null && !isExerciseDone(active)) return active;
    return nextUnfinishedIndex;
  }

  bool get isTimedSetRunning => timedSetEndsAt != null;

  Duration restRemaining(DateTime now) => _remaining(restEndsAt, now);

  Duration get restTotal {
    final start = restStartedAt;
    final end = restEndsAt;
    return start == null || end == null ? Duration.zero : end.difference(start);
  }

  Duration timedSetRemaining(DateTime now) => _remaining(timedSetEndsAt, now);

  Duration elapsed(DateTime now) => (finishedAt ?? now).difference(startedAt);

  static Duration _remaining(DateTime? end, DateTime now) {
    if (end == null) return Duration.zero;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  SessionState copyWith({
    SessionPhase? phase,
    Object? activeExerciseIndex = unset,
    List<SetLog>? logs,
    Object? restStartedAt = unset,
    Object? restEndsAt = unset,
    Object? timedSetStartedAt = unset,
    Object? timedSetEndsAt = unset,
    Object? finishedAt = unset,
  }) {
    return SessionState(
      workout: workout,
      startedAt: startedAt,
      phase: phase ?? this.phase,
      activeExerciseIndex: identical(activeExerciseIndex, unset)
          ? this.activeExerciseIndex
          : activeExerciseIndex as int?,
      logs: logs ?? this.logs,
      restStartedAt: identical(restStartedAt, unset)
          ? this.restStartedAt
          : restStartedAt as DateTime?,
      restEndsAt: identical(restEndsAt, unset)
          ? this.restEndsAt
          : restEndsAt as DateTime?,
      timedSetStartedAt: identical(timedSetStartedAt, unset)
          ? this.timedSetStartedAt
          : timedSetStartedAt as DateTime?,
      timedSetEndsAt: identical(timedSetEndsAt, unset)
          ? this.timedSetEndsAt
          : timedSetEndsAt as DateTime?,
      finishedAt: identical(finishedAt, unset)
          ? this.finishedAt
          : finishedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionState &&
      other.workout == workout &&
      other.startedAt == startedAt &&
      other.phase == phase &&
      other.activeExerciseIndex == activeExerciseIndex &&
      sameItems(other.logs, logs) &&
      other.restStartedAt == restStartedAt &&
      other.restEndsAt == restEndsAt &&
      other.timedSetStartedAt == timedSetStartedAt &&
      other.timedSetEndsAt == timedSetEndsAt &&
      other.finishedAt == finishedAt;

  @override
  int get hashCode => Object.hash(
    workout,
    startedAt,
    phase,
    activeExerciseIndex,
    Object.hashAll(logs),
    restStartedAt,
    restEndsAt,
    timedSetStartedAt,
    timedSetEndsAt,
    finishedAt,
  );

  @override
  String toString() =>
      'SessionState(${phase.name}, active: $activeExerciseIndex, '
      'logs: ${logs.length}, restEndsAt: $restEndsAt)';
}
