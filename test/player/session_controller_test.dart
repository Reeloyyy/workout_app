import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/player/domain/session_controller.dart';
import 'package:workout_app/features/player/domain/session_state.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/set_log.dart';
import 'package:workout_app/models/workout.dart';

import '../helpers/fake_clock.dart';

/// Bench (2 sets, rest 120) · OHP (1 set, workout default rest) ·
/// Plank (2 × 45 s timed, rest 60).
Workout workout({int defaultRest = 90}) => Workout(
  name: 'Push',
  defaultRestSeconds: defaultRest,
  exercises: const [
    Exercise(
      name: 'Bench',
      sets: 2,
      reps: 6,
      weight: 60,
      unit: WeightUnit.kg,
      restSeconds: 120,
    ),
    Exercise(name: 'OHP', sets: 1, reps: 10, unit: WeightUnit.kg),
    Exercise(
      name: 'Plank',
      type: ExerciseType.timed,
      sets: 2,
      durationSeconds: 45,
      unit: WeightUnit.kg,
      restSeconds: 60,
    ),
  ],
);

const bench = 0;
const ohp = 1;
const plank = 2;

void main() {
  late FakeClock clock;
  late DateTime start;

  setUp(() {
    start = DateTime(2026, 10, 8, 18);
    clock = FakeClock(start);
  });

  SessionController controllerFor(Workout w) =>
      SessionController(workout: w, clock: clock);

  /// Completes one set of [index] and skips any rest that follows.
  void doSet(SessionController c, int index) {
    if (c.state.activeExerciseIndex != index) c.selectExercise(index);
    if (c.state.activeExercise!.type == ExerciseType.timed) {
      c.startTimedSet();
      clock.advance(const Duration(seconds: 45));
      c.tick();
    } else {
      c.completeSet();
    }
    if (c.state.phase == SessionPhase.resting) c.skipRest();
  }

  group('start', () {
    test('idle with nothing active; first exercise is highlighted', () {
      final c = controllerFor(workout());
      expect(c.state.phase, SessionPhase.idle);
      expect(c.state.activeExerciseIndex, isNull);
      expect(c.state.nextUnfinishedIndex, bench);
      expect(c.state.startedAt, start);
      expect(c.state.totalSets, 5);
    });

    test('selectExercise starts performing', () {
      final c = controllerFor(workout())..selectExercise(bench);
      expect(c.state.phase, SessionPhase.performing);
      expect(c.state.activeExerciseIndex, bench);
    });

    test('selecting an index out of range throws', () {
      expect(
        () => controllerFor(workout()).selectExercise(3),
        throwsRangeError,
      );
    });
  });

  group('completeSet', () {
    test('returns the log and starts the exercise rest', () {
      final c = controllerFor(workout())..selectExercise(bench);
      clock.advance(const Duration(minutes: 1));

      final log = c.completeSet(reps: 8, weight: 62.5);

      expect(
        log,
        SetLog(
          exercisePosition: bench,
          exerciseName: 'Bench',
          setNumber: 1,
          reps: 8,
          weight: 62.5,
          unit: WeightUnit.kg,
          completedAt: start.add(const Duration(minutes: 1)),
        ),
      );
      expect(c.state.logs, [log]);
      expect(c.state.phase, SessionPhase.resting);
      expect(c.state.restEndsAt, clock.now().add(const Duration(seconds: 120)));
      expect(c.state.restTotal, const Duration(seconds: 120));
    });

    test('reps default to the target; no weight means no unit', () {
      final c = controllerFor(workout())..selectExercise(ohp);
      final log = c.completeSet();
      expect(log.reps, 10);
      expect(log.weight, isNull);
      expect(log.unit, isNull);
    });

    test('set numbers count up per exercise', () {
      final c = controllerFor(workout())..selectExercise(bench);
      expect(c.completeSet().setNumber, 1);
      c.skipRest();
      expect(c.completeSet().setNumber, 2);
    });

    test('throws when nothing is being performed', () {
      expect(() => controllerFor(workout()).completeSet(), throwsStateError);
    });
  });

  group('rest duration', () {
    test('exercise restSeconds wins', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      expect(c.state.restTotal, const Duration(seconds: 120));
    });

    test('falls back to the workout default', () {
      final c = controllerFor(workout(defaultRest: 75))..selectExercise(bench);
      doSet(c, bench);
      doSet(c, bench);
      c.selectExercise(ohp);
      c.completeSet();
      expect(c.state.restTotal, const Duration(seconds: 75));
    });

    test('the workout default is 90 s unless the JSON sets it', () {
      final c = controllerFor(workout())..selectExercise(ohp);
      c.completeSet();
      expect(c.state.restTotal, const Duration(seconds: 90));
    });

    test('rest of 0 s skips resting', () {
      final c = controllerFor(workout(defaultRest: 0))..selectExercise(ohp);
      c.completeSet();
      expect(c.state.phase, SessionPhase.idle);
      expect(c.state.restEndsAt, isNull);
    });

    test('rest of 0 s with sets left goes straight to the next set', () {
      final w = workout().copyWith(
        exercises: [workout().exercises[bench].copyWith(restSeconds: 0)],
      );
      final c = controllerFor(w)..selectExercise(bench);
      c.completeSet();
      expect(c.state.phase, SessionPhase.performing);
      expect(c.state.activeExerciseIndex, bench);
    });
  });

  group('next step after rest', () {
    test('sets left: performing the same exercise', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      c.skipRest();
      expect(c.state.phase, SessionPhase.performing);
      expect(c.state.activeExerciseIndex, bench);
    });

    test('last set of a non-final exercise still rests, then goes idle', () {
      final c = controllerFor(workout())..selectExercise(ohp);
      c.completeSet();
      expect(c.state.phase, SessionPhase.resting);
      expect(c.state.upNextIndex, bench, reason: 'first unfinished');

      c.skipRest();
      expect(c.state.phase, SessionPhase.idle);
      expect(c.state.activeExerciseIndex, isNull);
      expect(c.state.isExerciseDone(ohp), isTrue);
      expect(c.state.nextUnfinishedIndex, bench);
    });

    test('no rest after the final set of the whole workout', () {
      final c = controllerFor(workout());
      doSet(c, bench);
      doSet(c, bench);
      doSet(c, plank);
      doSet(c, plank);
      clock.advance(const Duration(minutes: 1));
      c.selectExercise(ohp);
      c.completeSet();

      expect(c.state.phase, SessionPhase.finished);
      expect(c.state.restEndsAt, isNull);
      expect(c.state.finishedAt, clock.now());
      expect(c.state.logs, hasLength(5));
    });
  });

  group('any order', () {
    test('exercises can be done in any order', () {
      final c = controllerFor(workout());
      doSet(c, plank);
      doSet(c, ohp);
      doSet(c, bench);
      doSet(c, plank);
      expect(c.state.phase, isNot(SessionPhase.finished));
      doSet(c, bench);
      expect(c.state.phase, SessionPhase.finished);
      expect(c.state.logs.map((l) => l.exerciseName), [
        'Plank',
        'OHP',
        'Bench',
        'Plank',
        'Bench',
      ]);
    });

    test('switching exercise mid-way keeps both counts', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      c.skipRest();
      c.selectExercise(ohp);
      expect(c.state.phase, SessionPhase.performing);
      expect(c.state.setsDone(bench), 1);
      expect(c.state.isExerciseDone(bench), isFalse);
    });

    test('a finished exercise cannot be selected', () {
      final c = controllerFor(workout());
      doSet(c, ohp);
      c.selectExercise(ohp);
      expect(c.state.phase, SessionPhase.idle);
      expect(c.state.activeExerciseIndex, isNull);
    });

    test('selecting during rest keeps resting; that exercise comes next', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      final restEndsAt = c.state.restEndsAt;

      c.selectExercise(plank);
      expect(c.state.phase, SessionPhase.resting);
      expect(c.state.restEndsAt, restEndsAt);
      expect(c.state.upNextIndex, plank);

      c.skipRest();
      expect(c.state.phase, SessionPhase.performing);
      expect(c.state.activeExerciseIndex, plank);
    });
  });

  group('rest timer', () {
    test('tick before the end keeps resting', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      clock.advance(const Duration(seconds: 119));
      expect(c.tick(), isNull);
      expect(c.state.phase, SessionPhase.resting);
      expect(c.state.restRemaining(clock.now()), const Duration(seconds: 1));
    });

    test('tick at the end moves on', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      clock.advance(const Duration(seconds: 120));
      c.tick();
      expect(c.state.phase, SessionPhase.performing);
      expect(c.state.restEndsAt, isNull);
    });

    test('remaining time is computed from the clock (phone locked)', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      // No ticks while locked; on unlock the remaining time is still right.
      clock.advance(const Duration(seconds: 100));
      expect(c.state.restRemaining(clock.now()), const Duration(seconds: 20));
      clock.advance(const Duration(minutes: 5));
      expect(c.state.restRemaining(clock.now()), Duration.zero);
      c.tick();
      expect(c.state.phase, SessionPhase.performing);
    });

    test('+15 s moves the end time', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      final end = c.state.restEndsAt!;
      c.addRestTime(const Duration(seconds: 15));
      expect(c.state.restEndsAt, end.add(const Duration(seconds: 15)));
      expect(c.state.restTotal, const Duration(seconds: 135));

      clock.advance(const Duration(seconds: 120));
      c.tick();
      expect(c.state.phase, SessionPhase.resting);
      clock.advance(const Duration(seconds: 15));
      c.tick();
      expect(c.state.phase, SessionPhase.performing);
    });

    test('skip and +15 s throw when not resting', () {
      final c = controllerFor(workout());
      expect(c.skipRest, throwsStateError);
      expect(
        () => c.addRestTime(const Duration(seconds: 15)),
        throwsStateError,
      );
    });
  });

  group('timed sets', () {
    test('countdown auto-completes at zero with the full duration', () {
      final c = controllerFor(workout())..selectExercise(plank);
      c.startTimedSet();
      expect(c.state.isTimedSetRunning, isTrue);
      clock.advance(const Duration(seconds: 44));
      expect(c.tick(), isNull);
      expect(
        c.state.timedSetRemaining(clock.now()),
        const Duration(seconds: 1),
      );

      clock.advance(const Duration(seconds: 1));
      final log = c.tick();
      expect(log?.durationSeconds, 45);
      expect(log?.reps, isNull);
      expect(c.state.isTimedSetRunning, isFalse);
      expect(c.state.phase, SessionPhase.resting);
      expect(c.state.restTotal, const Duration(seconds: 60));
    });

    test('Done early logs the actual seconds', () {
      final c = controllerFor(workout())..selectExercise(plank);
      c.startTimedSet();
      clock.advance(const Duration(seconds: 30, milliseconds: 400));
      expect(c.completeSet().durationSeconds, 30);
    });

    test('Done without a countdown logs the target', () {
      final c = controllerFor(workout())..selectExercise(plank);
      expect(c.completeSet().durationSeconds, 45);
    });

    test('a countdown that ran while the phone was locked completes once', () {
      final c = controllerFor(workout())..selectExercise(plank);
      c.startTimedSet();
      clock.advance(const Duration(minutes: 3));
      expect(c.tick()?.durationSeconds, 45);
      expect(c.tick(), isNull);
      expect(c.state.logs, hasLength(1));
    });

    test('startTimedSet rejects reps exercises and double starts', () {
      final c = controllerFor(workout())..selectExercise(bench);
      expect(c.startTimedSet, throwsStateError);
      c.selectExercise(plank);
      c.startTimedSet();
      expect(c.startTimedSet, throwsStateError);
    });

    test('switching exercise cancels a running countdown', () {
      final c = controllerFor(workout())..selectExercise(plank);
      c.startTimedSet();
      c.selectExercise(bench);
      expect(c.state.isTimedSetRunning, isFalse);
      clock.advance(const Duration(minutes: 1));
      expect(c.tick(), isNull);
      expect(c.state.logs, isEmpty);
    });
  });

  group('finish', () {
    test('from idle', () {
      final c = controllerFor(workout())..finish();
      expect(c.state.phase, SessionPhase.finished);
      expect(c.state.finishedAt, start);
    });

    test('during rest clears the rest', () {
      final c = controllerFor(workout())..selectExercise(bench);
      c.completeSet();
      clock.advance(const Duration(seconds: 10));
      c.finish();
      expect(c.state.phase, SessionPhase.finished);
      expect(c.state.restEndsAt, isNull);
      expect(
        c.state.elapsed(clock.now().add(const Duration(hours: 1))),
        const Duration(seconds: 10),
        reason: 'elapsed stops at finish',
      );
    });

    test('nothing can be selected after finishing; finish is idempotent', () {
      final c = controllerFor(workout())..finish();
      expect(() => c.selectExercise(bench), throwsStateError);
      final state = c.state;
      clock.advance(const Duration(minutes: 1));
      c.finish();
      expect(c.state, same(state));
    });
  });

  test('changes emits each new state, not repeats', () async {
    final c = controllerFor(workout());
    final phases = <SessionPhase>[];
    c.changes.listen((s) => phases.add(s.phase));

    c.selectExercise(bench);
    c.selectExercise(bench);
    c.completeSet();
    c.tick();
    c.skipRest();
    c.finish();
    await c.dispose();

    expect(phases, [
      SessionPhase.performing,
      SessionPhase.resting,
      SessionPhase.performing,
      SessionPhase.finished,
    ]);
  });

  test('resumeFrom continues from a saved state', () {
    final first = controllerFor(workout())..selectExercise(bench);
    first.completeSet();
    final resumed = SessionController(
      workout: workout(),
      clock: clock,
      resumeFrom: first.state,
    );
    expect(resumed.state, first.state);
    clock.advance(const Duration(seconds: 120));
    resumed.tick();
    expect(resumed.state.phase, SessionPhase.performing);
  });
}
