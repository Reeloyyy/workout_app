import 'package:flutter/material.dart';

import '../models/workout_day.dart';
import '../theme/app_theme.dart';

/// Horizontally scrollable row of day tabs, with a checkmark for completed days.
class DaySelector extends StatelessWidget {
  final List<WorkoutDay> days;
  final String selectedKey;
  final Set<String> completedDayKeys;
  final ValueChanged<String> onSelect;

  const DaySelector({
    super.key,
    required this.days,
    required this.selectedKey,
    required this.completedDayKeys,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day.dayKey == selectedKey;
          final isCompleted = completedDayKeys.contains(day.dayKey);

          return GestureDetector(
            onTap: () => onSelect(day.dayKey),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? accentBlue : surfaceColor,
                borderRadius: BorderRadius.circular(pillRadius),
                border: Border.all(
                  color: isSelected ? accentBlue : borderColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: isSelected ? Colors.white : accentGreen,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
