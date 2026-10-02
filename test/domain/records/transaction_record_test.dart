import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransactionRecord の読み込み（D-168）', () {
    test('古い形式（カードの項目が無い）でも基準カードで読める', () {
      final record = TransactionRecord.fromJson(<String, Object?>{
        'id': '1700000000000000',
        'on': '2026-09-30',
        'merchantId': 'seven_eleven',
        'merchantName': 'セブン-イレブン',
        'amountYen': 1200,
      });

      expect(record, isNotNull);
      expect(record!.instrumentId, TransactionRecord.fallbackInstrumentId);
      expect(record.amountYen, 1200);
      expect(record.merchantName, 'セブン-イレブン');
    });

    test('カードの項目が空文字でも基準カードで読める', () {
      final record = TransactionRecord.fromJson(<String, Object?>{
        'id': '1700000000000001',
        'on': '2026-09-30',
        'merchantId': '',
        'merchantName': '',
        'instrumentId': '',
        'amountYen': 500,
      });

      expect(record, isNotNull);
      expect(record!.instrumentId, TransactionRecord.fallbackInstrumentId);
      expect(record.merchantName, 'その他');
    });

    test('金額が文字列でも数値として読める', () {
      final record = TransactionRecord.fromJson(<String, Object?>{
        'id': '1700000000000002',
        'on': '2026-09-30',
        'merchantId': 'seven_eleven',
        'merchantName': 'セブン-イレブン',
        'instrumentId': 'mizuho_rakuten_card',
        'amountYen': '980',
      });

      expect(record, isNotNull);
      expect(record!.amountYen, 980);
    });

    test('最低限の項目（id・日付・金額）だけでも読める', () {
      final record = TransactionRecord.fromJson(<String, Object?>{
        'id': '1700000000000003',
        'on': '2026-01-01',
        'amountYen': 100,
      });

      expect(record, isNotNull);
      expect(record!.merchantId, '');
      expect(record.instrumentId, TransactionRecord.fallbackInstrumentId);
    });

    test('id か日付が欠けた行は捨てる', () {
      expect(
        TransactionRecord.fromJson(<String, Object?>{
          'on': '2026-09-30',
          'amountYen': 100,
        }),
        isNull,
      );
      expect(
        TransactionRecord.fromJson(<String, Object?>{
          'id': 'x',
          'on': '2026-9-3',
          'amountYen': 100,
        }),
        isNull,
      );
    });

    test('書いて読み直すと同じ内容になる', () {
      const original = TransactionRecord(
        id: '1700000000000004',
        occurredOn: '2026-10-02',
        merchantId: 'seijo_ishii',
        merchantName: '成城石井',
        instrumentId: 'olive_flexible_pay_gold',
        amountYen: 3450,
      );

      final restored = TransactionRecord.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.occurredOn, original.occurredOn);
      expect(restored.merchantId, original.merchantId);
      expect(restored.merchantName, original.merchantName);
      expect(restored.instrumentId, original.instrumentId);
      expect(restored.amountYen, original.amountYen);
    });
  });
}
