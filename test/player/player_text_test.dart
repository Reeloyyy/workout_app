import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/core/format.dart';
import 'package:workout_app/features/player/domain/player_text.dart';
import 'package:workout_app/features/player/domain/session_controller.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/set_log.dart';
import 'package:workout_app/models/workout.dart';

import '../helpers/fake_clock.dart';

void main() {
  final workout = Workout(
    name: 'Push',
    exercises: const [
      Exercise(
        name: 'Bench Press',
        sets: 4,
        reps: 6,
        repsMax: 8,
        weight: 60,
        unit: WeightUnit.kg,
      ),
      Exercise(
        name: 'Plank',
        type: ExerciseType.timed,
        sets: 1,
        durationSeconds: 45,
        unit: WeightUnit.kg,
      ),
    ],
  );

  test('rest alert body and up-next label name the next set', () {
    final c = SessionController(
      workout: workout,
      clock: FakeClock(DateTime(2026)),
    )..selectExercise(0);
    c.completeSet();
    c.skipRest();
    c.completeSet();
    expect(restAlertBody(c.state), 'Set 3 of 4 — Bench Press');
    expect(upNextLabel(c.state), 'Up next: Bench Press — set 3 of 4');
  });

  test('after the last set of an exercise, up next is the next unfinished', () {
    final c = SessionController(
      workout: workout,
      clock: FakeClock(DateTime(2026)),
    )..selectExercise(0);
    for (var i = 0; i < 3; i++) {
      c.completeSet();
      c.skipRest();
    }
    c.completeSet();
    expect(restAlertBody(c.state), 'Set 1 of 1 — Plank');
  });

  test('formatSetLog', () {
    SetLog log({int? reps, double? weight, WeightUnit? unit, int? seconds}) =>
        SetLog(
          exercisePosition: 0,
          exerciseName: 'x',
          setNumber: 1,
          reps: reps,
          weight: weight,
          unit: unit,
          durationSeconds: seconds,
          completedAt: DateTime(2026),
        );
    expect(
      formatSetLog(log(reps: 8, weight: 60, unit: WeightUnit.kg)),
      '60 kg × 8',
    );
    expect(formatSetLog(log(reps: 8)), '× 8');
    expect(formatSetLog(log(seconds: 45)), '45 s');
  });

  test('formatSetTarget', () {
    expect(formatSetTarget(workout.exercises[0]), '6–8 reps @ 60 kg');
    expect(formatSetTarget(workout.exercises[1]), '45 s');
  });

  test('formatClock rounds partial seconds up', () {
    expect(formatClock(const Duration(seconds: 120)), '2:00');
    expect(formatClock(const Duration(milliseconds: 400)), '0:01');
    expect(formatClock(Duration.zero), '0:00');
    expect(
      formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
