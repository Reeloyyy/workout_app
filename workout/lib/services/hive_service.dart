import 'package:hive_flutter/hive_flutter.dart';

import '../models/completed_session.dart';
import '../models/exercise.dart';
import '../models/weight_entry.dart';
import '../models/workout_day.dart';
import '../models/workout_plan.dart';

/// Initializes Hive and exposes typed box accessors used throughout the app.
class HiveService {
  HiveService._();

  static const String plansBoxName = 'plans';
  static const String sessionsBoxName = 'sessions';
  static const String weightsBoxName = 'weights';
  static const String settingsBoxName = 'settings';

  static late Box<WorkoutPlan> _plansBox;
  static late Box<CompletedSession> _sessionsBox;
  static late Box<WeightEntry> _weightsBox;
  static late Box _settingsBox;

  static Box<WorkoutPlan> get plansBox => _plansBox;
  static Box<CompletedSession> get sessionsBox => _sessionsBox;
  static Box<WeightEntry> get weightsBox => _weightsBox;
  static Box get settingsBox => _settingsBox;

  /// Initializes Hive and opens all boxes. Pass [testPath] to point Hive at
  /// a plain filesystem directory instead of the platform app-documents
  /// directory (used by widget tests, which have no path_provider plugin).
  static Future<void> init({String? testPath}) async {
    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }

    Hive.registerAdapter(ExerciseAdapter());
    Hive.registerAdapter(WorkoutDayAdapter());
    Hive.registerAdapter(WorkoutPlanAdapter());
    Hive.registerAdapter(CompletedSessionAdapter());
    Hive.registerAdapter(WeightEntryAdapter());

    _plansBox = await Hive.openBox<WorkoutPlan>(plansBoxName);
    _sessionsBox = await Hive.openBox<CompletedSession>(sessionsBoxName);
    _weightsBox = await Hive.openBox<WeightEntry>(weightsBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
  }

  static String? get activePlanId => _settingsBox.get('activePlanId') as String?;

  static Future<void> setActivePlanId(String id) async {
    await _settingsBox.put('activePlanId', id);
  }

  static String get weightUnit => _settingsBox.get('weightUnit', defaultValue: 'lbs') as String;

  static Future<void> setWeightUnit(String unit) async {
    await _settingsBox.put('weightUnit', unit);
  }

  static Future<void> resetAllData() async {
    await _plansBox.clear();
    await _sessionsBox.clear();
    await _weightsBox.clear();
    await _settingsBox.clear();
  }
}
