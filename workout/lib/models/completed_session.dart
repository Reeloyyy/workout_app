import 'package:hive/hive.dart';

part 'completed_session.g.dart';

@HiveType(typeId: 3)
class CompletedSession extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String dayKey;

  @HiveField(3)
  String planId;

  CompletedSession({
    required this.id,
    required this.date,
    required this.dayKey,
    required this.planId,
  });
}
