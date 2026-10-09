import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/repositories/workout_repository.dart';
import 'package:workout_app/data/db/app_database.dart';
import 'package:workout_app/core/clock.dart';
import 'package:workout_app/features/import/domain/workout_parser.dart';
import 'package:workout_app/models/exercise.dart';

import '../helpers/test_app.dart';

Future<TestApp> openImport(WidgetTester tester) async {
  final app = await pumpApp(tester);
  await tester.tap(find.byTooltip('Import'));
  await tester.pumpAndSettle();
  return app;
}

Future<void> validate(WidgetTester tester, String json) async {
  await tester.enterText(find.byType(TextField), json);
  await tester.tap(find.text('Validate'));
  await tester.pumpAndSettle();
}

Future<void> saveExisting(AppDatabase db) async {
  final workout =
      (parseWorkouts(fixture('valid_push_day.json'), defaultUnit: WeightUnit.kg)
              as ImportSuccess)
          .workouts
          .single;
  await WorkoutRepository(db, const SystemClock()).insert(workout);
}

void main() {
  testWidgets('valid JSON opens a preview of every exercise', (tester) async {
    final app = await openImport(tester);
    await validate(tester, fixture('valid_push_day.json'));

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Overhead Press'), findsOneWidget);
    expect(find.text('Plank'), findsOneWidget);
    expect(
      find.text('4 × 6–8 @ 60 kg · Rest 120 s\nPause briefly on the chest'),
      findsOneWidget,
    );
    expect(find.text('3 × 10 · Rest 90 s'), findsOneWidget);
    expect(find.text('3 × 45 s · Rest 60 s'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Import'), findsOneWidget);
    await disposeApp(tester, app);
  });

  testWidgets('invalid JSON lists every error and stays on import', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await openImport(tester);
    await validate(tester, fixture('bad_ranges.json'));

    expect(find.text('Preview'), findsNothing);
    // Each icon merges with its message: "Error\n<message>".
    expect(find.bySemanticsLabel(RegExp(r'^Error\n')), findsNWidgets(3));
    expect(
      richTextContaining('Push Day A › exercise 1 (Bench Press): sets must be'),
      findsOneWidget,
    );
    expect(richTextContaining('repsMax must be at least reps'), findsOneWidget);
    expect(richTextContaining('restSeconds must be between'), findsOneWidget);
    await disposeApp(tester, app);
    semantics.dispose();
  });

  testWidgets('warnings are shown and do not block the preview', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await openImport(tester);
    await validate(tester, fixture('unknown_field.json'));

    expect(find.text('Preview'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Warning\n')), findsOneWidget);
    expect(
      richTextContaining('Unknown field tempo was ignored.'),
      findsOneWidget,
    );
    await disposeApp(tester, app);
    semantics.dispose();
  });

  testWidgets('Save adds the workout to the library', (tester) async {
    final app = await openImport(tester);
    await validate(tester, fixture('valid_push_day.json'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Workout saved.'), findsOneWidget);
    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.text('3 exercises · Not done yet'), findsOneWidget);
    await disposeApp(tester, app);
  });

  group('duplicate name', () {
    Future<TestApp> saveDuplicate(WidgetTester tester) async {
      final app = await openImport(tester);
      await tester.runAsync(() => saveExisting(app.db));
      await validate(tester, fixture('unknown_field.json'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Name already exists'), findsOneWidget);
      return app;
    }

    testWidgets('Keep both appends " (2)"', (tester) async {
      final app = await saveDuplicate(tester);
      await tester.tap(find.text('Keep both'));
      await tester.pumpAndSettle();

      expect(find.text('Push Day A'), findsOneWidget);
      expect(find.text('Push Day A (2)'), findsOneWidget);
      await disposeApp(tester, app);
    });

    testWidgets('Replace overwrites the saved workout', (tester) async {
      final app = await saveDuplicate(tester);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(find.text('Push Day A'), findsOneWidget);
      // unknown_field.json has a single exercise.
      expect(find.text('1 exercise · Not done yet'), findsOneWidget);
      await disposeApp(tester, app);
    });

    testWidgets('Cancel saves nothing and stays on the preview', (
      tester,
    ) async {
      final app = await saveDuplicate(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Preview'), findsOneWidget);
      final names = await tester.runAsync(
        () => WorkoutRepository(app.db, const SystemClock()).names(),
      );
      expect(names!.values, ['Push Day A']);
      await disposeApp(tester, app);
    });
  });
}
