import 'package:hive/hive.dart';

part 'exercise.g.dart';

@HiveType(typeId: 2)
class Exercise extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String? note;

  @HiveField(2)
  String sets;

  Exercise({
    required this.name,
    this.note,
    required this.sets,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'] as String,
      note: json['note'] as String?,
      sets: json['sets'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'note': note,
      'sets': sets,
    };
  }
}
