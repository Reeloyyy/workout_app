import 'package:workout_app/core/clock.dart';

/// A clock tests can set and advance.
class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration by) => current = current.add(by);
}
