import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';
import '../theme/app_theme.dart';

/// Line chart showing body weight over time, with a dashed starting-weight line.
class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final String unit;

  const WeightChart({super.key, required this.entries, required this.unit});

  @override
  Widget build(BuildContext context) {
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));

    final values = sorted.map((e) => e.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = ((maxValue - minValue) * 0.15).clamp(1.0, double.infinity);
    final minY = minValue - padding;
    final maxY = maxValue + padding;
    final startingWeight = sorted.first.value;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: borderColor,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(color: textMuted, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: (sorted.length / 5).clamp(1, sorted.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sorted.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('MMM d').format(sorted[index].date),
                      style: const TextStyle(color: textMuted, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: startingWeight,
                color: textMuted,
                strokeWidth: 1,
                dashArray: [6, 4],
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < sorted.length; i++)
                  FlSpot(i.toDouble(), sorted[i].value),
              ],
              isCurved: true,
              color: accentBlue,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: accentBlue.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
