import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/workout_plan.dart';
import '../services/hive_service.dart';
import '../services/json_import_service.dart';
import '../theme/app_theme.dart';

/// Settings screen: plan management, weight unit, data reset/export.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _importing = false;

  Future<void> _importPlan() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _importing = false);
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        throw PlanValidationException('Could not read the selected file.');
      }

      final content = await File(path).readAsString();
      final plan = JsonImportService.parsePlan(content);
      await HiveService.plansBox.add(plan);

      if (HiveService.activePlanId == null) {
        await HiveService.setActivePlanId(plan.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${plan.planName}".')),
        );
      }
    } on PlanValidationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    if (plan.id == HiveService.activePlanId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the active plan.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete plan?'),
        content: Text('This will permanently delete "${plan.planName}".'),
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

    if (confirmed == true) {
      await plan.delete();
    }
  }

  Future<void> _setActivePlan(String id) async {
    await HiveService.setActivePlanId(id);
    setState(() {});
  }

  Future<void> _setWeightUnit(String unit) async {
    await HiveService.setWeightUnit(unit);
    setState(() {});
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
            'This will permanently delete all plans, sessions, and weight entries. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HiveService.resetAllData();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset.')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final sessions = HiveService.sessionsBox.values
          .map((s) => {
                'date': s.date.toIso8601String(),
                'dayKey': s.dayKey,
                'planId': s.planId,
              })
          .toList();
      final weights = HiveService.weightsBox.values
          .map((w) => {
                'date': w.date.toIso8601String(),
                'value': w.value,
              })
          .toList();

      final export = {
        'sessions': sessions,
        'weights': weights,
        'exportedAt': DateTime.now().toIso8601String(),
      };

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fittrack_export.json');
      await file.writeAsString(jsonEncode(export));

      await Share.shareXFiles([XFile(file.path)], text: 'FitTrack data export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.plansBox.listenable(),
      builder: (context, Box<WorkoutPlan> plansBox, _) {
        final plans = plansBox.values.toList();
        final activeId = HiveService.activePlanId;
        final weightUnit = HiveService.weightUnit;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 20),
            _SectionHeader('Workout Plans'),
            const SizedBox(height: 8),
            if (plans.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(cardRadius),
                  border: Border.all(color: borderColor),
                ),
                child: const Text(
                  'No plans imported yet.',
                  style: TextStyle(color: textSecondary),
                ),
              )
            else
              RadioGroup<String>(
                groupValue: activeId,
                onChanged: (id) => id == null ? null : _setActivePlan(id),
                child: Column(
                  children: [
                    for (final plan in plans)
                      Dismissible(
                        key: ValueKey(plan.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _deletePlan(plan);
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: accentCoral,
                            borderRadius: BorderRadius.circular(cardRadius),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(cardRadius),
                            border: Border.all(
                              color: plan.id == activeId ? accentBlue : borderColor,
                            ),
                          ),
                          child: RadioListTile<String>(
                            value: plan.id,
                            title: Text(plan.planName, style: const TextStyle(color: textPrimary)),
                            subtitle: Text(
                              '${plan.days.length} days',
                              style: const TextStyle(color: textSecondary),
                            ),
                            activeColor: accentBlue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importing ? null : _importPlan,
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(_importing ? 'Importing...' : 'Import new plan'),
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeader('Weight Unit'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(color: borderColor),
              ),
              child: RadioGroup<String>(
                groupValue: weightUnit,
                onChanged: (v) => v == null ? null : _setWeightUnit(v),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'lbs',
                        title: const Text('lbs', style: TextStyle(color: textPrimary)),
                        activeColor: accentBlue,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'kg',
                        title: const Text('kg', style: TextStyle(color: textPrimary)),
                        activeColor: accentBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeader('Data'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exportData,
                icon: const Icon(Icons.ios_share),
                label: const Text('Export data'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _resetAllData,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentCoral,
                  side: const BorderSide(color: accentCoral),
                ),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Reset all data'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
