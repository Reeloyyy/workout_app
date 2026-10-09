import 'package:flutter/material.dart';

/// − value + control with 56 dp buttons, for reps and weight.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.label,
    required this.value,
    required this.display,
    required this.step,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  /// Spoken name, e.g. "Reps" or "Weight".
  final String label;
  final double value;

  /// What is shown, e.g. "8" or "62.5 kg".
  final String display;
  final double step;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = value - step >= min - 1e-9;
    final canIncrease = value + step <= max + 1e-9;
    return Semantics(
      label: label,
      value: display,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepButton(
                icon: Icons.remove,
                tooltip: 'Less ${label.toLowerCase()}',
                onPressed: canDecrease ? () => onChanged(value - step) : null,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: ExcludeSemantics(
                  child: Text(
                    display,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                tooltip: 'More ${label.toLowerCase()}',
                onPressed: canIncrease ? () => onChanged(value + step) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      constraints: const BoxConstraints.tightFor(width: 56, height: 56),
    );
  }
}
