import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../domain/player_text.dart';
import '../domain/session_state.dart';
import 'breathing_circle.dart';

/// Full-screen rest view over the player: countdown in a progress ring,
/// breathing cue, what comes next, +15 s and Skip.
class RestView extends StatelessWidget {
  const RestView({
    super.key,
    required this.state,
    required this.now,
    required this.onAddTime,
    required this.onSkip,
    required this.onChangeNext,
  });

  final SessionState state;
  final DateTime now;
  final VoidCallback onAddTime;
  final VoidCallback onSkip;

  /// Opens the exercise chooser (selecting during rest is allowed).
  final VoidCallback onChangeNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final remaining = state.restRemaining(now);
    final total = state.restTotal;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : remaining.inMilliseconds / total.inMilliseconds;
    final next = upNextLabel(state);

    return Material(
      color: colors.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Rest', style: text.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox.square(
                    dimension: 240,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress.clamp(0, 1),
                          strokeWidth: 10,
                          backgroundColor: colors.surfaceContainerHighest,
                          semanticsLabel: 'Rest remaining',
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: FittedBox(
                              child: Text(
                                formatClock(remaining),
                                style: text.displayLarge?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const BreathingCircle(size: 96),
                  const SizedBox(height: 24),
                  if (next != null) ...[
                    Text(
                      next,
                      style: text.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: onChangeNext,
                      child: const Text('Change exercise'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: onAddTime,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 56),
                        ),
                        child: const Text('+15 s'),
                      ),
                      FilledButton(
                        onPressed: onSkip,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 56),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
