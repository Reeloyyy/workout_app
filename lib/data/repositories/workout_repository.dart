import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../db/app_database.dart';

/// Reads and writes workouts. Converts between drift rows and domain models;
/// nothing outside `lib/data/` sees drift types.
///
/// Times are written in UTC (so stored text sorts in time order) and returned
/// in local time.
class WorkoutRepository {
  WorkoutRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Library rows, sorted by name (case-insensitive).
  Stream<List<WorkoutSummary>> watchSummaries() {
    return _db
        .customSelect(
          '''
SELECT w.id, w.name,
  (SELECT COUNT(*) FROM exercises e WHERE e.workout_id = w.id)
    AS exercise_count,
  (SELECT MAX(s.finished_at) FROM sessions s
    WHERE s.workout_id = w.id
      AND s.finished_at IS NOT NULL
      AND EXISTS (SELECT 1 FROM set_logs l WHERE l.session_id = s.id))
    AS last_done
FROM workouts w
ORDER BY w.name COLLATE NOCASE, w.id
''',
          readsFrom: {_db.workouts, _db.exercises, _db.sessions, _db.setLogs},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              WorkoutSummary(
                id: row.read<int>('id'),
                name: row.read<String>('name'),
                exerciseCount: row.read<int>('exercise_count'),
                lastDone: row.readNullable<DateTime>('last_done')?.toLocal(),
              ),
          ],
        );
  }

  /// The workout with [id], or null once it is deleted.
  Stream<SavedWorkout?> watchWorkout(int id) {
    final query = _db.select(_db.workouts)..where((w) => w.id.equals(id));
    return query.watchSingleOrNull().asyncMap(
      (row) async => row == null ? null : _toSaved(row),
    );
  }

  Future<SavedWorkout?> findById(int id) async {
    final row = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toSaved(row);
  }

  /// Every saved workout's id and name, for duplicate checks.
  Future<Map<int, String>> names() async {
    final rows = await _db.select(_db.workouts).get();
    return {for (final row in rows) row.id: row.name};
  }

  Future<int> insert(Workout workout) =>
      _db.transaction(() => _insert(workout));

  /// Inserts [inserts] and overwrites [replacements] (by id) in one
  /// transaction: either all are saved or none.
  Future<void> saveAll({
    List<Workout> inserts = const [],
    Map<int, Workout> replacements = const {},
  }) {
    return _db.transaction(() async {
      for (final MapEntry(key: id, value: workout) in replacements.entries) {
        await _replace(id, workout);
      }
      for (final workout in inserts) {
        await _insert(workout);
      }
    });
  }

  /// Deletes the workout and its exercises. Past sessions keep their
  /// snapshot; their `workout_id` becomes null.
  Future<void> delete(int id) =>
      (_db.delete(_db.workouts)..where((w) => w.id.equals(id))).go();

  Future<int> _insert(Workout workout) async {
    final now = _clock.now().toUtc();
    final id = await _db
        .into(_db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            name: workout.name,
            description: Value(workout.description),
            tagsJson: jsonEncode(workout.tags),
            defaultRestSeconds: workout.defaultRestSeconds,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _insertExercises(id, workout.exercises);
    return id;
  }

  /// Keeps the id (and so the link from past sessions) and creation time.
  Future<void> _replace(int id, Workout workout) async {
    final updated =
        await (_db.update(_db.workouts)..where((w) => w.id.equals(id))).write(
          WorkoutsCompanion(
            name: Value(workout.name),
            description: Value(workout.description),
            tagsJson: Value(jsonEncode(workout.tags)),
            defaultRestSeconds: Value(workout.defaultRestSeconds),
            updatedAt: Value(_clock.now().toUtc()),
          ),
        );
    if (updated == 0) throw StateError('No workout with id $id');
    await (_db.delete(
      _db.exercises,
    )..where((e) => e.workoutId.equals(id))).go();
    await _insertExercises(id, workout.exercises);
  }

  Future<void> _insertExercises(int workoutId, List<Exercise> exercises) {
    return _db.batch((batch) {
      batch.insertAll(_db.exercises, [
        for (final (position, e) in exercises.indexed)
          ExercisesCompanion.insert(
            workoutId: workoutId,
            position: position,
            name: e.name,
            type: e.type,
            sets: e.sets,
            reps: Value(e.reps),
            repsMax: Value(e.repsMax),
            durationSeconds: Value(e.durationSeconds),
            weight: Value(e.weight),
            unit: e.unit,
            restSeconds: Value(e.restSeconds),
            notes: Value(e.notes),
            groupKey: Value(e.group),
          ),
      ]);
    });
  }

  Future<SavedWorkout> _toSaved(WorkoutRow row) async {
    final exerciseRows =
        await (_db.select(_db.exercises)
              ..where((e) => e.workoutId.equals(row.id))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();
    final tags = (jsonDecode(row.tagsJson) as List<Object?>).cast<String>();
    return SavedWorkout(
      id: row.id,
      workout: Workout(
        name: row.name,
        description: row.description,
        tags: tags,
        defaultRestSeconds: row.defaultRestSeconds,
        exercises: [
          for (final e in exerciseRows)
            Exercise(
              name: e.name,
              type: e.type,
              sets: e.sets,
              reps: e.reps,
              repsMax: e.repsMax,
              durationSeconds: e.durationSeconds,
              weight: e.weight,
              unit: e.unit,
              restSeconds: e.restSeconds,
              notes: e.notes,
              group: e.groupKey,
            ),
        ],
      ),
    );
  }
}
