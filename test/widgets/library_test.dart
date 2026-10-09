import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/import/domain/workout_parser.dart';
import 'package:workout_app/models/exercise.dart';

import '../helpers/test_app.dart';

void main() {
  test('the bundled sample is the spec example', () {
    expect(
      File('assets/sample_workout.json').readAsStringSync(),
      fixture('valid_push_day.json'),
    );
  });

  testWidgets('empty library explains import and offers the sample', (
    tester,
  ) async {
    final db = await pumpApp(tester);

    expect(find.text('No workouts yet'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    await tester.tap(find.text('Add sample workout'));
    await tester.pumpAndSettle();

    expect(find.text('No workouts yet'), findsNothing);
    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.text('3 exercises · Not done yet'), findsOneWidget);
    await disposeApp(tester, db);
  });

  testWidgets('detail shows exercises, exports and deletes', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final db = await pumpApp(tester);
    await tester.tap(find.text('Add sample workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push Day A'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('3 × 45 s · Rest 60 s'), findsOneWidget);

    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    expect(find.text('Workout JSON copied to the clipboard.'), findsOneWidget);
    final reimported = parseWorkouts(clipboard!, defaultUnit: WeightUnit.kg);
    final original = parseWorkouts(
      fixture('valid_push_day.json'),
      defaultUnit: WeightUnit.kg,
    );
    expect(
      (reimported as ImportSuccess).workouts,
      (original as ImportSuccess).workouts,
    );

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete workout?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No workouts yet'), findsOneWidget);
    await disposeApp(tester, db);
  });
}
