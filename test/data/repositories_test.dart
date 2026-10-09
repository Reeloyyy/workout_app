import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/core/clock.dart';
import 'package:workout_app/data/db/app_database.dart';
import 'package:workout_app/data/repositories/workout_repository.dart';
import 'package:workout_app/features/import/domain/workout_parser.dart';
import 'package:workout_app/models/exercise.dart';
import 'package:workout_app/models/workout.dart';

class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

Workout pushDay() {
  final result = parseWorkouts(
    File('test/fixtures/valid_push_day.json').readAsStringSync(),
    defaultUnit: WeightUnit.kg,
  );
  return (result as ImportSuccess).workouts.single;
}

Workout legs([String name = 'Legs']) => Workout(
  name: name,
  exercises: const [
    Exercise(name: 'Squat', sets: 3, reps: 5, unit: WeightUnit.kg),
  ],
);

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late WorkoutRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FakeClock(DateTime.utc(2026, 10, 8, 9));
    repo = WorkoutRepository(db, clock);
  });

  tearDown(() => db.close());

  /// Adds a session for [workoutId]; with [sets] > 0 it also logs sets.
  Future<int> addSession(
    int? workoutId, {
    required DateTime started,
    DateTime? finished,
    int sets = 1,
  }) async {
    final id = await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            workoutId: Value(workoutId),
            workoutName: 'x',
            workoutSnapshotJson: '{}',
            startedAt: started.toUtc(),
            finishedAt: Value(finished?.toUtc()),
          ),
        );
    for (var i = 1; i <= sets; i++) {
      await db
          .into(db.setLogs)
          .insert(
            SetLogsCompanion.insert(
              sessionId: id,
              exercisePosition: 0,
              exerciseName: 'Squat',
              setNumber: i,
              completedAt: started.toUtc(),
            ),
          );
    }
    return id;
  }

  group('database', () {
    test('creates the single settings row with defaults', () async {
      final row = await db.select(db.settings).getSingle();
      expect(row.id, 1);
      expect(row.unit, WeightUnit.kg);
      expect(row.reminderDaysMask, 0);
      expect(row.soundOn, isTrue);
      expect(row.vibrationOn, isTrue);
    });

    test('enforces foreign keys', () async {
      await expectLater(
        db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                workoutId: 999,
                position: 0,
                name: 'Orphan',
                type: ExerciseType.reps,
                sets: 1,
                unit: WeightUnit.kg,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('WorkoutRepository', () {
    test('insert then read returns an equal workout', () async {
      final id = await repo.insert(pushDay());
      final saved = await repo.findById(id);
      expect(saved, SavedWorkout(id: id, workout: pushDay()));
    });

    test('exported JSON of a saved workout re-imports equal', () async {
      final id = await repo.insert(pushDay());
      final saved = (await repo.findById(id))!;
      final reimported = parseWorkouts(
        exportWorkouts([saved.workout]),
        defaultUnit: WeightUnit.lb,
      );
      expect((reimported as ImportSuccess).workouts.single, saved.workout);
    });

    test('summaries: sorted by name, exercise count', () async {
      await repo.insert(legs('legs b'));
      await repo.insert(pushDay());
      await repo.insert(legs('Legs A'));

      final summaries = await repo.watchSummaries().first;
      expect(summaries.map((s) => s.name), ['Legs A', 'legs b', 'Push Day A']);
      expect(summaries.map((s) => s.exerciseCount), [1, 1, 3]);
      expect(summaries.every((s) => s.lastDone == null), isTrue);
    });

    test('last done ignores unfinished and empty sessions', () async {
      final id = await repo.insert(legs());
      final monday = DateTime.utc(2026, 10, 5, 18);
      final tuesday = DateTime.utc(2026, 10, 6, 18);
      final wednesday = DateTime.utc(2026, 10, 7, 18);

      await addSession(id, started: monday, finished: monday);
      await addSession(id, started: tuesday, finished: tuesday);
      // Discarded (finished, nothing logged) and still running.
      await addSession(id, started: wednesday, finished: wednesday, sets: 0);
      await addSession(id, started: wednesday);

      final summary = (await repo.watchSummaries().first).single;
      expect(summary.lastDone, tuesday.toLocal());
      expect(summary.lastDone!.isUtc, isFalse);
    });

    test('summaries update when a workout is added', () async {
      final emitted = repo.watchSummaries().map((s) => s.length);
      final expectation = expectLater(emitted, emitsInOrder([0, 1]));
      await pumpEventQueue();
      await repo.insert(legs());
      await expectation;
    });

    test('names lists every saved workout', () async {
      final a = await repo.insert(legs('A'));
      final b = await repo.insert(legs('B'));
      expect(await repo.names(), {a: 'A', b: 'B'});
    });

    test('saveAll replaces in place and inserts new ones', () async {
      final id = await repo.insert(legs());
      clock.current = DateTime.utc(2026, 10, 9);
      final replacement = pushDay().copyWith(name: 'Legs');

      await repo.saveAll(
        inserts: [legs('Arms')],
        replacements: {id: replacement},
      );

      expect(
        await repo.findById(id),
        SavedWorkout(id: id, workout: replacement),
      );
      expect((await repo.names()).values, containsAll(['Legs', 'Arms']));
      final exerciseCount = await db.select(db.exercises).get();
      expect(exerciseCount, hasLength(4), reason: 'old exercises removed');

      final row = await (db.select(
        db.workouts,
      )..where((w) => w.id.equals(id))).getSingle();
      expect(row.createdAt, DateTime.utc(2026, 10, 8, 9));
      expect(row.updatedAt, DateTime.utc(2026, 10, 9));
    });

    test('saveAll saves nothing if any part fails', () async {
      await expectLater(
        repo.saveAll(inserts: [legs('Arms')], replacements: {999: legs()}),
        throwsStateError,
      );
      expect(await repo.names(), isEmpty);
    });

    test('delete removes exercises and keeps sessions', () async {
      final id = await repo.insert(pushDay());
      final sessionId = await addSession(
        id,
        started: DateTime.utc(2026, 10, 1),
        finished: DateTime.utc(2026, 10, 1),
      );

      await repo.delete(id);

      expect(await repo.findById(id), isNull);
      expect(await db.select(db.exercises).get(), isEmpty);
      final session = await (db.select(
        db.sessions,
      )..where((s) => s.id.equals(sessionId))).getSingle();
      expect(session.workoutId, isNull);
      expect(await db.select(db.setLogs).get(), hasLength(1));
    });

    test('watchWorkout emits null after delete', () async {
      final id = await repo.insert(legs());
      final emitted = repo.watchWorkout(id).map((w) => w?.id);
      final expectation = expectLater(emitted, emitsInOrder([id, null]));
      await pumpEventQueue();
      await repo.delete(id);
      await expectation;
    });
  });
}
