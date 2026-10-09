import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/completed_session.dart';
import '../models/weight_entry.dart';
import '../services/hive_service.dart';
import '../theme/app_theme.dart';
import '../widgets/weight_chart.dart';
import '../widgets/workout_chart.dart';

const List<String> kDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// History screen with two tabs: Workouts and Weight.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'History',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: accentBlue,
          unselectedLabelColor: textMuted,
          indicatorColor: accentBlue,
          tabs: const [
            Tab(text: 'Workouts'),
            Tab(text: 'Weight'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _WorkoutsTab(),
              _WeightTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkoutsTab extends StatelessWidget {
  const _WorkoutsTab();

  List<WeeklySessionData> _buildWeeklyData(List<CompletedSession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));

    final weeks = <WeeklySessionData>[];
    for (var i = 11; i >= 0; i--) {
      final weekStart = currentWeekStart.subtract(Duration(days: 7 * i));
      final weekEnd = weekStart.add(const Duration(days: 7));
      final count = sessions
          .where((s) =>
              !s.date.isBefore(weekStart) && s.date.isBefore(weekEnd))
          .length;
      weeks.add(WeeklySessionData(
        weekLabel: DateFormat('MMM d').format(weekStart),
        sessionCount: count,
      ));
    }
    return weeks;
  }

  int _computeStreak(List<CompletedSession> sessions) {
    if (sessions.isEmpty) return 0;
    final dates = sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();

    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    if (!dates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!dates.contains(cursor)) return 0;
    }

    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Map<String, List<CompletedSession>> _groupByWeek(List<CompletedSession> sessions) {
    final sorted = [...sessions]..sort((a, b) => b.date.compareTo(a.date));
    final grouped = <String, List<CompletedSession>>{};
    for (final session in sorted) {
      final weekStart = session.date.subtract(Duration(days: session.date.weekday - 1));
      final label = 'Week of ${DateFormat('MMM d').format(weekStart)}';
      grouped.putIfAbsent(label, () => []).add(session);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.sessionsBox.listenable(),
      builder: (context, Box<CompletedSession> box, _) {
        final sessions = box.values.toList();

        if (sessions.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_busy,
            title: 'No sessions logged yet',
            message: 'Complete a workout to see your history here.',
          );
        }

        final weeklyData = _buildWeeklyData(sessions);
        final streak = _computeStreak(sessions);
        final grouped = _groupByWeek(sessions);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                '🔥 $streak day streak',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: accentAmber,
                ),
              ),
            ),
            const SizedBox(height: 16),
            WorkoutChart(weeks: weeklyData),
            const SizedBox(height: 20),
            for (final entry in grouped.entries) ...[
              Text(
                entry.key,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              for (final session in entry.value)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: accentGreen),
                      const SizedBox(width: 10),
                      Text(
                        kDayLabels[session.date.weekday - 1],
                        style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, yyyy').format(session.date),
                        style: const TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _WeightTab extends StatefulWidget {
  const _WeightTab();

  @override
  State<_WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends State<_WeightTab> {
  static const _uuid = Uuid();
  final _weightController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _logWeight() async {
    final text = _weightController.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight value.')),
      );
      return;
    }

    final entry = WeightEntry(
      id: _uuid.v4(),
      date: _selectedDate,
      value: value,
    );
    await HiveService.weightsBox.add(entry);
    _weightController.clear();
    setState(() => _selectedDate = DateTime.now());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight logged.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = HiveService.weightUnit;

    return ValueListenableBuilder(
      valueListenable: HiveService.weightsBox.listenable(),
      builder: (context, Box<WeightEntry> box, _) {
        final entries = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Weight ($unit)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(DateFormat('MMM d').format(_selectedDate)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logWeight,
                      child: const Text('Log weight'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (entries.isEmpty)
              const _EmptyState(
                icon: Icons.monitor_weight_outlined,
                title: 'No weight entries yet',
                message: 'Log your weight above to start tracking progress.',
              )
            else ...[
              WeightChart(entries: entries, unit: unit),
              const SizedBox(height: 20),
              for (final entry in entries)
                Dismissible(
                  key: ValueKey(entry.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: accentCoral,
                      borderRadius: BorderRadius.circular(cardRadius),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => entry.delete(),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${entry.value.toStringAsFixed(1)} $unit',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d, yyyy').format(entry.date),
                          style: const TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
