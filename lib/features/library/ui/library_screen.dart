import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../models/workout.dart';
import '../../import/domain/unique_name.dart';
import '../../import/domain/workout_parser.dart';
import '../../import/import_providers.dart';

/// Asset with the example workout from the spec.
const sampleWorkoutAsset = 'assets/sample_workout.json';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(workoutSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/import'),
        tooltip: 'Import',
        child: const Icon(Icons.add),
      ),
      body: switch (summaries) {
        AsyncData(:final value) when value.isEmpty => const _EmptyLibrary(),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [for (final summary in value) _WorkoutTile(summary)],
        ),
        AsyncError() => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Your workouts could not be loaded.'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile(this.summary);

  final WorkoutSummary summary;

  @override
  Widget build(BuildContext context) {
    final count = summary.exerciseCount;
    final lastDone = summary.lastDone;
    final when = lastDone == null
        ? 'Not done yet'
        : 'Last done ${MaterialLocalizations.of(context).formatMediumDate(lastDone)}';
    return ListTile(
      title: Text(summary.name),
      subtitle: Text('$count ${count == 1 ? 'exercise' : 'exercises'} · $when'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/workout/${summary.id}'),
    );
  }
}

class _EmptyLibrary extends ConsumerStatefulWidget {
  const _EmptyLibrary();

  @override
  ConsumerState<_EmptyLibrary> createState() => _EmptyLibraryState();
}

class _EmptyLibraryState extends ConsumerState<_EmptyLibrary> {
  bool _adding = false;

  Future<void> _addSample() async {
    setState(() => _adding = true);
    try {
      final json = await rootBundle.loadString(sampleWorkoutAsset);
      final result = parseWorkouts(
        json,
        defaultUnit: ref.read(defaultUnitProvider),
      );
      // The bundled sample is covered by tests, so this always succeeds.
      final workout = (result as ImportSuccess).workouts.single;
      final repo = ref.read(workoutRepositoryProvider);
      final taken = (await repo.names()).values;
      await repo.insert(
        workout.copyWith(name: uniqueName(workout.name, taken)),
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The sample could not be added.')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No workouts yet', style: text.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Workouts are added as JSON. Tap Import, then paste the JSON '
              'or choose a .json file.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/import'),
              icon: const Icon(Icons.add),
              label: const Text('Import'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _adding ? null : _addSample,
              child: const Text('Add sample workout'),
            ),
          ],
        ),
      ),
    );
  }
}
