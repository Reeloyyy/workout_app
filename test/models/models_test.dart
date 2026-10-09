import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/workout.dart';

void main() {
  const bench = Exercise(
    name: 'Bench Press',
    sets: 4,
    reps: 6,
    repsMax: 8,
    weight: 60,
    unit: WeightUnit.kg,
    restSeconds: 120,
  );

  group('Exercise', () {
    test('equal when all fields are equal', () {
      expect(bench, bench.copyWith());
      expect(bench.hashCode, bench.copyWith().hashCode);
      expect(bench, isNot(bench.copyWith(sets: 5)));
    });

    test('copyWith can clear nullable fields', () {
      final cleared = bench.copyWith(weight: null, restSeconds: null);
      expect(cleared.weight, isNull);
      expect(cleared.restSeconds, isNull);
      expect(cleared.reps, 6, reason: 'untouched fields keep their value');
    });
  });

  group('Workout', () {
    Workout pushDay() =>
        Workout(name: 'Push Day A', tags: ['push'], exercises: [bench]);

    test('equal when fields and lists are equal', () {
      expect(pushDay(), pushDay());
      expect(pushDay().hashCode, pushDay().hashCode);
      expect(pushDay(), isNot(pushDay().copyWith(tags: ['pull'])));
      expect(
        pushDay(),
        isNot(pushDay().copyWith(exercises: [bench.copyWith(sets: 3)])),
      );
    });

    test('lists cannot be modified', () {
      expect(() => pushDay().exercises.add(bench), throwsUnsupportedError);
      expect(() => pushDay().tags.add('x'), throwsUnsupportedError);
    });

    test('rest falls back to the workout default', () {
      final workout = pushDay().copyWith(defaultRestSeconds: 75);
      expect(workout.restSecondsFor(bench), 120);
      expect(workout.restSecondsFor(bench.copyWith(restSeconds: null)), 75);
      expect(Workout.defaultRest, 90);
    });

    test('copyWith can clear the description', () {
      final workout = pushDay().copyWith(description: 'x');
      expect(workout.copyWith(description: null).description, isNull);
    });
  });
}
