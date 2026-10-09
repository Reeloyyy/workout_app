import 'package:flutter_test/flutter_test.dart';
import 'package:workout_app/features/import/domain/unique_name.dart';

void main() {
  test('free name is kept', () {
    expect(uniqueName('Legs', ['Push']), 'Legs');
  });

  test('taken name gets the next free number, ignoring case', () {
    expect(uniqueName('Legs', ['legs']), 'Legs (2)');
    expect(uniqueName('Legs', ['Legs', 'Legs (2)']), 'Legs (3)');
    expect(uniqueName('Legs', ['Legs', 'Legs (3)']), 'Legs (2)');
  });

  test('result stays within 60 characters', () {
    final long = 'x' * 60;
    final result = uniqueName(long, [long]);
    expect(result, '${'x' * 56} (2)');
    expect(result.length, maxWorkoutNameLength);
  });
}
