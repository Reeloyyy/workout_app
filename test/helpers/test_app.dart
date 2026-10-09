import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/data/db/app_database.dart';
import 'package:workout_app/data/providers.dart';
import 'package:workout_app/main.dart';
import 'package:workout_app/services/service_providers.dart';

import 'fake_clock.dart';
import 'fakes.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Everything a widget test may want to inspect or control.
class TestApp {
  TestApp(this.db, this.clock, this.notifications, this.screenAwake);

  final AppDatabase db;
  final FakeClock clock;
  final FakeNotificationService notifications;
  final FakeScreenAwake screenAwake;
}

/// Pumps the whole app on a phone-sized screen (360 × 800 dp) with a fresh
/// in-memory database, a [FakeClock] and fake platform services.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  FakeNotificationService? notifications,
  double textScale = 1,
}) async {
  // Each test opens its own database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final app = TestApp(
    AppDatabase(NativeDatabase.memory()),
    FakeClock(DateTime(2026, 10, 8, 18)),
    notifications ?? FakeNotificationService(),
    FakeScreenAwake(),
  );

  // rootBundle caches each asset's Future in the test's fake-async zone;
  // a later test awaiting that cached Future would never complete.
  addTearDown(rootBundle.clear);

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(app.db),
        clockProvider.overrideWithValue(app.clock),
        notificationServiceProvider.overrideWithValue(app.notifications),
        screenAwakeProvider.overrideWithValue(app.screenAwake),
      ],
      child: const WorkoutApp(),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

/// Disposes the widget tree (cancelling drift stream queries and timers)
/// and closes the database. Call at the end of every test that used
/// [pumpApp].
Future<void> disposeApp(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await app.db.close();
}

/// [CodeText] renders rich text, so match on the plain text of RichText.
Finder richTextContaining(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);
