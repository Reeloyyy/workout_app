import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/workout_plan.dart';

/// Thrown when an imported plan JSON fails validation.
class PlanValidationException implements Exception {
  final String message;
  PlanValidationException(this.message);

  @override
  String toString() => message;
}

/// Parses and validates workout plan JSON, producing a [WorkoutPlan].
class JsonImportService {
  JsonImportService._();

  static const _uuid = Uuid();

  static WorkoutPlan parsePlan(String jsonString) {
    late final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      throw PlanValidationException('This file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw PlanValidationException('The plan file must contain a JSON object.');
    }

    final planName = decoded['planName'];
    if (planName is! String || planName.trim().isEmpty) {
      throw PlanValidationException('"planName" must be a non-empty string.');
    }

    final days = decoded['days'];
    if (days is! List || days.isEmpty) {
      throw PlanValidationException('"days" must be a non-empty array.');
    }

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      if (day is! Map<String, dynamic>) {
        throw PlanValidationException('Day at index $i must be an object.');
      }
      if (day['key'] is! String || (day['key'] as String).trim().isEmpty) {
        throw PlanValidationException('Day at index $i is missing a valid "key".');
      }
      if (day['label'] is! String || (day['label'] as String).trim().isEmpty) {
        throw PlanValidationException('Day at index $i is missing a valid "label".');
      }
      if (day['title'] is! String || (day['title'] as String).trim().isEmpty) {
        throw PlanValidationException('Day at index $i is missing a valid "title".');
      }
      final exercises = day['exercises'];
      if (exercises is! List) {
        throw PlanValidationException('Day "${day['label']}" is missing an "exercises" array.');
      }
      for (var j = 0; j < exercises.length; j++) {
        final exercise = exercises[j];
        if (exercise is! Map<String, dynamic>) {
          throw PlanValidationException(
              'Exercise at index $j in day "${day['label']}" must be an object.');
        }
        if (exercise['name'] is! String || (exercise['name'] as String).trim().isEmpty) {
          throw PlanValidationException(
              'Exercise at index $j in day "${day['label']}" is missing a valid "name".');
        }
        if (exercise['sets'] is! String || (exercise['sets'] as String).trim().isEmpty) {
          throw PlanValidationException(
              'Exercise "${exercise['name']}" is missing a valid "sets" value.');
        }
      }
    }

    return WorkoutPlan.fromJson(decoded, id: _uuid.v4());
  }
}
