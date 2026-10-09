// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_day.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutDayAdapter extends TypeAdapter<WorkoutDay> {
  @override
  final int typeId = 1;

  @override
  WorkoutDay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutDay(
      dayKey: fields[0] as String,
      label: fields[1] as String,
      title: fields[2] as String,
      focus: fields[3] as String,
      badge: fields[4] as String,
      badgeColor: fields[5] as String?,
      tip: fields[6] as String?,
      exercises: (fields[7] as List).cast<Exercise>(),
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutDay obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.dayKey)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.focus)
      ..writeByte(4)
      ..write(obj.badge)
      ..writeByte(5)
      ..write(obj.badgeColor)
      ..writeByte(6)
      ..write(obj.tip)
      ..writeByte(7)
      ..write(obj.exercises);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutDayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
