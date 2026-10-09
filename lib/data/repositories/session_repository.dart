import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../features/import/domain/workout_parser.dart';
import '../../models/exercise.dart';
import '../../models/session.dart';
import '../../models/workout.dart';
import '../db/app_database.dart';

/// Reads and writes workout sessions. Times are written in UTC and returned
/// in local time.
class SessionRepository {
  SessionRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Creates the session row with a snapshot of [saved] and returns its id.
  Future<int> start(SavedWorkout saved) {
    return _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            workoutId: Value(saved.id),
            workoutName: saved.workout.name,
            workoutSnapshotJson: exportWorkouts([saved.workout]),
            startedAt: _clock.now().toUtc(),
          ),
        );
  }

  Future<Session?> findById(int id) async {
    final row = await (_db.select(
      _db.sessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    // The snapshot was written by exportWorkouts, which always includes
    // `unit`, so the default unit is never used.
    final parsed = parseWorkouts(
      row.workoutSnapshotJson,
      defaultUnit: WeightUnit.kg,
    );
    final workout = switch (parsed) {
      ImportSuccess(:final workouts) => workouts.single,
      ImportFailure(:final errors) => throw FormatException(
        'Session $id has an unreadable workout snapshot: $errors',
      ),
    };
    return Session(
      id: row.id,
      workoutId: row.workoutId,
      workout: workout,
      startedAt: row.startedAt.toLocal(),
      finishedAt: row.finishedAt?.toLocal(),
    );
  }

  Future<void> finish(int id, DateTime finishedAt) {
    return (_db.update(_db.sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(finishedAt: Value(finishedAt.toUtc())),
    );
  }
}
