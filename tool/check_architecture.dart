import 'dart:io';

/// A single prohibited import detected by [ArchitectureChecker].
final class ArchitectureViolation {
  const ArchitectureViolation({
    required this.path,
    required this.lineNumber,
    required this.importLine,
    required this.ruleId,
    required this.message,
    required this.suggestion,
  });

  final String path;
  final int lineNumber;
  final String importLine;
  final String ruleId;
  final String message;
  final String suggestion;

  @override
  String toString() {
    return '$path:$lineNumber: $ruleId: $message\n'
        '  $importLine\n'
        '  Fix: $suggestion';
  }
}

/// Checks imports in the v2 layer directories.
///
/// Existing v1 directories such as lib/db and lib/screens are intentionally
/// outside the initial PR-02 check target.
final class ArchitectureChecker {
  ArchitectureChecker({required this.rootDirectory});

  final Directory rootDirectory;

  static const List<String> _targetLayers = <String>[
    'core',
    'domain',
    'application',
    'infrastructure',
    'presentation',
    'composition',
    'legacy',
  ];

  Future<List<ArchitectureViolation>> check() async {
    final violations = <ArchitectureViolation>[];

    for (final layer in _targetLayers) {
      final directory = Directory(
        '${rootDirectory.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}$layer',
      );

      if (!directory.existsSync()) {
        continue;
      }

      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        violations.addAll(await _checkFile(entity, layer));
      }
    }

    violations.sort((left, right) {
      final pathComparison = left.path.compareTo(right.path);
      if (pathComparison != 0) {
        return pathComparison;
      }
      return left.lineNumber.compareTo(right.lineNumber);
    });

    return violations;
  }

  Future<List<ArchitectureViolation>> _checkFile(
    File file,
    String layer,
  ) async {
    final violations = <ArchitectureViolation>[];
    final lines = await file.readAsLines();
    final importPattern = RegExp(
      r'''^\s*import\s+['"]([^'"]+)['"]''',
    );

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final match = importPattern.firstMatch(line);
      if (match == null) {
        continue;
      }

      final importUri = match.group(1)!;
      final normalizedUri = _normalizeImportUri(file, importUri);
      final rule = _findRule(layer, normalizedUri);
      if (rule == null) {
        continue;
      }

      violations.add(
        ArchitectureViolation(
          path: _relativePath(file),
          lineNumber: index + 1,
          importLine: line.trim(),
          ruleId: rule.id,
          message: rule.message,
          suggestion: rule.suggestion,
        ),
      );
    }

    return violations;
  }

  _ImportRule? _findRule(String layer, String uri) {
    switch (layer) {
      case 'core':
        if (_isPackage(uri, 'package:flutter')) {
          return const _ImportRule(
            'ARCH-CORE-001',
            'core must not import Flutter',
            'Move Flutter-dependent code to presentation or infrastructure.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/domain')) {
          return const _ImportRule(
            'ARCH-CORE-002',
            'core must not import domain',
            'Reverse the dependency so domain depends on core.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/application')) {
          return const _ImportRule(
            'ARCH-CORE-003',
            'core must not import application',
            'Move the shared contract into core or remove the dependency.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/infrastructure')) {
          return const _ImportRule(
            'ARCH-CORE-004',
            'core must not import infrastructure',
            'Pass infrastructure behavior through an outer-layer adapter.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/presentation')) {
          return const _ImportRule(
            'ARCH-CORE-005',
            'core must not import presentation',
            'Move UI behavior to presentation.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/legacy')) {
          return const _ImportRule(
            'ARCH-CORE-006',
            'core must not import legacy',
            'Use a legacy adapter outside core.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/composition')) {
          return const _ImportRule(
            'ARCH-CORE-007',
            'core must not import composition',
            'Create and connect concrete dependencies in composition.',
          );
        }
        if (uri.startsWith('package:') &&
            !_isPackage(uri, 'package:bestpay/core')) {
          return const _ImportRule(
            'ARCH-CORE-008',
            'core must depend only on the Dart SDK or other core code',
            'Move package-dependent behavior to an outer layer.',
          );
        }

      case 'domain':
        if (_isPackage(uri, 'package:flutter')) {
          return const _ImportRule(
            'ARCH-DOMAIN-001',
            'domain must not import Flutter',
            'Keep domain code as pure Dart.',
          );
        }
        if (_isPackage(uri, 'package:sqflite') ||
            _isPackage(uri, 'package:shared_preferences') ||
            _isPackage(uri, 'package:file_picker')) {
          return const _ImportRule(
            'ARCH-DOMAIN-002',
            'domain must not import storage or platform plugins',
            'Define a repository contract and implement it in infrastructure.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/application')) {
          return const _ImportRule(
            'ARCH-DOMAIN-003',
            'domain must not import application',
            'Application may depend on domain, not the reverse.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/infrastructure')) {
          return const _ImportRule(
            'ARCH-DOMAIN-004',
            'domain must not import infrastructure',
            'Depend on a domain repository contract instead.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/presentation')) {
          return const _ImportRule(
            'ARCH-DOMAIN-005',
            'domain must not import presentation',
            'Move display behavior to presentation.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/legacy')) {
          return const _ImportRule(
            'ARCH-DOMAIN-006',
            'domain must not import legacy',
            'Convert legacy models through an adapter.',
          );
        }

      case 'application':
        if (_isPackage(uri, 'package:flutter')) {
          return const _ImportRule(
            'ARCH-APP-001',
            'application must not import Flutter',
            'Move Widget and BuildContext behavior to presentation.',
          );
        }
        if (_isPackage(uri, 'package:sqflite') ||
            _isPackage(uri, 'package:shared_preferences') ||
            _isPackage(uri, 'package:file_picker')) {
          return const _ImportRule(
            'ARCH-APP-002',
            'application must not import concrete platform plugins',
            'Depend on a port implemented by infrastructure.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/infrastructure')) {
          return const _ImportRule(
            'ARCH-APP-003',
            'application must not import infrastructure',
            'Create concrete dependencies in composition.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/presentation')) {
          return const _ImportRule(
            'ARCH-APP-004',
            'application must not import presentation',
            'Presentation may call application, not the reverse.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/legacy')) {
          return const _ImportRule(
            'ARCH-APP-005',
            'application must not import legacy',
            'Use an application port and a legacy adapter.',
          );
        }

      case 'infrastructure':
        if (_isPackage(uri, 'package:bestpay/presentation')) {
          return const _ImportRule(
            'ARCH-INFRA-001',
            'infrastructure must not import presentation',
            'Return data through a repository contract instead.',
          );
        }

      case 'presentation':
        if (_isPackage(uri, 'package:sqflite') ||
            _isPackage(uri, 'package:shared_preferences') ||
            _isPackage(uri, 'package:file_picker')) {
          return const _ImportRule(
            'ARCH-PRES-001',
            'presentation must not import storage or platform plugins directly',
            'Call an application service instead.',
          );
        }
        if (_isPackage(uri, 'package:bestpay/infrastructure')) {
          return const _ImportRule(
            'ARCH-PRES-002',
            'presentation must not import infrastructure',
            'Receive application dependencies from composition.',
          );
        }
        if (_isLegacyDatabaseHelper(uri)) {
          return const _ImportRule(
            'ARCH-PRES-003',
            'presentation must not import legacy DatabaseHelper directly',
            'Use an application service and repository abstraction.',
          );
        }
        if (_isLegacyCalculator(uri)) {
          return const _ImportRule(
            'ARCH-PRES-004',
            'presentation must not import legacy Calculator directly',
            'Use the v2 calculation application service.',
          );
        }

      case 'legacy':
        if (_isPackage(uri, 'package:bestpay/infrastructure') ||
            _isPackage(uri, 'package:bestpay/presentation')) {
          return const _ImportRule(
            'ARCH-LEGACY-001',
            'legacy adapters must not depend on outer v2 layers',
            'Depend on core, domain, or an application port.',
          );
        }

      case 'composition':
        return null;
    }

    return null;
  }

  String _normalizeImportUri(File sourceFile, String uri) {
    final parsedUri = Uri.parse(uri);
    if (parsedUri.hasScheme) {
      return uri;
    }

    final resolvedPath = File.fromUri(
      sourceFile.parent.uri.resolve(uri),
    ).absolute.path;
    final libPath = Directory(
      '${rootDirectory.path}${Platform.pathSeparator}lib',
    ).absolute.path;

    final comparableResolvedPath =
        Platform.isWindows ? resolvedPath.toLowerCase() : resolvedPath;
    final comparableLibPath =
        Platform.isWindows ? libPath.toLowerCase() : libPath;

    final isInsideLib = comparableResolvedPath == comparableLibPath ||
        comparableResolvedPath.startsWith(
          '$comparableLibPath${Platform.pathSeparator}',
        );
    if (!isInsideLib) {
      return uri;
    }

    final relativePath = resolvedPath
        .substring(libPath.length)
        .replaceFirst(RegExp(r'^[\\/]'), '')
        .replaceAll(r'\', '/');

    return 'package:bestpay/$relativePath';
  }

  bool _isPackage(String uri, String packagePrefix) {
    return uri == packagePrefix || uri.startsWith('$packagePrefix/');
  }

  bool _isLegacyDatabaseHelper(String uri) {
    return uri == 'package:bestpay/db/database_helper.dart' ||
        uri.endsWith('/db/database_helper.dart');
  }

  bool _isLegacyCalculator(String uri) {
    return uri == 'package:bestpay/utils/calculator.dart' ||
        uri.endsWith('/utils/calculator.dart');
  }

  String _relativePath(File file) {
    final rootPath = rootDirectory.absolute.path;
    final filePath = file.absolute.path;

    if (!filePath.startsWith(rootPath)) {
      return filePath.replaceAll(r'\', '/');
    }

    return filePath
        .substring(rootPath.length)
        .replaceFirst(RegExp(r'^[\\/]'), '')
        .replaceAll(r'\', '/');
  }
}

final class _ImportRule {
  const _ImportRule(
    this.id,
    this.message,
    this.suggestion,
  );

  final String id;
  final String message;
  final String suggestion;
}

/// Returns the process exit code for an architecture-check result.
int architectureExitCode(
  Iterable<ArchitectureViolation> violations,
) {
  return violations.isEmpty ? 0 : 1;
}

Future<void> main(List<String> arguments) async {
  final root = Directory(
    arguments.isEmpty ? Directory.current.path : arguments.first,
  );
  final violations = await ArchitectureChecker(
    rootDirectory: root,
  ).check();

  exitCode = architectureExitCode(violations);

  if (violations.isEmpty) {
    stdout.writeln('Architecture check passed.');
    return;
  }

  stderr.writeln(
    'Architecture check failed with ${violations.length} violation(s).',
  );
  for (final violation in violations) {
    stderr.writeln();
    stderr.writeln(violation);
  }
}
