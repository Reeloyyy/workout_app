import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../models/workout.dart';
import '../../library/ui/workout_overview.dart';
import '../domain/unique_name.dart';
import '../domain/workout_parser.dart';
import '../import_providers.dart';
import 'import_issue_list.dart';

/// Read-only view of validated workouts, with Save.
///
/// Only reachable with an [ImportSuccess]; the router sends other visits back
/// to the import screen.
class ImportPreviewScreen extends ConsumerStatefulWidget {
  const ImportPreviewScreen({super.key});

  @override
  ConsumerState<ImportPreviewScreen> createState() =>
      _ImportPreviewScreenState();
}

enum _DuplicateChoice { replace, keepBoth }

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  bool _saving = false;

  /// Asks about each workout whose name is already in the library, then saves
  /// everything in one transaction. Cancel on any dialog saves nothing.
  Future<void> _save(List<Workout> workouts) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final existing = await repo.names();
      final inserts = <Workout>[];
      final replacements = <int, Workout>{};
      final taken = existing.values.toList();
      final namesInBatch = <String>{};

      for (final workout in workouts) {
        var toSave = workout;
        final match = existing.entries
            .where((e) => e.value.toLowerCase() == workout.name.toLowerCase())
            .firstOrNull;
        final key = workout.name.toLowerCase();

        if (namesInBatch.contains(key)) {
          // Same name twice in one file: number the later one.
          toSave = workout.copyWith(name: uniqueName(workout.name, taken));
          inserts.add(toSave);
        } else if (match != null) {
          if (!mounted) return;
          final choice = await _askAboutDuplicate(workout.name);
          switch (choice) {
            case null:
              return;
            case _DuplicateChoice.replace:
              replacements[match.key] = workout;
            case _DuplicateChoice.keepBoth:
              toSave = workout.copyWith(name: uniqueName(workout.name, taken));
              inserts.add(toSave);
          }
        } else {
          inserts.add(workout);
        }
        namesInBatch.add(key);
        taken.add(toSave.name);
      }

      await repo.saveAll(inserts: inserts, replacements: replacements);
      if (!mounted) return;
      final count = workouts.length;
      ref.read(importResultProvider.notifier).clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              count == 1 ? 'Workout saved.' : '$count workouts saved.',
            ),
          ),
        );
      context.go('/');
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The workouts could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_DuplicateChoice?> _askAboutDuplicate(String name) {
    return showDialog<_DuplicateChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name already exists'),
        content: Text('A workout named "$name" is already saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DuplicateChoice.keepBoth),
            child: const Text('Keep both'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _DuplicateChoice.replace),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(importResultProvider);
    // Cleared after saving, while the route animates away.
    if (result is! ImportSuccess) return const Scaffold();

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
          for (final workout in result.workouts)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: WorkoutOverview(workout: workout),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => context.pop(),
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : () => _save(result.workouts),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
