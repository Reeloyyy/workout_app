import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AGENTS.md §5.2: the domain layers stay pure Dart so a future watch app
/// can reuse them, and only SystemClock reads the wall clock.
void main() {
  const pureDirs = [
    'lib/models',
    'lib/features/import/domain',
    'lib/features/player/domain',
  ];
  const pureCoreFiles = ['lib/core/clock.dart', 'lib/core/format.dart'];

  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  test('domain code imports only dart: libraries and pure files', () {
    final files = [
      for (final dir in pureDirs) ...dartFiles(dir),
      for (final path in pureCoreFiles) File(path),
    ];
    final packageImport = RegExp(
      r'''^import\s+['"]package:''',
      multiLine: true,
    );
    final offenders = [
      for (final file in files)
        if (packageImport.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('DateTime.now() is only called by SystemClock', () {
    final offenders = [
      for (final file in dartFiles('lib'))
        if (file.path.replaceAll(r'\', '/') != 'lib/core/clock.dart' &&
            file.readAsStringSync().contains('DateTime.now()'))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
