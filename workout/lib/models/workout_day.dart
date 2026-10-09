import 'package:hive/hive.dart';
import 'exercise.dart';

part 'workout_day.g.dart';

@HiveType(typeId: 1)
class WorkoutDay extends HiveObject {
  @HiveField(0)
  String dayKey;

  @HiveField(1)
  String label;

  @HiveField(2)
  String title;

  @HiveField(3)
  String focus;

  @HiveField(4)
  String badge;

  @HiveField(5)
  String? badgeColor;

  @HiveField(6)
  String? tip;

  @HiveField(7)
  List<Exercise> exercises;

  WorkoutDay({
    required this.dayKey,
    required this.label,
    required this.title,
    required this.focus,
    required this.badge,
    this.badgeColor,
    this.tip,
    required this.exercises,
  });

  bool get isRestDay => exercises.isEmpty;

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    final exercisesJson = (json['exercises'] as List<dynamic>? ?? []);
    return WorkoutDay(
      dayKey: json['key'] as String,
      label: json['label'] as String,
      title: json['title'] as String,
      focus: json['focus'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
      badgeColor: json['badgeColor'] as String?,
      tip: json['tip'] as String?,
      exercises: exercisesJson
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': dayKey,
      'label': label,
      'title': title,
      'focus': focus,
      'badge': badge,
      'badgeColor': badgeColor,
      'tip': tip,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}
