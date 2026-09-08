import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final testFiles =
      Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => path.endsWith('_test.dart'))
          .toList()
        ..sort();
  if (testFiles.isEmpty) {
    stderr.writeln('No test files found.');
    exitCode = 1;
    return;
  }

  final rawCoverage = Directory('coverage/raw');
  if (rawCoverage.existsSync()) {
    rawCoverage.deleteSync(recursive: true);
  }
  rawCoverage.createSync(recursive: true);

  // Dart's Linux VM can crash in SourceReport when branch coverage is
  // collected across many test-suite isolates. A fresh VM per test file keeps
  // the tests and branch gate intact while isolating that upstream failure.
  for (var index = 0; index < testFiles.length; index++) {
    final testFile = testFiles[index];
    final suiteCoverage = '${rawCoverage.path}/suite_$index';
    stdout.writeln('Collecting coverage: $testFile');
    final result = await Process.start(Platform.resolvedExecutable, [
      '--branch-coverage',
      'run',
      'test',
      testFile,
      '--concurrency=1',
      '--reporter=expanded',
      '--coverage=$suiteCoverage',
      '--branch-coverage',
    ], mode: ProcessStartMode.inheritStdio).then((process) => process.exitCode);
    if (result != 0) {
      exitCode = result;
      return;
    }
  }

  final mergedCoverage = File('coverage/merged.vm.json');
  _mergeCoverage(rawCoverage, mergedCoverage);

  final formatResult = await Process.start(Platform.resolvedExecutable, [
    'run',
    'coverage:format_coverage',
    '--lcov',
    '--in=${mergedCoverage.path}',
    '--out=coverage/lcov.info',
    '--packages=.dart_tool/package_config.json',
    '--report-on=lib',
  ], mode: ProcessStartMode.inheritStdio).then((process) => process.exitCode);
  if (formatResult != 0) {
    exitCode = formatResult;
  }
}

void _mergeCoverage(Directory input, File output) {
  final scripts = <String, Map<String, dynamic>>{};
  final files = input
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.vm.json'));
  for (final file in files) {
    final document =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final coverage = document['coverage']! as List<dynamic>;
    for (final value in coverage) {
      final incoming = value as Map<String, dynamic>;
      final source = incoming['source']! as String;
      final key = _coverageKey(source);
      final existing = scripts[key];
      if (existing == null) {
        scripts[key] = Map<String, dynamic>.from(incoming)..['source'] = key;
        continue;
      }
      existing['hits'] = _mergeHitPairs(existing['hits'], incoming['hits']);
      existing['branchHits'] = _mergeHitPairs(
        existing['branchHits'],
        incoming['branchHits'],
      );
    }
  }
  output.writeAsStringSync(
    jsonEncode({'type': 'CodeCoverage', 'coverage': scripts.values.toList()}),
  );
}

String _coverageKey(String source) {
  final libraryRoot = '${Directory.current.absolute.path}/lib/';
  final uri = Uri.tryParse(source);
  if (uri?.scheme == 'file' && uri!.toFilePath().startsWith(libraryRoot)) {
    return 'package:rosm_passport_server/${uri.toFilePath().substring(libraryRoot.length)}';
  }
  return source;
}

List<int> _mergeHitPairs(Object? first, Object? second) {
  final totals = <int, int>{};
  for (final pairs in [first, second]) {
    if (pairs is! List<dynamic>) continue;
    for (var index = 0; index < pairs.length; index += 2) {
      final position = pairs[index] as int;
      final count = pairs[index + 1] as int;
      totals.update(position, (value) => value + count, ifAbsent: () => count);
    }
  }
  final positions = totals.keys.toList()..sort();
  return [
    for (final position in positions) ...[position, totals[position]!],
  ];
}
