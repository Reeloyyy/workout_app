import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/code_text.dart';
import '../domain/import_error.dart';
import '../domain/workout_parser.dart';
import '../import_providers.dart';
import 'import_issue_list.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _json = TextEditingController();

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      _showMessage('The clipboard has no text.');
      return;
    }
    _json.text = text;
  }

  Future<void> _chooseFile() async {
    final String text;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      text = utf8.decode(await file.readAsBytes());
    } on FormatException {
      if (mounted) _showMessage('This file is not UTF-8 text.');
      return;
    } on Exception {
      if (mounted) _showMessage('The file could not be opened.');
      return;
    }
    if (!mounted) return;
    _json.text = text;
  }

  void _validate() {
    FocusScope.of(context).unfocus();
    final result = ref.read(importResultProvider.notifier).validate(_json.text);
    if (result is ImportSuccess) context.push('/import/preview');
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(importResultProvider);
    final List<ImportIssue> issues = switch (result) {
      ImportFailure(:final errors, :final warnings) => [...errors, ...warnings],
      ImportSuccess(:final warnings) => warnings,
      null => const [],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _json,
            minLines: 8,
            maxLines: 16,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            enableSuggestions: false,
            style: monospace,
            decoration: const InputDecoration(
              labelText: 'Workout JSON',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('Paste'),
              ),
              OutlinedButton.icon(
                onPressed: _chooseFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Choose file'),
              ),
              FilledButton.icon(
                onPressed: _validate,
                icon: const Icon(Icons.check),
                label: const Text('Validate'),
              ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            ImportIssueList(issues: issues),
          ],
        ],
      ),
    );
  }
}
