import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_architecture.dart';

void main() {
  late Directory temporaryRoot;

  setUp(() {
    temporaryRoot = Directory.systemTemp.createTempSync(
      'bestpay_architecture_test_',
    );
  });

  tearDown(() {
    if (temporaryRoot.existsSync()) {
      temporaryRoot.deleteSync(recursive: true);
    }
  });

  test('allows Dart SDK imports in core', () async {
    await _writeSource(
      temporaryRoot,
      'lib/core/example.dart',
      "import 'dart:async';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, isEmpty);
  });

  test('detects a Flutter import in core', () async {
    await _writeSource(
      temporaryRoot,
      'lib/core/example.dart',
      "import 'package:flutter/material.dart';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, hasLength(1));
    expect(violations.single.ruleId, 'ARCH-CORE-001');
    expect(violations.single.path, 'lib/core/example.dart');
    expect(violations.single.lineNumber, 1);
  });

  test('detects an infrastructure import in domain', () async {
    await _writeSource(
      temporaryRoot,
      'lib/domain/example.dart',
      "import 'package:bestpay/infrastructure/database.dart';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, hasLength(1));
    expect(violations.single.ruleId, 'ARCH-DOMAIN-004');
  });

  test('detects a presentation import in application', () async {
    await _writeSource(
      temporaryRoot,
      'lib/application/example.dart',
      "import 'package:bestpay/presentation/screen.dart';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, hasLength(1));
    expect(violations.single.ruleId, 'ARCH-APP-004');
  });

  test('detects a sqflite import in presentation', () async {
    await _writeSource(
      temporaryRoot,
      'lib/presentation/example.dart',
      "import 'package:sqflite/sqflite.dart';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, hasLength(1));
    expect(violations.single.ruleId, 'ARCH-PRES-001');
  });

  test('allows composition to import every application layer', () async {
    await _writeSource(
      temporaryRoot,
      'lib/composition/example.dart',
      '''
import 'package:bestpay/core/result/app_result.dart';
import 'package:bestpay/domain/model.dart';
import 'package:bestpay/application/service.dart';
import 'package:bestpay/infrastructure/repository.dart';
import 'package:bestpay/presentation/screen.dart';
import 'package:bestpay/legacy/adapter.dart';
''',
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, isEmpty);
  });

  test('excludes existing v1 legacy directories from the check', () async {
    await _writeSource(
      temporaryRoot,
      'lib/db/database_helper.dart',
      "import 'package:sqflite/sqflite.dart';\n",
    );
    await _writeSource(
      temporaryRoot,
      'lib/screens/example_screen.dart',
      "import 'package:bestpay/db/database_helper.dart';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, isEmpty);
  });

  test('maps architecture violations to a non-zero exit code', () async {
    await _writeSource(
      temporaryRoot,
      'lib/core/example.dart',
      "import 'package:flutter/widgets.dart';\n",
    );

    final violations = await ArchitectureChecker(
      rootDirectory: temporaryRoot,
    ).check();

    expect(violations, hasLength(1));
    expect(violations.single.ruleId, 'ARCH-CORE-001');
    expect(architectureExitCode(violations), 1);
  });
}

Future<void> _writeSource(
  Directory root,
  String relativePath,
  String contents,
) async {
  final path = relativePath.replaceAll('/', Platform.pathSeparator);
  final file = File(
    '${root.path}${Platform.pathSeparator}$path',
  );

  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}
