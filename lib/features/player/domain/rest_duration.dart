import '../../../models/workout.dart';

/// Rest after a set of the exercise at [exerciseIndex]:
/// exercise `restSeconds` → workout `defaultRestSeconds` (which defaults to
/// 90 at import).
Duration restAfterSet(Workout workout, int exerciseIndex) =>
    Duration(seconds: workout.restSecondsFor(workout.exercises[exerciseIndex]));
