import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise.dart';
import 'domain/workout_parser.dart';

/// Unit given to imported exercises that do not name one.
// TODO(M5): read from settings.
final defaultUnitProvider = Provider<WeightUnit>((ref) => WeightUnit.kg);

/// The latest validation result, shared by the import and preview screens.
final importResultProvider = NotifierProvider<ImportNotifier, ImportResult?>(
  ImportNotifier.new,
);

class ImportNotifier extends Notifier<ImportResult?> {
  @override
  ImportResult? build() => null;

  ImportResult validate(String json) {
    final result = parseWorkouts(
      json,
      defaultUnit: ref.read(defaultUnitProvider),
    );
    state = result;
    return result;
  }

  void clear() => state = null;
}
