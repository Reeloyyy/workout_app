import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/core/format.dart';
import 'package:workout_app/models/exercise.dart';

void main() {
  test('formatWeight drops a trailing .0', () {
    expect(formatWeight(60), '60');
    expect(formatWeight(62.5), '62.5');
  });

  test('formatTarget', () {
    expect(
      formatTarget(
        const Exercise(
          name: 'Bench',
          sets: 4,
          reps: 6,
          repsMax: 8,
          weight: 60,
          unit: WeightUnit.kg,
        ),
      ),
      '4 × 6–8 @ 60 kg',
    );
    expect(
      formatTarget(
        const Exercise(name: 'OHP', sets: 3, reps: 10, unit: WeightUnit.kg),
      ),
      '3 × 10',
    );
    expect(
      formatTarget(
        const Exercise(
          name: 'Plank',
          type: ExerciseType.timed,
          sets: 3,
          durationSeconds: 45,
          unit: WeightUnit.kg,
        ),
      ),
      '3 × 45 s',
    );
    expect(
      formatTarget(
        const Exercise(
          name: 'Dips',
          sets: 3,
          reps: 8,
          repsMax: 8,
          weight: 12.5,
          unit: WeightUnit.lb,
        ),
      ),
      '3 × 8 @ 12.5 lb',
    );
  });

  test('formatRest', () {
    expect(formatRest(90), 'Rest 90 s');
  });
}
