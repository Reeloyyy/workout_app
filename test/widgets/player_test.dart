import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/player/ui/rest_view.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

/// Adds the sample workout, opens it and taps Start.
Future<TestApp> startSample(
  WidgetTester tester, {
  FakeNotificationService? notifications,
  double textScale = 1,
}) async {
  final app = await pumpApp(
    tester,
    notifications: notifications,
    textScale: textScale,
  );
  await tester.tap(find.text('Add sample workout'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Push Day A'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
  return app;
}

/// Advances the fake clock and lets the player's 250 ms ticker run.
Future<void> advance(WidgetTester tester, TestApp app, Duration by) async {
  app.clock.advance(by);
  await tester.pump(const Duration(milliseconds: 300));
}

Finder doneButton() => find.widgetWithText(FilledButton, 'Done');

void main() {
  testWidgets('Start asks for permission and opens the player full screen', (
    tester,
  ) async {
    final app = await startSample(tester);

    expect(app.notifications.permissionRequests, 1);
    expect(app.screenAwake.on, isTrue);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Push Day A'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget, reason: 'elapsed time');
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('0/4'), findsOneWidget);
    expect(find.text('0/3'), findsNWidgets(2));
    expect(doneButton(), findsNothing, reason: 'nothing selected yet');

    final session = await tester.runAsync(
      () => app.db.select(app.db.sessions).getSingle(),
    );
    expect(session!.finishedAt, isNull);
    await disposeApp(tester, app);
    expect(app.screenAwake.on, isFalse, reason: 'released on leave');
  });

  testWidgets('offers exact alarms when they are not allowed', (tester) async {
    final app = await startSample(
      tester,
      notifications: FakeNotificationService(exactAlarmsAllowed: false),
    );
    expect(
      find.text(
        'Rest alerts may arrive late. Allow alarms for on-time alerts.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Allow'));
    expect(app.notifications.exactAlarmRequests, 1);
    await disposeApp(tester, app);
  });

  testWidgets('completing a set starts rest and schedules the alert', (
    tester,
  ) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget, reason: 'reps from the target');
    expect(find.text('60 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('More reps'));
    await tester.tap(find.byTooltip('More weight'));
    await tester.pump();
    await tester.tap(doneButton());
    await tester.pump();

    expect(find.byType(RestView), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);
    expect(find.text('Up next: Bench Press — set 2 of 4'), findsOneWidget);
    expect(app.notifications.pending, (
      at: app.clock.now().add(const Duration(seconds: 120)),
      body: 'Set 2 of 4 — Bench Press',
    ));

    final logs = await tester.runAsync(
      () => app.db.select(app.db.setLogs).get(),
    );
    expect(logs, isEmpty, reason: 'logs are persisted from M4');

    await advance(tester, app, const Duration(seconds: 30));
    expect(find.text('1:30'), findsOneWidget);
    await disposeApp(tester, app);
  });

  testWidgets('+15 s reschedules, Skip cancels', (tester) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(doneButton());
    await tester.pump();
    final restStart = app.clock.now();

    await tester.tap(find.text('+15 s'));
    await tester.pump();
    expect(find.text('2:15'), findsOneWidget);
    expect(
      app.notifications.pending?.at,
      restStart.add(const Duration(seconds: 135)),
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.byType(RestView), findsNothing);
    expect(app.notifications.pending, isNull);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('68 kg × 7'), findsNothing);
    expect(find.text('60 kg × 6'), findsOneWidget, reason: 'set 1 logged');
    await disposeApp(tester, app);
  });

  testWidgets('rest ends on time by itself; the alert is not cancelled', (
    tester,
  ) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(doneButton());
    await tester.pump();

    // As if the phone was locked: no ticks, then time has passed.
    await advance(tester, app, const Duration(seconds: 119));
    expect(find.byType(RestView), findsOneWidget);
    expect(find.text('0:01'), findsOneWidget);
    await advance(tester, app, const Duration(seconds: 1));

    expect(find.byType(RestView), findsNothing);
    expect(app.notifications.cancels, 0);
    expect(app.notifications.pending, isNotNull);
    await disposeApp(tester, app);
  });

  testWidgets('exercises can be done in any order', (tester) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Overhead Press'));
    await tester.pumpAndSettle();
    expect(find.text('Set 1'), findsOneWidget);

    // Switch before doing anything.
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('Set 4'), findsOneWidget, reason: 'Bench is expanded');
    await disposeApp(tester, app);
  });

  testWidgets('choosing another exercise during rest updates the alert', (
    tester,
  ) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(doneButton());
    await tester.pump();

    await tester.tap(find.text('Change exercise'));
    // The breathing animation never settles, so pump past the sheet animation.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Plank'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Up next: Plank — set 1 of 3'), findsOneWidget);
    expect(app.notifications.pending?.body, 'Set 1 of 3 — Plank');
    await disposeApp(tester, app);
  });

  testWidgets('timed set counts down and completes at zero', (tester) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Plank'));
    await tester.pumpAndSettle();
    expect(find.text('0:45'), findsOneWidget);

    await tester.tap(find.text('Start').last);
    await tester.pump();
    await advance(tester, app, const Duration(seconds: 15));
    expect(find.text('0:30'), findsOneWidget);

    await advance(tester, app, const Duration(seconds: 30));
    expect(find.byType(RestView), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget, reason: 'Plank rest is 60 s');
    await disposeApp(tester, app);
  });

  testWidgets('Add weight reveals a weight stepper from 0', (tester) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Overhead Press'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('More weight'), findsNothing);
    await tester.tap(find.text('Add weight'));
    await tester.pump();
    expect(find.text('0 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('More weight'));
    await tester.pump();
    expect(find.text('2.5 kg'), findsOneWidget);

    await tester.tap(doneButton());
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.text('2.5 kg × 10'), findsOneWidget);
    await disposeApp(tester, app);
  });

  testWidgets('Finish asks when sets remain, saves and returns home', (
    tester,
  ) async {
    final app = await startSample(tester);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(doneButton());
    await tester.pump();
    await advance(tester, app, const Duration(minutes: 5));

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('9 sets are not done.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Finish').last);
    await tester.pumpAndSettle();

    expect(find.text('Workout finished.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(app.notifications.pending, isNull);
    final session = await tester.runAsync(
      () => app.db.select(app.db.sessions).getSingle(),
    );
    expect(session!.finishedAt, isNotNull);
    await disposeApp(tester, app);
  });

  testWidgets('Back asks before leaving', (tester) async {
    final app = await startSample(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Leave workout?'), findsOneWidget);
    expect(find.text('Progress is saved.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Overhead Press'), findsOneWidget, reason: 'stayed');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget, reason: 'back on the detail');
    await disposeApp(tester, app);
  });

  testWidgets('player and rest view fit at 1.5× text', (tester) async {
    final app = await startSample(tester, textScale: 1.5);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(doneButton());
    await tester.pump();
    expect(find.byType(RestView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeApp(tester, app);
  });
}
