import 'package:workout_app/services/notification_service.dart';
import 'package:workout_app/services/screen_awake.dart';

/// Records rest alert calls instead of talking to the plugin.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.exactAlarmsAllowed = true});

  bool exactAlarmsAllowed;
  int permissionRequests = 0;
  int exactAlarmRequests = 0;
  int cancels = 0;

  /// Every scheduled rest alert, in order.
  final List<({DateTime at, String body})> scheduled = [];

  /// The alert that would fire, or null after a cancel.
  ({DateTime at, String body})? pending;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async => permissionRequests++;

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsAllowed;

  @override
  Future<void> requestExactAlarms() async => exactAlarmRequests++;

  @override
  Future<void> scheduleRestAlert({
    required DateTime at,
    required String body,
    bool sound = true,
    bool vibration = true,
  }) async {
    scheduled.add((at: at, body: body));
    pending = (at: at, body: body);
  }

  @override
  Future<void> cancelRestAlert() async {
    cancels++;
    pending = null;
  }
}

class FakeScreenAwake implements ScreenAwake {
  bool on = false;

  @override
  Future<void> keepOn(bool on) async => this.on = on;
}
