import 'package:hive/hive.dart';

part 'weight_entry.g.dart';

@HiveType(typeId: 4)
class WeightEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double value;

  WeightEntry({
    required this.id,
    required this.date,
    required this.value,
  });
}
