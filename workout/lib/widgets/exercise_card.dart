import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../theme/app_theme.dart';

/// A single exercise row with a checkbox, name, sets, and note.
class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool completed;
  final ValueChanged<bool> onToggle;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.completed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: completed ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: completed,
              onChanged: (value) => onToggle(value ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: textPrimary,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      Text(
                        exercise.sets,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (exercise.note != null && exercise.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      exercise.note!,
                      style: const TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
