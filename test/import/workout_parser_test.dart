import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/import/domain/import_error.dart';
import 'package:workout_app/features/import/domain/workout_parser.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/workout.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

ImportResult parse(String json, {WeightUnit unit = WeightUnit.kg}) =>
    parseWorkouts(json, defaultUnit: unit);

ImportSuccess expectSuccess(ImportResult result) {
  if (result is ImportFailure) {
    fail('Expected success, got errors: ${result.errors}');
  }
  return result as ImportSuccess;
}

ImportFailure expectFailure(ImportResult result) {
  expect(result, isA<ImportFailure>());
  return result as ImportFailure;
}

/// Wraps one exercise in a minimal valid document.
String withExercise(String exerciseJson) =>
    '''
{"schemaVersion": 1, "workouts": [
  {"name": "Legs", "exercises": [$exerciseJson]}
]}''';

void main() {
  group('fixtures', () {
    test('valid_push_day: 1 workout, 3 exercises, rest fallbacks', () {
      final result = expectSuccess(parse(fixture('valid_push_day.json')));
      expect(result.warnings, isEmpty);
      expect(result.workouts, hasLength(1));

      final workout = result.workouts.single;
      expect(workout.name, 'Push Day A');
      expect(workout.description, 'Chest, shoulders, triceps');
      expect(workout.tags, ['push', 'upper']);
      expect(workout.exercises, hasLength(3));

      final [bench, ohp, plank] = workout.exercises;
      expect(workout.restSecondsFor(bench), 120);
      expect(workout.restSecondsFor(ohp), 90);
      expect(workout.restSecondsFor(plank), 60);

      expect(
        bench,
        const Exercise(
          name: 'Bench Press',
          sets: 4,
          reps: 6,
          repsMax: 8,
          weight: 60,
          unit: WeightUnit.kg,
          restSeconds: 120,
          notes: 'Pause briefly on the chest',
        ),
      );
      expect(plank.type, ExerciseType.timed);
      expect(plank.durationSeconds, 45);
    });

    test('invalid_syntax: one error with line and column', () {
      final result = expectFailure(parse(fixture('invalid_syntax.json')));
      expect(result.errors, hasLength(1));
      // The trailing comma on line 7 makes the "]" on line 8 unexpected.
      expect(
        result.errors.single.message,
        'Not valid JSON (line 8, column 7): Unexpected character.',
      );
    });

    test('missing_fields: exactly 2 errors, both located', () {
      final result = expectFailure(parse(fixture('missing_fields.json')));
      expect(result.errors.map((e) => e.message), [
        'Push Day A › exercise 1 (Bench Press): `sets` is required.',
        'Push Day A › exercise 3 (Plank): '
            '`durationSeconds` is required for timed exercises.',
      ]);
      expect(result.errors.map((e) => e.path), [
        'workouts[0].exercises[0].sets',
        'workouts[0].exercises[2].durationSeconds',
      ]);
    });

    test('future_version: newer version message', () {
      final result = expectFailure(parse(fixture('future_version.json')));
      expect(result.errors, hasLength(1));
      expect(
        result.errors.single.message,
        'This file needs a newer version of the app.',
      );
    });

    test('unknown_field: success with 1 warning', () {
      final result = expectSuccess(parse(fixture('unknown_field.json')));
      expect(result.warnings, hasLength(1));
      final warning = result.warnings.single;
      expect(warning.isWarning, isTrue);
      expect(warning.path, 'workouts[0].exercises[0].tempo');
      expect(
        warning.message,
        'Push Day A › exercise 1 (Bench Press): '
        'Unknown field `tempo` was ignored.',
      );
    });

    test('bad_ranges: 3 errors', () {
      final result = expectFailure(parse(fixture('bad_ranges.json')));
      expect(result.errors.map((e) => e.path), [
        'workouts[0].exercises[0].sets',
        'workouts[0].exercises[1].repsMax',
        'workouts[0].exercises[2].restSeconds',
      ]);
      expect(result.errors.map((e) => e.message), [
        'Push Day A › exercise 1 (Bench Press): '
            '`sets` must be between 1 and 20.',
        'Push Day A › exercise 2 (Overhead Press): '
            '`repsMax` must be at least `reps` (10).',
        'Push Day A › exercise 3 (Plank): '
            '`restSeconds` must be between 0 and 600.',
      ]);
    });

    test('round trip: parse(export(parse(valid))) equals parse(valid)', () {
      final first = expectSuccess(parse(fixture('valid_push_day.json')));
      final exported = exportWorkouts(first.workouts);
      final second = expectSuccess(parse(exported));
      expect(second.workouts, first.workouts);
      expect(second.warnings, isEmpty);
    });
  });

  group('decoding', () {
    test('strips a UTF-8 BOM and surrounding whitespace', () {
      final json = '﻿  \n${fixture('valid_push_day.json')}\n\n';
      expectSuccess(parse(json));
    });

    test('empty input is not valid JSON', () {
      final result = expectFailure(parse('   '));
      expect(result.errors.single.message, startsWith('Not valid JSON'));
    });

    test('root must be an object', () {
      final result = expectFailure(parse('[]'));
      expect(result.errors, hasLength(1));
      expect(result.errors.single.message, contains('JSON object'));
    });
  });

  group('root', () {
    test('missing schemaVersion and workouts are both reported', () {
      final result = expectFailure(parse('{}'));
      expect(result.errors.map((e) => e.message), [
        '`schemaVersion` is required.',
        '`workouts` is required.',
      ]);
    });

    test('schemaVersion 0 is rejected', () {
      final result = expectFailure(
        parse(fixture('valid_push_day.json').replaceFirst(': 1,', ': 0,')),
      );
      expect(result.errors.single.message, '`schemaVersion` must be 1.');
    });

    test('empty workouts list is an error', () {
      final result = expectFailure(
        parse('{"schemaVersion": 1, "workouts": []}'),
      );
      expect(
        result.errors.single.message,
        '`workouts` must contain at least one workout.',
      );
    });

    test('unknown root field is a warning', () {
      final json = fixture(
        'valid_push_day.json',
      ).replaceFirst('"schemaVersion": 1,', '"schemaVersion": 1, "author": 1,');
      final result = expectSuccess(parse(json));
      expect(
        result.warnings.single.message,
        'Unknown field `author` was ignored.',
      );
    });
  });

  group('workout', () {
    test('missing name falls back to "Workout N" in messages', () {
      final result = expectFailure(
        parse('''
{"schemaVersion": 1, "workouts": [
  {"name": "A", "exercises": [{"name": "X", "sets": 1, "reps": 1}]},
  {"exercises": [{"name": "Squat", "reps": 5}]}
]}'''),
      );
      expect(result.errors.map((e) => e.message), [
        'Workout 2: `name` is required.',
        'Workout 2 › exercise 1 (Squat): `sets` is required.',
      ]);
    });

    test('name is trimmed and limited to 60 characters', () {
      final ok = expectSuccess(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "  Legs  ", '
          '"exercises": [{"name": "Squat", "sets": 1, "reps": 5}]}]}',
        ),
      );
      expect(ok.workouts.single.name, 'Legs');

      final long = 'x' * 61;
      final bad = expectFailure(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "$long", '
          '"exercises": [{"name": "Squat", "sets": 1, "reps": 5}]}]}',
        ),
      );
      expect(
        bad.errors.single.message,
        'Workout 1: `name` must be between 1 and 60 characters.',
      );
    });

    test('defaultRestSeconds defaults to 90 and is range checked', () {
      final ok = expectSuccess(
        parse(withExercise('{"name": "Squat", "sets": 1, "reps": 5}')),
      );
      expect(ok.workouts.single.defaultRestSeconds, 90);

      final bad = expectFailure(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "Legs", '
          '"defaultRestSeconds": 601, '
          '"exercises": [{"name": "Squat", "sets": 1, "reps": 5}]}]}',
        ),
      );
      expect(
        bad.errors.single.message,
        'Legs: `defaultRestSeconds` must be between 0 and 600.',
      );
    });

    test('tags: at most 10, each 1–30 characters', () {
      final tooMany = List.generate(11, (i) => '"t$i"').join(', ');
      final many = expectFailure(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "Legs", '
          '"tags": [$tooMany], '
          '"exercises": [{"name": "Squat", "sets": 1, "reps": 5}]}]}',
        ),
      );
      expect(
        many.errors.single.message,
        'Legs: `tags` can have at most 10 items.',
      );

      final bad = expectFailure(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "Legs", '
          '"tags": ["ok", " ", 3], '
          '"exercises": [{"name": "Squat", "sets": 1, "reps": 5}]}]}',
        ),
      );
      expect(bad.errors.map((e) => e.path), [
        'workouts[0].tags[1]',
        'workouts[0].tags[2]',
      ]);
    });

    test('description longer than 300 characters is an error', () {
      final long = 'x' * 301;
      final result = expectFailure(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "Legs", '
          '"description": "$long", '
          '"exercises": [{"name": "Squat", "sets": 1, "reps": 5}]}]}',
        ),
      );
      expect(
        result.errors.single.message,
        'Legs: `description` must be 300 characters or fewer.',
      );
    });

    test('empty exercises list is an error', () {
      final result = expectFailure(
        parse(
          '{"schemaVersion": 1, "workouts": [{"name": "Legs", '
          '"exercises": []}]}',
        ),
      );
      expect(
        result.errors.single.message,
        'Legs: `exercises` must contain at least one exercise.',
      );
    });

    test('a workout that is not an object is located', () {
      final result = expectFailure(
        parse('{"schemaVersion": 1, "workouts": [42]}'),
      );
      expect(result.errors.single.message, 'Workout 1 is not a JSON object.');
      expect(result.errors.single.path, 'workouts[0]');
    });
  });

  group('exercise', () {
    test('whole-number fields accept 90.0 and reject 90.5', () {
      final ok = expectSuccess(
        parse(
          withExercise(
            '{"name": "Squat", "sets": 3.0, "reps": 5, "restSeconds": 90.0}',
          ),
        ),
      );
      expect(ok.workouts.single.exercises.single.sets, 3);
      expect(ok.workouts.single.exercises.single.restSeconds, 90);

      final bad = expectFailure(
        parse(
          withExercise(
            '{"name": "Squat", "sets": 3, "reps": 5, "restSeconds": 90.5}',
          ),
        ),
      );
      expect(
        bad.errors.single.message,
        'Legs › exercise 1 (Squat): `restSeconds` must be a whole number.',
      );
    });

    test('wrong types are errors', () {
      final result = expectFailure(
        parse(
          withExercise(
            '{"name": 5, "sets": "3", "reps": true, "weight": "heavy", '
            '"notes": 1}',
          ),
        ),
      );
      expect(result.errors.map((e) => e.message), [
        'Legs › exercise 1: `name` must be text.',
        'Legs › exercise 1: `sets` must be a whole number.',
        'Legs › exercise 1: `reps` must be a whole number.',
        'Legs › exercise 1: `weight` must be a number.',
        'Legs › exercise 1: `notes` must be text.',
      ]);
    });

    test('type defaults to reps; unknown type is an error', () {
      final ok = expectSuccess(
        parse(withExercise('{"name": "Squat", "sets": 1, "reps": 5}')),
      );
      expect(ok.workouts.single.exercises.single.type, ExerciseType.reps);

      final bad = expectFailure(
        parse(withExercise('{"name": "Squat", "type": "amrap", "sets": 1}')),
      );
      expect(
        bad.errors.single.message,
        'Legs › exercise 1 (Squat): `type` must be "reps" or "timed".',
      );
    });

    test('reps is required for reps exercises', () {
      final result = expectFailure(
        parse(withExercise('{"name": "Squat", "sets": 1}')),
      );
      expect(
        result.errors.single.message,
        'Legs › exercise 1 (Squat): `reps` is required for reps exercises.',
      );
    });

    test('reps and repsMax ranges', () {
      final result = expectFailure(
        parse(
          withExercise(
            '{"name": "Squat", "sets": 1, "reps": 5, "repsMax": 201}',
          ),
        ),
      );
      expect(
        result.errors.single.message,
        'Legs › exercise 1 (Squat): `repsMax` must be 200 or less.',
      );

      final zero = expectFailure(
        parse(withExercise('{"name": "Squat", "sets": 1, "reps": 0}')),
      );
      expect(
        zero.errors.single.message,
        'Legs › exercise 1 (Squat): `reps` must be between 1 and 200.',
      );
    });

    test('reps on a timed exercise is a warning and ignored', () {
      final result = expectSuccess(
        parse(
          withExercise(
            '{"name": "Plank", "type": "timed", "sets": 3, '
            '"durationSeconds": 45, "reps": 10, "repsMax": 12}',
          ),
        ),
      );
      final plank = result.workouts.single.exercises.single;
      expect(plank.reps, isNull);
      expect(plank.repsMax, isNull);
      expect(result.warnings.map((w) => w.message), [
        'Legs › exercise 1 (Plank): `reps` is ignored for timed exercises.',
        'Legs › exercise 1 (Plank): `repsMax` is ignored for timed exercises.',
      ]);
    });

    test('durationSeconds on a reps exercise is a warning and ignored', () {
      final result = expectSuccess(
        parse(
          withExercise(
            '{"name": "Squat", "sets": 3, "reps": 5, "durationSeconds": 30}',
          ),
        ),
      );
      expect(result.workouts.single.exercises.single.durationSeconds, isNull);
      expect(
        result.warnings.single.message,
        'Legs › exercise 1 (Squat): '
        '`durationSeconds` is ignored for reps exercises.',
      );
    });

    test('durationSeconds range', () {
      final result = expectFailure(
        parse(
          withExercise(
            '{"name": "Plank", "type": "timed", "sets": 1, '
            '"durationSeconds": 3601}',
          ),
        ),
      );
      expect(
        result.errors.single.message,
        'Legs › exercise 1 (Plank): '
        '`durationSeconds` must be between 1 and 3600.',
      );
    });

    test('weight range and unit', () {
      final bad = expectFailure(
        parse(
          withExercise(
            '{"name": "Squat", "sets": 1, "reps": 5, "weight": -1, '
            '"unit": "stone"}',
          ),
        ),
      );
      expect(bad.errors.map((e) => e.message), [
        'Legs › exercise 1 (Squat): `weight` must be between 0 and 2000.',
        'Legs › exercise 1 (Squat): `unit` must be "kg" or "lb".',
      ]);

      final ok = expectSuccess(
        parse(
          withExercise(
            '{"name": "Squat", "sets": 1, "reps": 5, "weight": 62.5}',
          ),
          unit: WeightUnit.lb,
        ),
      );
      final squat = ok.workouts.single.exercises.single;
      expect(squat.weight, 62.5);
      expect(squat.unit, WeightUnit.lb, reason: 'default unit applies');
    });

    test('group is stored', () {
      final result = expectSuccess(
        parse(
          withExercise('{"name": "Squat", "sets": 1, "reps": 5, "group": "A"}'),
        ),
      );
      expect(result.workouts.single.exercises.single.group, 'A');
    });

    test('an exercise that is not an object is located', () {
      final result = expectFailure(parse(withExercise('"Squat"')));
      expect(
        result.errors.single.message,
        'Legs › exercise 1 is not a JSON object.',
      );
    });

    test('all errors across workouts are reported together', () {
      final result = expectFailure(
        parse('''
{"schemaVersion": 1, "workouts": [
  {"name": "A", "exercises": [{"name": "X", "sets": 0, "reps": 1}]},
  {"name": "B", "exercises": [{"name": "Y", "sets": 1, "reps": 999}]}
]}'''),
      );
      expect(result.errors, hasLength(2));
      expect(result.errors.map((e) => e.path), [
        'workouts[0].exercises[0].sets',
        'workouts[1].exercises[0].reps',
      ]);
    });
  });

  group('export', () {
    test('omits default values and writes whole weights as integers', () {
      final json = exportWorkouts([
        Workout(
          name: 'Legs',
          exercises: const [
            Exercise(
              name: 'Squat',
              sets: 3,
              reps: 5,
              weight: 100,
              unit: WeightUnit.kg,
            ),
            Exercise(
              name: 'Wall sit',
              type: ExerciseType.timed,
              sets: 2,
              durationSeconds: 60,
              unit: WeightUnit.kg,
            ),
          ],
        ),
      ]);
      expect(json, '''
{
  "schemaVersion": 1,
  "workouts": [
    {
      "name": "Legs",
      "exercises": [
        {
          "name": "Squat",
          "sets": 3,
          "reps": 5,
          "weight": 100,
          "unit": "kg"
        },
        {
          "name": "Wall sit",
          "type": "timed",
          "sets": 2,
          "durationSeconds": 60,
          "unit": "kg"
        }
      ]
    }
  ]
}''');
    });

    test('round trip keeps every field, including a unit with no weight', () {
      final workouts = [
        Workout(
          name: 'Everything',
          description: 'All fields',
          tags: const ['a', 'b'],
          defaultRestSeconds: 75,
          exercises: const [
            Exercise(
              name: 'Dips',
              sets: 3,
              reps: 8,
              repsMax: 12,
              weight: 12.5,
              unit: WeightUnit.lb,
              restSeconds: 0,
              notes: 'Slow',
              group: 'A',
            ),
            Exercise(name: 'Push-up', sets: 2, reps: 20, unit: WeightUnit.lb),
          ],
        ),
      ];
      final result = expectSuccess(parse(exportWorkouts(workouts)));
      expect(result.workouts, workouts);
    });
  });

  test('ImportIssue equality', () {
    expect(
      const ImportIssue(path: 'a', message: 'm'),
      const ImportIssue(path: 'a', message: 'm'),
    );
    expect(
      const ImportIssue(path: 'a', message: 'm'),
      isNot(const ImportIssue(path: 'a', message: 'm', isWarning: true)),
    );
  });
}
