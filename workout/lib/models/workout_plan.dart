import 'package:hive/hive.dart';
import 'workout_day.dart';

part 'workout_plan.g.dart';

@HiveType(typeId: 0)
class WorkoutPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String planName;

  @HiveField(2)
  String? weekNote;

  @HiveField(3)
  List<WorkoutDay> days;

  @HiveField(4)
  DateTime importedAt;

  WorkoutPlan({
    required this.id,
    required this.planName,
    this.weekNote,
    required this.days,
    required this.importedAt,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json, {required String id}) {
    final daysJson = (json['days'] as List<dynamic>? ?? []);
    return WorkoutPlan(
      id: id,
      planName: json['planName'] as String,
      weekNote: json['weekNote'] as String?,
      days: daysJson
          .map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      importedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planName': planName,
      'weekNote': weekNote,
      'days': days.map((d) => d.toJson()).toList(),
    };
  }
}
