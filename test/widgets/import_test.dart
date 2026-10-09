import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/main.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

Future<void> openImport(WidgetTester tester) async {
  // Phone-sized screen (360 × 800 dp), so the issue list below the field is
  // laid out.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const ProviderScope(child: WorkoutApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Import'));
  await tester.pumpAndSettle();
}

Future<void> validate(WidgetTester tester, String json) async {
  await tester.enterText(find.byType(TextField), json);
  await tester.tap(find.text('Validate'));
  await tester.pumpAndSettle();
}

/// [CodeText] renders rich text, so match on the plain text of RichText.
Finder richTextContaining(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);

void main() {
  testWidgets('valid JSON opens a preview of every exercise', (tester) async {
    await openImport(tester);
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
  });

  testWidgets('invalid JSON lists every error and stays on import', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openImport(tester);
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
    semantics.dispose();
  });

  testWidgets('warnings are shown and do not block the preview', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openImport(tester);
    await validate(tester, fixture('unknown_field.json'));

    expect(find.text('Preview'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Warning\n')), findsOneWidget);
    expect(
      richTextContaining('Unknown field tempo was ignored.'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
