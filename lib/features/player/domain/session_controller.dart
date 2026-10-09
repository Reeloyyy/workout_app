import 'dart:async';

import '../../../core/clock.dart';
import '../../../models/exercise.dart';
import '../../../models/set_log.dart';
import '../../../models/workout.dart';
import 'rest_duration.dart';
import 'session_state.dart';

/// The workout player's state machine (AGENTS.md §7.2). Pure Dart, so a
/// future watch app can drive it too.
///
/// ```
/// idle ──selectExercise──▶ performing ──completeSet──▶ resting
/// resting ──(time up | skip)──▶ next step:
///   exercise has sets left    → performing (same exercise)
///   exercise has no sets left → idle (next unfinished exercise highlighted)
///   no sets left at all       → finished (no rest)
/// any state ──finish──▶ finished
/// ```
///
/// Calling an intent that does not apply in the current phase throws a
/// [StateError]; the UI only offers intents that apply.
class SessionController {
  SessionController({
    required Workout workout,
    required Clock clock,
    DateTime? startedAt,
    SessionState? resumeFrom,
  }) : _clock = clock,
       _state =
           resumeFrom ??
           SessionState(workout: workout, startedAt: startedAt ?? clock.now());

  final Clock _clock;
  final StreamController<SessionState> _changes = StreamController.broadcast(
    sync: true,
  );
  SessionState _state;

  SessionState get state => _state;

  /// Emits each new state after a change.
  Stream<SessionState> get changes => _changes.stream;

  Workout get _workout => _state.workout;

  /// Makes [exerciseIndex] the active exercise. During rest the rest
  /// continues and this exercise comes next. Exercises with no sets left
  /// cannot be selected (no-op).
  void selectExercise(int exerciseIndex) {
    RangeError.checkValidIndex(exerciseIndex, _workout.exercises);
    _requireNotFinished();
    if (_state.isExerciseDone(exerciseIndex)) return;
    if (_state.phase == SessionPhase.resting) {
      _emit(_state.copyWith(activeExerciseIndex: exerciseIndex));
      return;
    }
    _emit(
      _state.copyWith(
        phase: SessionPhase.performing,
        activeExerciseIndex: exerciseIndex,
        timedSetStartedAt: null,
        timedSetEndsAt: null,
      ),
    );
  }

  /// Starts the countdown of the active timed exercise.
  void startTimedSet() {
    final exercise = _requirePerforming();
    if (exercise.type != ExerciseType.timed) {
      throw StateError('${exercise.name} is not a timed exercise');
    }
    if (_state.isTimedSetRunning) throw StateError('Timed set already running');
    final now = _clock.now();
    _emit(
      _state.copyWith(
        timedSetStartedAt: now,
        timedSetEndsAt: now.add(
          Duration(seconds: exercise.durationSeconds ?? 0),
        ),
      ),
    );
  }

  /// Logs the next set of the active exercise and moves on: rest, the next
  /// set, idle, or finished. Returns the log so it can be saved at once.
  ///
  /// Reps exercises: [reps] defaults to the target. Timed exercises:
  /// [durationSeconds] defaults to the time since [startTimedSet] (capped at
  /// the target), or the target if no countdown ran.
  SetLog completeSet({int? reps, double? weight, int? durationSeconds}) {
    final exercise = _requirePerforming();
    final index = _state.activeExerciseIndex!;
    final now = _clock.now();
    final isTimed = exercise.type == ExerciseType.timed;

    final log = SetLog(
      exercisePosition: index,
      exerciseName: exercise.name,
      setNumber: _state.setsDone(index) + 1,
      reps: isTimed ? null : reps ?? exercise.reps,
      weight: weight,
      unit: weight == null ? null : exercise.unit,
      durationSeconds: isTimed
          ? durationSeconds ?? _timedSetSeconds(exercise, now)
          : null,
      completedAt: now,
    );

    final logged = _state.copyWith(
      logs: [..._state.logs, log],
      timedSetStartedAt: null,
      timedSetEndsAt: null,
    );
    if (logged.allSetsDone) {
      _emit(_finished(logged, now));
      return log;
    }
    final rest = restAfterSet(_workout, index);
    if (rest == Duration.zero) {
      _emit(_nextStep(logged));
    } else {
      _emit(
        logged.copyWith(
          phase: SessionPhase.resting,
          restStartedAt: now,
          restEndsAt: now.add(rest),
        ),
      );
    }
    return log;
  }

  void skipRest() {
    _requireResting();
    _emit(_nextStep(_state));
  }

  /// Moves the end of the current rest by [extra] (the +15 s button).
  void addRestTime(Duration extra) {
    _requireResting();
    _emit(_state.copyWith(restEndsAt: _state.restEndsAt!.add(extra)));
  }

  /// Called about four times a second by the UI and when the app resumes.
  /// Ends rest when it is due and auto-completes a timed set at zero.
  /// Returns the auto-completed set's log, if any.
  SetLog? tick() {
    final now = _clock.now();
    final timedEnd = _state.timedSetEndsAt;
    if (_state.phase == SessionPhase.performing &&
        timedEnd != null &&
        !now.isBefore(timedEnd)) {
      final exercise = _state.activeExercise!;
      return completeSet(durationSeconds: exercise.durationSeconds);
    }
    final restEnd = _state.restEndsAt;
    if (_state.phase == SessionPhase.resting &&
        restEnd != null &&
        !now.isBefore(restEnd)) {
      _emit(_nextStep(_state));
    }
    return null;
  }

  void finish() {
    if (_state.phase == SessionPhase.finished) return;
    _emit(_finished(_state, _clock.now()));
  }

  Future<void> dispose() => _changes.close();

  SessionState _nextStep(SessionState from) {
    final cleared = from.copyWith(restStartedAt: null, restEndsAt: null);
    final active = from.activeExerciseIndex;
    if (active != null && !from.isExerciseDone(active)) {
      return cleared.copyWith(phase: SessionPhase.performing);
    }
    return cleared.copyWith(
      phase: SessionPhase.idle,
      activeExerciseIndex: null,
    );
  }

  SessionState _finished(SessionState from, DateTime now) => from.copyWith(
    phase: SessionPhase.finished,
    finishedAt: now,
    restStartedAt: null,
    restEndsAt: null,
    timedSetStartedAt: null,
    timedSetEndsAt: null,
  );

  int _timedSetSeconds(Exercise exercise, DateTime now) {
    final target = exercise.durationSeconds ?? 0;
    final started = _state.timedSetStartedAt;
    if (started == null) return target;
    final seconds = (now.difference(started).inMilliseconds / 1000).round();
    return seconds.clamp(0, target);
  }

  Exercise _requirePerforming() {
    if (_state.phase != SessionPhase.performing) {
      throw StateError('No exercise is being performed (${_state.phase.name})');
    }
    return _state.activeExercise!;
  }

  void _requireResting() {
    if (_state.phase != SessionPhase.resting) {
      throw StateError('Not resting (${_state.phase.name})');
    }
  }

  void _requireNotFinished() {
    if (_state.phase == SessionPhase.finished) {
      throw StateError('The session is finished');
    }
  }

  void _emit(SessionState next) {
    if (next == _state) return;
    _state = next;
    _changes.add(next);
  }
}
