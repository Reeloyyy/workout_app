import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../models/workout.dart';
import 'db/app_database.dart';
import 'repositories/workout_repository.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The app's database. Tests override this with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) =>
      WorkoutRepository(ref.watch(databaseProvider), ref.watch(clockProvider)),
);

final workoutSummariesProvider = StreamProvider<List<WorkoutSummary>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchSummaries(),
);

final workoutProvider = StreamProvider.family<SavedWorkout?, int>(
  (ref, id) => ref.watch(workoutRepositoryProvider).watchWorkout(id),
);
