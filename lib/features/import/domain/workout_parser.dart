import 'dart:convert';

import '../../../models/exercise.dart';
import '../../../models/workout.dart';
import 'import_error.dart';

/// The only workout JSON schema version this app understands.
const int currentSchemaVersion = 1;

sealed class ImportResult {
  const ImportResult();
}

class ImportSuccess extends ImportResult {
  const ImportSuccess({required this.workouts, this.warnings = const []});

  final List<Workout> workouts;
  final List<ImportIssue> warnings;
}

class ImportFailure extends ImportResult {
  const ImportFailure({required this.errors, this.warnings = const []});

  /// Every error found, never just the first.
  final List<ImportIssue> errors;
  final List<ImportIssue> warnings;
}

/// Parses and validates workout JSON (schema version 1).
///
/// Exercises without a `unit` get [defaultUnit].
ImportResult parseWorkouts(String json, {required WeightUnit defaultUnit}) {
  // Whitespace around JSON is legal, so only the BOM is removed before
  // decoding. That keeps reported line numbers matching the user's text.
  final text = json.startsWith('﻿') ? json.substring(1) : json;

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return ImportFailure(
      errors: [ImportIssue(path: '', message: _syntaxMessage(text, e))],
    );
  }
  return _Parser(defaultUnit).parseRoot(decoded);
}

/// Pretty-printed JSON (2-space indent) that re-imports to equal workouts.
///
/// Fields holding their default value are left out. `unit` is always written,
/// because its default depends on the importing phone's settings.
String exportWorkouts(List<Workout> workouts) {
  final document = <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'workouts': [for (final workout in workouts) _workoutToJson(workout)],
  };
  return const JsonEncoder.withIndent('  ').convert(document);
}

Map<String, Object?> _workoutToJson(Workout workout) => {
  'name': workout.name,
  if (workout.description != null) 'description': workout.description,
  if (workout.tags.isNotEmpty) 'tags': workout.tags,
  if (workout.defaultRestSeconds != Workout.defaultRest)
    'defaultRestSeconds': workout.defaultRestSeconds,
  'exercises': [for (final e in workout.exercises) _exerciseToJson(e)],
};

Map<String, Object?> _exerciseToJson(Exercise exercise) {
  final isReps = exercise.type == ExerciseType.reps;
  final weight = exercise.weight;
  return {
    'name': exercise.name,
    if (!isReps) 'type': exercise.type.name,
    'sets': exercise.sets,
    if (isReps && exercise.reps != null) 'reps': exercise.reps,
    if (isReps && exercise.repsMax != null) 'repsMax': exercise.repsMax,
    if (!isReps && exercise.durationSeconds != null)
      'durationSeconds': exercise.durationSeconds,
    if (weight != null)
      'weight': weight == weight.truncateToDouble() ? weight.toInt() : weight,
    'unit': exercise.unit.name,
    if (exercise.restSeconds != null) 'restSeconds': exercise.restSeconds,
    if (exercise.notes != null) 'notes': exercise.notes,
    if (exercise.group != null) 'group': exercise.group,
  };
}

String _syntaxMessage(String source, FormatException e) {
  var reason = e.message.trim();
  if (reason.isEmpty) reason = 'Unexpected input';
  if (!reason.endsWith('.')) reason = '$reason.';

  final offset = e.offset;
  if (offset == null) return 'Not valid JSON: $reason';

  final end = offset.clamp(0, source.length);
  var line = 1;
  var lineStart = 0;
  for (var i = 0; i < end; i++) {
    if (source.codeUnitAt(i) == 0x0A) {
      line++;
      lineStart = i + 1;
    }
  }
  final column = end - lineStart + 1;
  return 'Not valid JSON (line $line, column $column): $reason';
}

const _rootFields = {'schemaVersion', 'workouts'};
const _workoutFields = {
  'name',
  'description',
  'tags',
  'defaultRestSeconds',
  'exercises',
};
const _exerciseFields = {
  'name',
  'type',
  'sets',
  'reps',
  'repsMax',
  'durationSeconds',
  'weight',
  'unit',
  'restSeconds',
  'notes',
  'group',
};

/// Where a value sits: [path] for code, [label] for people
/// (e.g. "Push Day A › exercise 3 (Plank)").
class _Place {
  const _Place(this.path, this.label);

  final String path;
  final String label;

  String pathOf(String key) => path.isEmpty ? key : '$path.$key';
}

class _Parser {
  _Parser(this.defaultUnit);

  final WeightUnit defaultUnit;
  final List<ImportIssue> _errors = [];
  final List<ImportIssue> _warnings = [];

  ImportResult parseRoot(Object? root) {
    const place = _Place('', '');
    if (root is! Map<String, Object?>) {
      _error(
        place,
        '',
        'The file must be a JSON object with `schemaVersion` and `workouts`.',
      );
      return _failure();
    }

    final version = _int(root, 'schemaVersion', place, required: true);
    if (version != null && version > currentSchemaVersion) {
      // A newer format may mean anything; do not report its fields as errors.
      return ImportFailure(
        errors: [
          ImportIssue(
            path: place.pathOf('schemaVersion'),
            message: 'This file needs a newer version of the app.',
          ),
        ],
      );
    }
    if (version != null && version != currentSchemaVersion) {
      _error(place, 'schemaVersion', '`schemaVersion` must be 1.');
    }
    _warnUnknown(root, _rootFields, place);

    final list = _list(root, 'workouts', place, required: true);
    final workouts = <Workout?>[];
    if (list != null) {
      if (list.isEmpty) {
        _error(
          place,
          'workouts',
          '`workouts` must contain at least one workout.',
        );
      }
      for (var i = 0; i < list.length; i++) {
        workouts.add(_workout(list[i], i));
      }
    }

    if (_errors.isNotEmpty) return _failure();
    return ImportSuccess(
      workouts: [for (final w in workouts) w!],
      warnings: List.unmodifiable(_warnings),
    );
  }

  Workout? _workout(Object? value, int index) {
    final path = 'workouts[$index]';
    final fallbackLabel = 'Workout ${index + 1}';
    if (value is! Map<String, Object?>) {
      _issue(path, '$fallbackLabel is not a JSON object.');
      return null;
    }
    final errorsBefore = _errors.length;

    // Validate the name first so the other messages can use it as the label.
    final name = _string(
      value,
      'name',
      _Place(path, fallbackLabel),
      required: true,
      min: 1,
      max: 60,
    );
    final place = _Place(path, name ?? fallbackLabel);

    final description = _string(value, 'description', place, max: 300);
    final tags = _tags(value, place);
    final defaultRest = _int(
      value,
      'defaultRestSeconds',
      place,
      min: 0,
      max: 600,
    );
    _warnUnknown(value, _workoutFields, place);

    final list = _list(value, 'exercises', place, required: true);
    final exercises = <Exercise?>[];
    if (list != null) {
      if (list.isEmpty) {
        _error(
          place,
          'exercises',
          '`exercises` must contain at least one exercise.',
        );
      }
      for (var i = 0; i < list.length; i++) {
        exercises.add(_exercise(list[i], i, place));
      }
    }

    if (_errors.length != errorsBefore) return null;
    return Workout(
      name: name!,
      description: description,
      tags: tags ?? const [],
      defaultRestSeconds: defaultRest ?? Workout.defaultRest,
      exercises: [for (final e in exercises) e!],
    );
  }

  Exercise? _exercise(Object? value, int index, _Place workout) {
    final path = workout.pathOf('exercises[$index]');
    final baseLabel = '${workout.label} › exercise ${index + 1}';
    if (value is! Map<String, Object?>) {
      _issue(path, '$baseLabel is not a JSON object.');
      return null;
    }
    final errorsBefore = _errors.length;

    final name = _string(
      value,
      'name',
      _Place(path, baseLabel),
      required: true,
      min: 1,
      max: 60,
    );
    final place = _Place(path, name == null ? baseLabel : '$baseLabel ($name)');

    var type = ExerciseType.reps;
    var typeKnown = true;
    final typeText = _string(value, 'type', place);
    if (typeText != null) {
      final parsed = ExerciseType.fromJson(typeText);
      if (parsed == null) {
        typeKnown = false;
        _error(place, 'type', '`type` must be "reps" or "timed".');
      } else {
        type = parsed;
      }
    }

    final sets = _int(value, 'sets', place, required: true, min: 1, max: 20);

    int? reps;
    int? repsMax;
    int? duration;
    if (!typeKnown) {
      // Without a valid type it is unknown which of these is required, so
      // only check the values that are present.
      _int(value, 'reps', place, min: 1, max: 200);
      _int(value, 'repsMax', place, min: 1, max: 200);
      _int(value, 'durationSeconds', place, min: 1, max: 3600);
    } else if (type == ExerciseType.reps) {
      reps = _int(
        value,
        'reps',
        place,
        min: 1,
        max: 200,
        missingMessage: '`reps` is required for reps exercises.',
      );
      repsMax = _repsMax(value, place, reps);
      _warnIgnored(value, 'durationSeconds', place, 'reps');
    } else {
      duration = _int(
        value,
        'durationSeconds',
        place,
        min: 1,
        max: 3600,
        missingMessage: '`durationSeconds` is required for timed exercises.',
      );
      _warnIgnored(value, 'reps', place, 'timed');
      _warnIgnored(value, 'repsMax', place, 'timed');
    }

    final weight = _weight(value, place);
    var unit = defaultUnit;
    final unitText = _string(value, 'unit', place);
    if (unitText != null) {
      final parsed = WeightUnit.fromJson(unitText);
      if (parsed == null) {
        _error(place, 'unit', '`unit` must be "kg" or "lb".');
      } else {
        unit = parsed;
      }
    }
    final rest = _int(value, 'restSeconds', place, min: 0, max: 600);
    final notes = _string(value, 'notes', place, max: 300);
    final group = _string(value, 'group', place);
    _warnUnknown(value, _exerciseFields, place);

    if (_errors.length != errorsBefore) return null;
    return Exercise(
      name: name!,
      type: type,
      sets: sets!,
      reps: reps,
      repsMax: repsMax,
      durationSeconds: duration,
      weight: weight,
      unit: unit,
      restSeconds: rest,
      notes: notes,
      group: group,
    );
  }

  int? _repsMax(Map<String, Object?> map, _Place place, int? reps) {
    final value = _int(map, 'repsMax', place);
    if (value == null) return null;
    if (value > 200) {
      _error(place, 'repsMax', '`repsMax` must be 200 or less.');
      return null;
    }
    if (reps != null && value < reps) {
      _error(place, 'repsMax', '`repsMax` must be at least `reps` ($reps).');
      return null;
    }
    if (value < 1) {
      _error(place, 'repsMax', '`repsMax` must be at least 1.');
      return null;
    }
    return value;
  }

  double? _weight(Map<String, Object?> map, _Place place) {
    final value = map['weight'];
    if (value == null) return null;
    if (value is! num || !value.isFinite) {
      _error(place, 'weight', '`weight` must be a number.');
      return null;
    }
    if (value < 0 || value > 2000) {
      _error(place, 'weight', '`weight` must be between 0 and 2000.');
      return null;
    }
    return value.toDouble();
  }

  List<String>? _tags(Map<String, Object?> map, _Place place) {
    final list = _list(map, 'tags', place);
    if (list == null) return null;
    if (list.length > 10) {
      _error(place, 'tags', '`tags` can have at most 10 items.');
      return null;
    }
    final tags = <String>[];
    for (var i = 0; i < list.length; i++) {
      final key = 'tags[$i]';
      final item = list[i];
      if (item is! String) {
        _error(place, key, '`$key` must be text.');
        continue;
      }
      final tag = item.trim();
      if (tag.isEmpty || tag.length > 30) {
        _error(place, key, '`$key` must be between 1 and 30 characters.');
        continue;
      }
      tags.add(tag);
    }
    return tags;
  }

  /// Reads an optional (or [required]) string, trimmed. An empty optional
  /// string counts as absent.
  String? _string(
    Map<String, Object?> map,
    String key,
    _Place place, {
    bool required = false,
    int min = 0,
    int? max,
  }) {
    final value = map[key];
    if (value == null) {
      if (required) _error(place, key, '`$key` is required.');
      return null;
    }
    if (value is! String) {
      _error(place, key, '`$key` must be text.');
      return null;
    }
    final text = value.trim();
    final tooShort = text.length < min;
    final tooLong = max != null && text.length > max;
    if (tooShort || tooLong) {
      _error(
        place,
        key,
        min > 0
            ? '`$key` must be between $min and $max characters.'
            : '`$key` must be $max characters or fewer.',
      );
      return null;
    }
    return text.isEmpty ? null : text;
  }

  /// Reads a whole number. Accepts `90.0`, rejects `90.5`.
  int? _int(
    Map<String, Object?> map,
    String key,
    _Place place, {
    bool required = false,
    String? missingMessage,
    int? min,
    int? max,
  }) {
    final value = map[key];
    if (value == null) {
      if (required || missingMessage != null) {
        _error(place, key, missingMessage ?? '`$key` is required.');
      }
      return null;
    }
    final int number;
    if (value is int) {
      number = value;
    } else if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      number = value.toInt();
    } else {
      _error(place, key, '`$key` must be a whole number.');
      return null;
    }
    if ((min != null && number < min) || (max != null && number > max)) {
      _error(place, key, '`$key` must be between $min and $max.');
      return null;
    }
    return number;
  }

  List<Object?>? _list(
    Map<String, Object?> map,
    String key,
    _Place place, {
    bool required = false,
  }) {
    final value = map[key];
    if (value == null) {
      if (required) _error(place, key, '`$key` is required.');
      return null;
    }
    if (value is! List<Object?>) {
      _error(place, key, '`$key` must be a list.');
      return null;
    }
    return value;
  }

  void _warnUnknown(Map<String, Object?> map, Set<String> known, _Place place) {
    for (final key in map.keys) {
      if (!known.contains(key)) {
        _warning(place, key, 'Unknown field `$key` was ignored.');
      }
    }
  }

  void _warnIgnored(
    Map<String, Object?> map,
    String key,
    _Place place,
    String typeName,
  ) {
    if (map[key] != null) {
      _warning(place, key, '`$key` is ignored for $typeName exercises.');
    }
  }

  void _error(_Place place, String key, String message) =>
      _issue(place.pathOf(key), _located(place, message));

  void _warning(_Place place, String key, String message) => _warnings.add(
    ImportIssue(
      path: place.pathOf(key),
      message: _located(place, message),
      isWarning: true,
    ),
  );

  void _issue(String path, String message) =>
      _errors.add(ImportIssue(path: path, message: message));

  String _located(_Place place, String message) =>
      place.label.isEmpty ? message : '${place.label}: $message';

  ImportFailure _failure() => ImportFailure(
    errors: List.unmodifiable(_errors),
    warnings: List.unmodifiable(_warnings),
  );
}
