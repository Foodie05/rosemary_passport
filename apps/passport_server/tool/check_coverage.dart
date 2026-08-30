import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/check_coverage.dart coverage/lcov.info',
    );
    exitCode = 64;
    return;
  }
  final file = File(arguments.single);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file is missing: ${file.path}');
    exitCode = 1;
    return;
  }

  final records = <String, _Coverage>{};
  String? source;
  var current = _Coverage();
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      source = line.substring(3);
      current = _Coverage();
    } else if (line.startsWith('LF:')) {
      current.linesFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      current.linesHit = int.parse(line.substring(3));
    } else if (line.startsWith('BRF:')) {
      if (!current.hasBranchRecords) {
        current.branchesFound = int.parse(line.substring(4));
      }
    } else if (line.startsWith('BRH:')) {
      if (!current.hasBranchRecords) {
        current.branchesHit = int.parse(line.substring(4));
      }
    } else if (line.startsWith('BRDA:')) {
      // Dart's LCOV formatter emits individual branch records without the
      // optional BRF/BRH summary lines used by some native toolchains.
      if (!current.hasBranchRecords) {
        current.branchesFound = 0;
        current.branchesHit = 0;
        current.hasBranchRecords = true;
      }
      current.branchesFound++;
      final taken = line.split(',').last;
      final count = int.tryParse(taken);
      if (count != null && count > 0) {
        current.branchesHit++;
      }
    } else if (line == 'end_of_record' && source != null) {
      records[source] = current;
      source = null;
    }
  }

  final overall = records.values.fold<_Coverage>(
    _Coverage(),
    (total, item) => total..add(item),
  );
  final failures = <String>[];
  if (overall.linePercent < 70) {
    failures.add(
      'overall line coverage ${overall.linePercent.toStringAsFixed(2)}% < 70%',
    );
  }

  const criticalSuffixes = [
    '/lib/src/services/auth_service.dart',
    '/lib/src/security/token_service.dart',
    '/lib/src/repositories/oidc_repository.dart',
    '/lib/src/db/migration_runner.dart',
    '/lib/src/security/settings_cipher.dart',
  ];
  for (final suffix in criticalSuffixes) {
    final matches = records.entries.where(
      (entry) => entry.key.endsWith(suffix),
    );
    if (matches.isEmpty) {
      failures.add('critical file absent from coverage: $suffix');
      continue;
    }
    final coverage = matches.single.value;
    if (coverage.branchesFound == 0) {
      failures.add('critical branch data absent: $suffix');
    } else if (coverage.branchPercent < 90) {
      failures.add(
        'critical branch coverage ${coverage.branchPercent.toStringAsFixed(2)}% < 90%: $suffix',
      );
    }
  }

  stdout.writeln(
    'overall lines ${overall.linesHit}/${overall.linesFound} '
    '(${overall.linePercent.toStringAsFixed(2)}%)',
  );
  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln('COVERAGE GATE: $failure');
    }
    exitCode = 1;
  }
}

class _Coverage {
  int linesFound = 0;
  int linesHit = 0;
  int branchesFound = 0;
  int branchesHit = 0;
  bool hasBranchRecords = false;

  double get linePercent => linesFound == 0 ? 0 : linesHit * 100 / linesFound;
  double get branchPercent =>
      branchesFound == 0 ? 0 : branchesHit * 100 / branchesFound;

  void add(_Coverage other) {
    linesFound += other.linesFound;
    linesHit += other.linesHit;
    branchesFound += other.branchesFound;
    branchesHit += other.branchesHit;
  }
}
