import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'screen_awake.dart';

/// Initialised in `main` and overridden there; tests override it with a fake.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError('Override in main() after init()'),
);

final screenAwakeProvider = Provider<ScreenAwake>((ref) => const ScreenAwake());
