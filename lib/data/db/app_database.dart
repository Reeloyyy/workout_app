import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/exercise.dart';

part 'app_database.g.dart';

@DataClassName('WorkoutRow')
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get tagsJson => text()();
  IntColumn get defaultRestSeconds => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('ExerciseRow')
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  TextColumn get type => textEnum<ExerciseType>()();
  IntColumn get sets => integer()();
  IntColumn get reps => integer().nullable()();
  IntColumn get repsMax => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get unit => textEnum<WeightUnit>()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get groupKey => text().nullable()();
}

@DataClassName('SessionRow')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().nullable().references(
    Workouts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get workoutName => text()();

  /// The workout as exported JSON at session start, so history and resume
  /// work after the workout is edited or deleted.
  TextColumn get workoutSnapshotJson => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get activeExerciseIndex => integer().nullable()();
  DateTimeColumn get restEndsAt => dateTime().nullable()();
}

@TableIndex(
  name: 'set_logs_exercise_name_completed_at',
  columns: {#exerciseName, #completedAt},
)
@DataClassName('SetLogRow')
class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exercisePosition => integer()();
  TextColumn get exerciseName => text()();
  IntColumn get setNumber => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get unit => textEnum<WeightUnit>().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get completedAt => dateTime()();
}

/// Single-row table (id is always 1).
@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id =>
      // drift's table DSL: `id` names the column; it is not a recursive call.
      // ignore: recursive_getters
      integer().withDefault(const Constant(1)).check(id.equals(1))();
  TextColumn get unit =>
      textEnum<WeightUnit>().withDefault(Constant(WeightUnit.kg.name))();

  /// Bit 0 = Monday … bit 6 = Sunday. Reminders are off by default.
  IntColumn get reminderDaysMask => integer().withDefault(const Constant(0))();

  /// Minutes after midnight, local time.
  IntColumn get reminderMinutes =>
      integer().withDefault(const Constant(18 * 60))();
  BoolColumn get soundOn => boolean().withDefault(const Constant(true))();
  BoolColumn get vibrationOn => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Workouts, Exercises, Sessions, SetLogs, Settings])
class AppDatabase extends _$AppDatabase {
  /// [executor] is an in-memory database in tests.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'workout_app'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(settings).insert(const SettingsCompanion());
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
