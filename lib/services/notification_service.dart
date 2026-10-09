import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps flutter_local_notifications for the rest alert (and, from M5, the
/// weekly reminders).
///
/// The rest alert is the alert in every app state, foreground included
/// (AGENTS.md §7.2): it is never cancelled because the app is open, only on
/// skip, +15 s (rescheduled) or finish.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// One fixed id for the rest alert.
  static const int restAlertId = 1;

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Sets the local time zone and initialises the plugin. Does not ask for
  /// permission: that happens when a workout is first started.
  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (e) {
      // Rest alerts use absolute instants, so they stay correct in UTC.
      debugPrint('Could not read the local time zone: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          // Show alerts and play their sound while the app is open.
          defaultPresentAlert: true,
          defaultPresentBanner: true,
          defaultPresentList: true,
          defaultPresentSound: true,
        ),
      ),
    );
  }

  /// Asks for permission to post notifications. The system only shows the
  /// prompt while the user has not decided.
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
      await _ios?.requestPermissions(alert: true, sound: true);
    } on Object catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Whether rest alerts can be scheduled for an exact time (Android 12+
  /// "Alarms & reminders"). Without it alerts may arrive late.
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? true;
    } on Object {
      return false;
    }
  }

  /// Opens the system screen where exact alarms can be allowed.
  Future<void> requestExactAlarms() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } on Object catch (e) {
      debugPrint('Exact alarm request failed: $e');
    }
  }

  /// Schedules (or moves) the rest alert to [at]. Failures (including a time
  /// already past) are logged and ignored: the in-app timer keeps working.
  Future<void> scheduleRestAlert({
    required DateTime at,
    required String body,
    bool sound = true,
    bool vibration = true,
  }) async {
    try {
      final exact = await canScheduleExactAlarms();
      await _plugin.zonedSchedule(
        id: restAlertId,
        title: 'Rest over',
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _restAlertDetails(
          sound: sound,
          vibration: vibration,
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Object catch (e) {
      debugPrint('Could not schedule the rest alert: $e');
    }
  }

  Future<void> cancelRestAlert() async {
    try {
      await _plugin.cancel(id: restAlertId);
    } on Object catch (e) {
      debugPrint('Could not cancel the rest alert: $e');
    }
  }

  /// Android channel sound and vibration cannot change after creation, so
  /// there is one high-importance channel per combination.
  static NotificationDetails _restAlertDetails({
    required bool sound,
    required bool vibration,
  }) {
    final channelId = switch ((sound, vibration)) {
      (true, true) => 'rest_alert_sound_vibration',
      (true, false) => 'rest_alert_sound',
      (false, true) => 'rest_alert_vibration',
      (false, false) => 'rest_alert_silent',
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Rest alerts',
        channelDescription: 'Tells you when a rest is over.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: sound,
        enableVibration: vibration,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: sound,
      ),
    );
  }
}
