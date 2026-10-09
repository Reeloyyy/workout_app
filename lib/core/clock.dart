/// Source of the current time.
///
/// Everything that needs "now" takes a [Clock] so tests can control time.
/// [SystemClock] is the only place allowed to call `DateTime.now()`.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
