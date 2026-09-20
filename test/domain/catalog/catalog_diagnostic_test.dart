import 'package:bestpay/domain/catalog/catalog_diagnostic.dart';
import 'package:bestpay/domain/catalog/catalog_diagnostic_code.dart';
import 'package:bestpay/domain/catalog/catalog_diagnostic_severity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogDiagnosticSeverity', () {
    test('fatal and error block publication', () {
      expect(CatalogDiagnosticSeverity.fatal.blocksPublication, isTrue);
      expect(CatalogDiagnosticSeverity.error.blocksPublication, isTrue);
    });

    test('warning and info allow publication', () {
      expect(CatalogDiagnosticSeverity.warning.blocksPublication, isFalse);
      expect(CatalogDiagnosticSeverity.info.blocksPublication, isFalse);
    });

    test('maps stable markers to severity values', () {
      expect(
        CatalogDiagnosticSeverity.fromMarker('F'),
        CatalogDiagnosticSeverity.fatal,
      );
      expect(
        CatalogDiagnosticSeverity.fromMarker('E'),
        CatalogDiagnosticSeverity.error,
      );
      expect(
        CatalogDiagnosticSeverity.fromMarker('W'),
        CatalogDiagnosticSeverity.warning,
      );
      expect(
        CatalogDiagnosticSeverity.fromMarker('I'),
        CatalogDiagnosticSeverity.info,
      );
    });
  });

  group('CatalogDiagnosticCode', () {
    test('accepts every boundary code', () {
      final expected = <String, CatalogDiagnosticSeverity>{
        'CAT-F001': CatalogDiagnosticSeverity.fatal,
        'CAT-F007': CatalogDiagnosticSeverity.fatal,
        'CAT-E001': CatalogDiagnosticSeverity.error,
        'CAT-E013': CatalogDiagnosticSeverity.error,
        'CAT-W001': CatalogDiagnosticSeverity.warning,
        'CAT-W010': CatalogDiagnosticSeverity.warning,
        'CAT-I001': CatalogDiagnosticSeverity.info,
        'CAT-I004': CatalogDiagnosticSeverity.info,
      };

      for (final entry in expected.entries) {
        final code = CatalogDiagnosticCode.parse(entry.key);

        expect(code.value, entry.key);
        expect(code.severity, entry.value);
        expect(code.toString(), entry.key);
      }
    });

    test('rejects values outside reserved ranges', () {
      const invalidCodes = <String>[
        'CAT-F000',
        'CAT-F008',
        'CAT-E000',
        'CAT-E014',
        'CAT-W000',
        'CAT-W011',
        'CAT-I000',
        'CAT-I005',
      ];

      for (final value in invalidCodes) {
        expect(
          () => CatalogDiagnosticCode.parse(value),
          throwsFormatException,
          reason: value,
        );
        expect(CatalogDiagnosticCode.tryParse(value), isNull);
      }
    });

    test('rejects malformed and normalized-looking values', () {
      const invalidCodes = <String>[
        '',
        'cat-f001',
        'CAT-F1',
        'CAT-F0001',
        ' CAT-F001',
        'CAT-F001 ',
        'CAT-X001',
      ];

      for (final value in invalidCodes) {
        expect(
          () => CatalogDiagnosticCode.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
    });

    test('uses the stable string for equality', () {
      final first = CatalogDiagnosticCode.parse('CAT-E001');
      final second = CatalogDiagnosticCode.parse('CAT-E001');
      final different = CatalogDiagnosticCode.parse('CAT-E002');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(different));
    });
  });

  group('CatalogDiagnostic', () {
    test('derives severity and publication blocking from its code', () {
      final fatal = CatalogDiagnostic(
        code: CatalogDiagnosticCode.parse('CAT-F001'),
        message: 'Manifest is missing.',
      );
      final warning = CatalogDiagnostic(
        code: CatalogDiagnosticCode.parse('CAT-W001'),
        message: 'Source should be reviewed.',
      );

      expect(fatal.severity, CatalogDiagnosticSeverity.fatal);
      expect(fatal.blocksPublication, isTrue);
      expect(warning.severity, CatalogDiagnosticSeverity.warning);
      expect(warning.blocksPublication, isFalse);
    });

    test('defensively freezes nested diagnostic context', () {
      final sourceIds = <Object?>['source_a'];
      final sourceContext = <String, Object?>{
        'sourceIds': sourceIds,
        'metadata': <String, Object?>{'required': true},
      };

      final diagnostic = CatalogDiagnostic(
        code: CatalogDiagnosticCode.parse('CAT-E001'),
        message: 'Referenced item does not exist.',
        path: '/items/0/sourceIds/0',
        context: sourceContext,
      );

      sourceIds.add('source_b');
      sourceContext['other'] = true;

      final frozenIds = diagnostic.context['sourceIds']! as List<Object?>;
      final frozenMetadata =
          diagnostic.context['metadata']! as Map<String, Object?>;

      expect(frozenIds, <Object?>['source_a']);
      expect(diagnostic.context.containsKey('other'), isFalse);

      expect(
        () => frozenIds.add('source_c'),
        throwsUnsupportedError,
      );
      expect(
        () => frozenMetadata['required'] = false,
        throwsUnsupportedError,
      );
      expect(
        () => diagnostic.context['other'] = true,
        throwsUnsupportedError,
      );
    });

    test('rejects a blank message', () {
      expect(
        () => CatalogDiagnostic(
          code: CatalogDiagnosticCode.parse('CAT-I001'),
          message: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('formats code, path, and message without context leakage', () {
      final diagnostic = CatalogDiagnostic(
        code: CatalogDiagnosticCode.parse('CAT-E001'),
        message: 'Referenced item does not exist.',
        path: '/items/0',
        context: const <String, Object?>{
          'secret': 'must-not-appear',
        },
      );

      expect(
        diagnostic.toString(),
        'CAT-E001 at /items/0: Referenced item does not exist.',
      );
      expect(diagnostic.toString(), isNot(contains('must-not-appear')));
    });
  });
}
