/// One problem found while importing workout JSON.
class ImportIssue {
  const ImportIssue({
    required this.path,
    required this.message,
    this.isWarning = false,
  });

  /// Machine-readable location, e.g. `workouts[0].exercises[2].durationSeconds`.
  /// Empty for problems with the document as a whole.
  final String path;

  /// Plain-language message shown to the user, including where the problem is.
  final String message;

  /// Warnings do not block the import.
  final bool isWarning;

  @override
  bool operator ==(Object other) =>
      other is ImportIssue &&
      other.path == path &&
      other.message == message &&
      other.isWarning == isWarning;

  @override
  int get hashCode => Object.hash(path, message, isWarning);

  @override
  String toString() =>
      '${isWarning ? 'Warning' : 'Error'} at "$path": $message';
}
