import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/hive_service.dart';
import 'services/json_import_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();
  await _loadSamplePlanIfNeeded();

  runApp(const FitTrackApp());
}

/// Loads the bundled sample plan as the active plan on first launch,
/// i.e. whenever no plans have been imported yet.
Future<void> _loadSamplePlanIfNeeded() async {
  if (HiveService.plansBox.isNotEmpty) return;

  try {
    final jsonString = await rootBundle.loadString('assets/sample_plan.json');
    final plan = JsonImportService.parsePlan(jsonString);
    await HiveService.plansBox.add(plan);
    await HiveService.setActivePlanId(plan.id);
  } catch (_) {
    // If the bundled sample is missing or invalid, the app simply starts
    // with no active plan and prompts the user to import one.
  }
}
