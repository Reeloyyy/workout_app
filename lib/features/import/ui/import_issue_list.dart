import 'package:flutter/material.dart';

import '../../../core/widgets/code_text.dart';
import '../domain/import_error.dart';

/// Errors first, then warnings, each with an icon screen readers announce.
class ImportIssueList extends StatelessWidget {
  const ImportIssueList({super.key, required this.issues});

  final List<ImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sorted = [
      ...issues.where((i) => !i.isWarning),
      ...issues.where((i) => i.isWarning),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in sorted)
          // One screen-reader item per issue: "Error, <message>".
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    issue.isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline,
                    color: issue.isWarning ? colors.tertiary : colors.error,
                    semanticLabel: issue.isWarning ? 'Warning' : 'Error',
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: CodeText(issue.message)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
