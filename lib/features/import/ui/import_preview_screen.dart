import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../models/workout.dart';
import '../domain/workout_parser.dart';
import '../import_providers.dart';
import 'import_issue_list.dart';

/// Read-only view of validated workouts before they are saved.
///
/// Only reachable with an [ImportSuccess]; the router sends other visits back
/// to the import screen.
class ImportPreviewScreen extends ConsumerWidget {
  const ImportPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(importResultProvider);
    if (result is! ImportSuccess) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (result.warnings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ImportIssueList(issues: result.warnings),
            ),
          for (final workout in result.workouts) _WorkoutPreview(workout),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutPreview extends StatelessWidget {
  const _WorkoutPreview(this.workout);

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final description = workout.description;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workout.name, style: text.titleLarge),
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
        ),
      ),
    );
  }
}
