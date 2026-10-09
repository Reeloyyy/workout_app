import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../models/workout.dart';

/// A workout's description, tags and exercises (target, rest, notes), as the
/// player shows them. Used by the import preview and the workout detail.
class WorkoutOverview extends StatelessWidget {
  const WorkoutOverview({
    super.key,
    required this.workout,
    this.showName = true,
  });

  final Workout workout;

  /// False where the name is already the screen title.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final description = workout.description;
    final hasHeader =
        showName || description != null || workout.tags.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName) Text(workout.name, style: text.titleLarge),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description),
                ],
                if (workout.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(workout.tags.join(' · '), style: text.bodySmall),
                ],
              ],
            ),
          ),
        for (final exercise in workout.exercises)
          ListTile(
            title: Text(exercise.name),
            subtitle: Text(
              [
                '${formatTarget(exercise)} · '
                    '${formatRest(workout.restSecondsFor(exercise))}',
                ?exercise.notes,
              ].join('\n'),
            ),
          ),
      ],
    );
  }
}
