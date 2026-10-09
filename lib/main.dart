import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'services/notification_service.dart';
import 'services/service_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sets the local time zone and initialises notifications (no permission
  // prompt: that waits until a workout is first started).
  final notifications = NotificationService();
  await notifications.init();
  runApp(
    ProviderScope(
      overrides: [notificationServiceProvider.overrideWithValue(notifications)],
      child: const WorkoutApp(),
    ),
  );
}

class WorkoutApp extends ConsumerWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Workout App',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
