import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/widgets/value_stepper.dart';
import '../../../data/providers.dart';
import '../../../models/exercise.dart';
import '../../../services/screen_awake.dart';
import '../../../services/service_providers.dart';
import '../domain/player_text.dart';
import '../domain/session_state.dart';
import '../player_providers.dart';
import 'rest_view.dart';

/// The workout player (AGENTS.md §7.2). Shows state from [playerProvider]
/// and calls its intents; the stepper values are the only local state.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  static const _tickInterval = Duration(milliseconds: 250);

  late final ScreenAwake _screenAwake;
  late final Timer _ticker;
  late final AppLifecycleListener _lifecycle;
  DateTime? _lastDrawn;

  /// Stepper values per exercise index, once the user changed them.
  final Map<int, int> _reps = {};
  final Map<int, double> _weights = {};

  AsyncNotifierProvider<PlayerNotifier, SessionState> get _provider =>
      playerProvider(widget.sessionId);

  PlayerNotifier get _player => ref.read(_provider.notifier);

  @override
  void initState() {
    super.initState();
    _screenAwake = ref.read(screenAwakeProvider);
    unawaited(_screenAwake.keepOn(true));
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
    // Remaining time is recomputed from the clock on resume.
    _lifecycle = AppLifecycleListener(onResume: _tick);
  }

  @override
  void dispose() {
    _ticker.cancel();
    _lifecycle.dispose();
    unawaited(_screenAwake.keepOn(false));
    super.dispose();
  }

  void _tick() {
    if (!mounted || ref.read(_provider) is! AsyncData) return;
    final autoCompleted = _player.tick();
    if (autoCompleted != null) unawaited(HapticFeedback.vibrate());
    // Redraw countdowns and elapsed time only when the time moved.
    final now = ref.read(clockProvider).now();
    if (now != _lastDrawn) setState(() => _lastDrawn = now);
  }

  int _repsFor(int index, Exercise exercise) =>
      _reps[index] ?? exercise.reps ?? 0;

  /// Null means the exercise is done without weight.
  double? _weightFor(int index, Exercise exercise) =>
      _weights[index] ?? exercise.weight;

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text('Progress is saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    // Navigator.pop does not consult PopScope, so this leaves.
    if (leave == true && mounted) context.pop();
  }

  Future<void> _confirmFinish(SessionState state) async {
    final left = state.totalSets - state.logs.length;
    if (left > 0) {
      final finish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish workout?'),
          content: Text(
            left == 1 ? '1 set is not done.' : '$left sets are not done.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finish'),
            ),
          ],
        ),
      );
      if (finish != true || !mounted) return;
    }
    _player.finish();
  }

  Future<void> _chooseNext(SessionState state) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < state.workout.exercises.length; i++)
              if (!state.isExerciseDone(i))
                ListTile(
                  title: Text(state.workout.exercises[i].name),
                  subtitle: Text(
                    '${state.setsDone(i)}/${state.workout.exercises[i].sets} sets',
                  ),
                  selected: i == state.upNextIndex,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _player.selectExercise(i);
                  },
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_provider, (previous, next) {
      final wasFinished = previous?.value?.phase == SessionPhase.finished;
      if (next.value?.phase == SessionPhase.finished && !wasFinished) {
        // TODO(M4): go to the session summary instead.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Workout finished.')));
        context.go('/');
      }
    });

    return switch (ref.watch(_provider)) {
      AsyncData(:final value) => _buildPlayer(value),
      AsyncError() => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This workout could not be opened.')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _buildPlayer(SessionState state) {
    final now = ref.read(clockProvider).now();
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: state.phase == SessionPhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.workout.name, overflow: TextOverflow.ellipsis),
                  Text(
                    formatClock(state.elapsed(now)),
                    style: text.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    semanticsLabel:
                        'Elapsed ${formatClock(state.elapsed(now))}',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => _confirmFinish(state),
                  child: const Text('Finish'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                for (var i = 0; i < state.workout.exercises.length; i++)
                  _exerciseCard(state, i, now),
              ],
            ),
          ),
          if (state.phase == SessionPhase.resting)
            Positioned.fill(
              child: RestView(
                state: state,
                now: now,
                onAddTime: () =>
                    _player.addRestTime(const Duration(seconds: 15)),
                onSkip: _player.skipRest,
                onChangeNext: () => _chooseNext(state),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exerciseCard(SessionState state, int index, DateTime now) {
    final exercise = state.workout.exercises[index];
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = state.isExerciseDone(index);
    final active =
        state.phase == SessionPhase.performing &&
        state.activeExerciseIndex == index;
    final highlighted =
        state.phase == SessionPhase.idle && state.nextUnfinishedIndex == index;
    final notes = exercise.notes;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: active || highlighted
            ? BorderSide(color: colors.primary, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: done || active ? null : () => _player.selectExercise(index),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exercise.name, style: text.titleMedium),
                          Text(formatTarget(exercise)),
                          if (active && notes != null)
                            Text(notes, style: text.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${state.setsDone(index)}/${exercise.sets}',
                      style: text.titleMedium,
                      semanticsLabel:
                          '${state.setsDone(index)} of ${exercise.sets} sets done',
                    ),
                    if (done) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        color: colors.primary,
                        semanticLabel: 'Done',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (active) ..._setRows(state, index, exercise, now),
        ],
      ),
    );
  }

  List<Widget> _setRows(
    SessionState state,
    int index,
    Exercise exercise,
    DateTime now,
  ) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final logs = state.logs.where((l) => l.exercisePosition == index).toList();
    final current = logs.length + 1;
    return [
      const Divider(height: 1),
      for (var set = 1; set <= exercise.sets; set++)
        if (set < current)
          ListTile(
            leading: Text('Set $set'),
            title: Text(formatSetLog(logs[set - 1])),
            trailing: const Icon(Icons.check, semanticLabel: 'Done'),
          )
        else if (set == current)
          exercise.type == ExerciseType.timed
              ? _timedSet(state, set, exercise, now)
              : _repsSet(index, set, exercise)
        else
          ListTile(
            leading: Text('Set $set'),
            title: Text(formatSetTarget(exercise), style: muted),
          ),
      const SizedBox(height: 8),
    ];
  }

  Widget _repsSet(int index, int set, Exercise exercise) {
    final reps = _repsFor(index, exercise);
    final weight = _weightFor(index, exercise);
    final step = exercise.unit == WeightUnit.kg ? 2.5 : 5.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set $set', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ValueStepper(
                label: 'Reps',
                value: reps.toDouble(),
                display: '$reps',
                step: 1,
                min: 0,
                max: 200,
                onChanged: (v) => setState(() => _reps[index] = v.round()),
              ),
              if (weight == null)
                TextButton.icon(
                  onPressed: () => setState(() => _weights[index] = 0),
                  icon: const Icon(Icons.add),
                  label: const Text('Add weight'),
                )
              else
                ValueStepper(
                  label: 'Weight',
                  value: weight,
                  display: formatWeightWithUnit(weight, exercise.unit),
                  step: step,
                  min: 0,
                  max: 2000,
                  onChanged: (v) => setState(() => _weights[index] = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _player.completeSet(reps: reps, weight: weight),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _timedSet(
    SessionState state,
    int set,
    Exercise exercise,
    DateTime now,
  ) {
    final running = state.isTimedSetRunning;
    final shown = running
        ? formatClock(state.timedSetRemaining(now))
        : formatClock(Duration(seconds: exercise.durationSeconds ?? 0));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set $set', style: Theme.of(context).textTheme.titleSmall),
          Center(
            child: Text(
              shown,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              semanticsLabel: running ? '$shown left' : shown,
            ),
          ),
          const SizedBox(height: 12),
          if (running)
            FilledButton(
              onPressed: () => _player.completeSet(weight: exercise.weight),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Text('Done'),
            )
          else
            FilledButton.icon(
              onPressed: _player.startTimedSet,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
        ],
      ),
    );
  }
}
