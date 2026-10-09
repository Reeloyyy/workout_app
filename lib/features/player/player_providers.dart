import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../models/set_log.dart';
import '../../services/notification_service.dart';
import '../../services/service_providers.dart';
import 'domain/player_text.dart';
import 'domain/session_controller.dart';
import 'domain/session_state.dart';

/// The player for one session, by session id.
final playerProvider = AsyncNotifierProvider.autoDispose
    .family<PlayerNotifier, SessionState, int>(PlayerNotifier.new);

/// Glue between [SessionController], the session repository and the rest
/// alert. Widgets call these intents; all workout logic is in the
/// controller.
///
/// Rest alert rules (AGENTS.md §7.2): schedule when rest starts, reschedule
/// on +15 s or when the next exercise changes, cancel on skip or finish.
/// When rest simply runs out the alert is left alone — it is the alert.
class PlayerNotifier extends AsyncNotifier<SessionState> {
  PlayerNotifier(this.sessionId);

  final int sessionId;
  late SessionController _controller;
  bool _finishSaved = false;

  NotificationService get _alerts => ref.read(notificationServiceProvider);

  @override
  Future<SessionState> build() async {
    final session = await ref
        .read(sessionRepositoryProvider)
        .findById(sessionId);
    if (session == null) throw StateError('No session $sessionId');
    final controller = SessionController(
      workout: session.workout,
      clock: ref.read(clockProvider),
      startedAt: session.startedAt,
    );
    _controller = controller;
    final subscription = controller.changes.listen(
      (next) => state = AsyncData(next),
    );
    ref.onDispose(() {
      subscription.cancel();
      controller.dispose();
    });
    return controller.state;
  }

  SessionState get _state => _controller.state;

  void selectExercise(int index) {
    final wasResting = _state.phase == SessionPhase.resting;
    final before = restAlertBody(_state);
    _controller.selectExercise(index);
    if (wasResting && restAlertBody(_state) != before) _scheduleAlert();
  }

  void startTimedSet() => _controller.startTimedSet();

  SetLog completeSet({int? reps, double? weight}) {
    final log = _controller.completeSet(reps: reps, weight: weight);
    _afterSet();
    return log;
  }

  void skipRest() {
    _controller.skipRest();
    unawaited(_alerts.cancelRestAlert());
  }

  void addRestTime(Duration extra) {
    _controller.addRestTime(extra);
    _scheduleAlert();
  }

  /// Returns the log of a timed set that just auto-completed, if any.
  SetLog? tick() {
    final log = _controller.tick();
    if (log != null) _afterSet();
    return log;
  }

  void finish() {
    _controller.finish();
    unawaited(_alerts.cancelRestAlert());
    _saveFinish();
  }

  void _afterSet() {
    switch (_state.phase) {
      case SessionPhase.resting:
        _scheduleAlert();
      case SessionPhase.finished:
        _saveFinish();
      case SessionPhase.idle || SessionPhase.performing:
        break;
    }
  }

  void _scheduleAlert() {
    final at = _state.restEndsAt;
    final body = restAlertBody(_state);
    if (at == null || body == null) return;
    // TODO(M5): sound and vibration from settings.
    unawaited(_alerts.scheduleRestAlert(at: at, body: body));
  }

  void _saveFinish() {
    final finishedAt = _state.finishedAt;
    if (_finishSaved || finishedAt == null) return;
    _finishSaved = true;
    unawaited(
      ref
          .read(sessionRepositoryProvider)
          .finish(sessionId, finishedAt)
          .catchError((Object e) => debugPrint('Could not save finish: $e')),
    );
  }
}
