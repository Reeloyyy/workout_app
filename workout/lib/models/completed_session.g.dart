// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completed_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CompletedSessionAdapter extends TypeAdapter<CompletedSession> {
  @override
  final int typeId = 3;

  @override
  CompletedSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CompletedSession(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      dayKey: fields[2] as String,
      planId: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CompletedSession obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.dayKey)
      ..writeByte(3)
      ..write(obj.planId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
