import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while the player is open.
class ScreenAwake {
  const ScreenAwake();

  Future<void> keepOn(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } on Object {
      // Not critical: the screen may dim, the workout continues.
    }
  }
}
