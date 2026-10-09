/// Longest workout name the JSON format accepts.
const int maxWorkoutNameLength = 60;

/// [name] if no name in [taken] matches it (ignoring case), otherwise
/// "name (2)", "name (3)", … — the first that is free.
///
/// The base is shortened when needed so the result stays within
/// [maxWorkoutNameLength] and still re-imports.
String uniqueName(String name, Iterable<String> taken) {
  final used = {for (final t in taken) t.toLowerCase()};
  if (!used.contains(name.toLowerCase())) return name;
  for (var n = 2; ; n++) {
    final suffix = ' ($n)';
    final room = maxWorkoutNameLength - suffix.length;
    final base = name.length > room
        ? name.substring(0, room).trimRight()
        : name;
    final candidate = '$base$suffix';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}
