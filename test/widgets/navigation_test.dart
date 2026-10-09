import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  Finder appBarTitle(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  testWidgets('starts on Workouts and every tab navigates', (tester) async {
    final db = await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(appBarTitle('Workouts'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(appBarTitle('History'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(appBarTitle('Settings'), findsOneWidget);

    await tester.tap(find.text('Workouts').last);
    await tester.pumpAndSettle();
    expect(appBarTitle('Workouts'), findsOneWidget);

    await disposeApp(tester, db);
  });
}
