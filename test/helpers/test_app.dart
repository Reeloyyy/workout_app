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

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Pumps the whole app on a phone-sized screen (360 × 800 dp) backed by a
/// fresh in-memory database, which is returned.
Future<AppDatabase> pumpApp(WidgetTester tester, {AppDatabase? db}) async {
  // Each test opens its own database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final database = db ?? AppDatabase(NativeDatabase.memory());

  // rootBundle caches each asset's Future in the test's fake-async zone;
  // a later test awaiting that cached Future would never complete.
  addTearDown(rootBundle.clear);

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(database)],
      child: const WorkoutApp(),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

/// Disposes the widget tree (cancelling drift stream queries) and closes the
/// database. Call at the end of every test that used [pumpApp].
Future<void> disposeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  await db.close();
}

/// [CodeText] renders rich text, so match on the plain text of RichText.
Finder richTextContaining(String text) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(text),
);
