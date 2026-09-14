import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreDetailScreen legacy wiring characterization', () {
    late String source;

    setUpAll(() {
      final file = File('lib/screens/store_detail_screen.dart');

      expect(
        file.existsSync(),
        isTrue,
        reason: 'StoreDetailScreen source file must exist',
      );

      source = file.readAsStringSync();
    });

    test('contains the current two Calculator.rank call sites', () {
      final matches = RegExp(
        r'Calculator\.rank\s*\(',
      ).allMatches(source);

      expect(matches, hasLength(2));
    });

    test('does not pass customRates to either ranking calculation', () {
      final callBodies = RegExp(
        r'Calculator\.rank\s*\(([\s\S]*?)\);',
      ).allMatches(source);

      expect(callBodies, hasLength(2));

      for (final match in callBodies) {
        expect(
          match.group(1),
          isNot(contains('customRates:')),
          reason: 'Legacy StoreDetailScreen currently omits customRates. '
              'Replace this characterization when the known bug is fixed.',
        );
      }
    });

    test('does not load custom rules before calculating the ranking', () {
      expect(source, isNot(contains('getCustomRules(')));
      expect(source, isNot(contains('getCustomRateMap(')));
    });
  });
}
