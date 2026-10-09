import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers.dart';
import '../../../models/workout.dart';
import '../../import/domain/workout_parser.dart';
import 'workout_overview.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.id});

  final int id;

  Future<void> _export(BuildContext context, Workout workout) async {
    await Clipboard.setData(ClipboardData(text: exportWorkouts([workout])));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Workout JSON copied to the clipboard.')),
      );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedWorkout saved,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text(
          '"${saved.workout.name}" will be removed. Its history is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(workoutRepositoryProvider).delete(saved.id);
      if (context.mounted) context.go('/');
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The workout could not be deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(workoutProvider(id));
    return switch (saved) {
      AsyncData(value: final saved?) => Scaffold(
        appBar: AppBar(
          title: Text(saved.workout.name),
          actions: [
            IconButton(
              onPressed: () => _export(context, saved.workout),
              tooltip: 'Export',
              icon: const Icon(Icons.copy_all_outlined),
            ),
            IconButton(
              onPressed: () => _delete(context, ref, saved),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [WorkoutOverview(workout: saved.workout, showName: false)],
        ),
      ),
      AsyncData() => const _Message('This workout no longer exists.'),
      AsyncError() => const _Message('This workout could not be loaded.'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
      ),
    );
  }
}
