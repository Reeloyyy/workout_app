import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/completed_session.dart';
import '../models/workout_day.dart';
import '../models/workout_plan.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../widgets/day_selector.dart';
import '../widgets/exercise_card.dart';

const List<String> kWeekDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// The main daily-use screen: shows the active plan's exercises for a chosen day.
class WorkoutScreen extends StatefulWidget {
  final VoidCallback onGoToSettings;

  const WorkoutScreen({super.key, required this.onGoToSettings});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  static const _uuid = Uuid();

  late String _selectedDayKey;
  List<bool> _checks = [];
  Set<String> _completedDayKeysThisWeek = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDayKey = kWeekDayKeys[today.weekday - 1];
    _loadState();
  }

  DateTime get _weekStart {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return startOfDay.subtract(Duration(days: today.weekday - 1));
  }

  DateTime _dateForDayKey(String dayKey) {
    final offset = kWeekDayKeys.indexOf(dayKey);
    if (offset < 0) return DateTime.now();
    return _weekStart.add(Duration(days: offset));
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  WorkoutPlan? get _activePlan {
    final id = HiveService.activePlanId;
    if (id == null) return null;
    try {
      return HiveService.plansBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String _prefsKey(String planId, String dayKey, DateTime date) {
    return 'checks_${planId}_${dayKey}_${_formatDate(date)}';
  }

  Future<void> _loadState() async {
    final plan = _activePlan;
    if (plan == null) {
      setState(() => _loading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final completed = <String>{};
    for (final day in plan.days) {
      if (day.isRestDay) continue;
      final date = _dateForDayKey(day.dayKey);
      final raw = prefs.getString(_prefsKey(plan.id, day.dayKey, date));
      if (raw == null) continue;
      final checks = (jsonDecode(raw) as List<dynamic>).cast<bool>();
      if (checks.isNotEmpty && checks.every((c) => c)) {
        completed.add(day.dayKey);
      }
    }

    final selectedDay = _dayForKey(plan, _selectedDayKey);
    List<bool> checks = [];
    if (selectedDay != null && !selectedDay.isRestDay) {
      final date = _dateForDayKey(selectedDay.dayKey);
      final raw = prefs.getString(_prefsKey(plan.id, selectedDay.dayKey, date));
      if (raw != null) {
        checks = (jsonDecode(raw) as List<dynamic>).cast<bool>();
      } else {
        checks = List.filled(selectedDay.exercises.length, false);
      }
    }

    if (!mounted) return;
    setState(() {
      _completedDayKeysThisWeek = completed;
      _checks = checks;
      _loading = false;
    });
  }

  WorkoutDay? _dayForKey(WorkoutPlan plan, String key) {
    try {
      return plan.days.firstWhere((d) => d.dayKey == key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _selectDay(String dayKey) async {
    setState(() => _selectedDayKey = dayKey);
    await _loadState();
  }

  Future<void> _saveChecks(WorkoutPlan plan, WorkoutDay day, List<bool> checks) async {
    final prefs = await SharedPreferences.getInstance();
    final date = _dateForDayKey(day.dayKey);
    await prefs.setString(_prefsKey(plan.id, day.dayKey, date), jsonEncode(checks));
  }

  Future<void> _toggleExercise(int index, bool value) async {
    final plan = _activePlan;
    final day = plan == null ? null : _dayForKey(plan, _selectedDayKey);
    if (plan == null || day == null) return;

    final updated = [..._checks];
    updated[index] = value;

    setState(() => _checks = updated);
    await _saveChecks(plan, day, updated);

    final allDone = updated.isNotEmpty && updated.every((c) => c);
    if (allDone) {
      await _logSessionIfNeeded(plan, day);
      setState(() {
        _completedDayKeysThisWeek = {..._completedDayKeysThisWeek, day.dayKey};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Workout complete! Great job.')),
        );
      }
    } else {
      setState(() {
        _completedDayKeysThisWeek = {..._completedDayKeysThisWeek}..remove(day.dayKey);
      });
    }
  }

  Future<void> _logSessionIfNeeded(WorkoutPlan plan, WorkoutDay day) async {
    final date = _dateForDayKey(day.dayKey);
    final alreadyLogged = HiveService.sessionsBox.values.any((s) =>
        s.planId == plan.id &&
        s.dayKey == day.dayKey &&
        _formatDate(s.date) == _formatDate(date));
    if (alreadyLogged) return;

    final session = CompletedSession(
      id: _uuid.v4(),
      date: date,
      dayKey: day.dayKey,
      planId: plan.id,
    );
    await HiveService.sessionsBox.add(session);
  }

  Future<void> _resetDay() async {
    final plan = _activePlan;
    final day = plan == null ? null : _dayForKey(plan, _selectedDayKey);
    if (plan == null || day == null) return;

    final cleared = List.filled(day.exercises.length, false);
    setState(() {
      _checks = cleared;
      _completedDayKeysThisWeek = {..._completedDayKeysThisWeek}..remove(day.dayKey);
    });
    await _saveChecks(plan, day, cleared);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final plan = _activePlan;
    if (plan == null) {
      return _EmptyPlanState(onGoToSettings: widget.onGoToSettings);
    }

    final day = _dayForKey(plan, _selectedDayKey);
    final total = day?.exercises.length ?? 0;
    final done = _checks.where((c) => c).length;
    final progress = total == 0 ? 0.0 : done / total;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.planName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          if (plan.weekNote != null && plan.weekNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              plan.weekNote!,
              style: const TextStyle(fontSize: 13, color: textSecondary),
            ),
          ],
          const SizedBox(height: 16),
          DaySelector(
            days: plan.days,
            selectedKey: _selectedDayKey,
            completedDayKeys: _completedDayKeysThisWeek,
            onSelect: _selectDay,
          ),
          const SizedBox(height: 16),
          if (day == null)
            const Expanded(
              child: Center(
                child: Text('Day not found in plan.', style: TextStyle(color: textMuted)),
              ),
            )
          else if (day.isRestDay)
            Expanded(child: _RestDayState(day: day))
          else ...[
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$done / $total',
                  style: const TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: day.exercises.length,
                itemBuilder: (context, index) {
                  return ExerciseCard(
                    exercise: day.exercises[index],
                    completed: index < _checks.length ? _checks[index] : false,
                    onToggle: (value) => _toggleExercise(index, value),
                  );
                },
              ),
            ),
            if (day.tip != null && day.tip!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface2Color,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: accentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        day.tip!,
                        style: const TextStyle(fontSize: 12.5, color: textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetDay,
                child: const Text('Reset day'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPlanState extends StatelessWidget {
  final VoidCallback onGoToSettings;

  const _EmptyPlanState({required this.onGoToSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 56, color: textMuted),
            const SizedBox(height: 16),
            const Text(
              'No workout plan yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import a plan JSON file from Settings to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onGoToSettings,
              child: const Text('Go to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestDayState extends StatelessWidget {
  final WorkoutDay day;

  const _RestDayState({required this.day});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.self_improvement, size: 56, color: textMuted),
          const SizedBox(height: 16),
          Text(
            day.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          if (day.focus.trim().isNotEmpty)
            Text(
              day.focus,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
        ],
      ),
    );
  }
}
