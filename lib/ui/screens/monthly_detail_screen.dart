import 'package:bestpay/application/ranking/annual_reward_summary_usecase.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/charts.dart';
import '../widgets/record_editor_sheet.dart';

/// 1か月分の内訳を見る画面（D-161・D-162）。
///
/// 「カード別」と「店舗別」を切り替えられる。どちらも上に比較の棒グラフ、
/// 下に入力した順の利用明細を並べる。明細を押すと修正・削除ができる。
final class MonthlyDetailScreen extends StatefulWidget {
  const MonthlyDetailScreen({
    super.key,
    required this.year,
    required this.month,
    required this.records,
    this.onRecordsChanged,
  });

  final int year;
  final int month;

  /// 全期間の記録。この画面で年・月に絞って表示する。
  final List<TransactionRecord> records;

  /// 記録を修正・削除したときに呼ばれる。
  final ValueChanged<List<TransactionRecord>>? onRecordsChanged;

  @override
  State<MonthlyDetailScreen> createState() => _MonthlyDetailScreenState();
}

enum _DetailMode { card, store }

final class _MonthlyDetailScreenState extends State<MonthlyDetailScreen> {
  _DetailMode _mode = _DetailMode.card;
  late List<TransactionRecord> _all = widget.records;

  List<TransactionRecord> get _records {
    final list = <TransactionRecord>[
      for (final record in _all)
        if (record.year == widget.year && record.month == widget.month) record,
    ];
    // 入力した順（新しい入力が上）。
    list.sort((a, b) => b.id.compareTo(a.id));

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = _records;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.year}年${widget.month}月の内訳'),
      ),
      body: records.isEmpty
          ? const Center(child: Text('この月の記録はありません。'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                SegmentedButton<_DetailMode>(
                  segments: const <ButtonSegment<_DetailMode>>[
                    ButtonSegment<_DetailMode>(
                      value: _DetailMode.card,
                      label: Text('カード別'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment<_DetailMode>(
                      value: _DetailMode.store,
                      label: Text('店舗別'),
                      icon: Icon(Icons.storefront),
                    ),
                  ],
                  selected: <_DetailMode>{_mode},
                  onSelectionChanged: (selection) =>
                      setState(() => _mode = selection.first),
                ),
                const SizedBox(height: 16),
                if (_mode == _DetailMode.card)
                  ..._buildCardView(theme, records)
                else
                  ..._buildStoreView(theme, records),
              ],
            ),
    );
  }

  // ---------- カード別 ----------

  List<Widget> _buildCardView(
    ThemeData theme,
    List<TransactionRecord> records,
  ) {
    final summary = _summaryOf(records);
    final spendByCard = <String, int>{};
    for (final record in records) {
      spendByCard[record.instrumentId] =
          (spendByCard[record.instrumentId] ?? 0) + record.amountYen;
    }

    final rewardByCard = <String, int>{
      for (final entry in summary.entries)
        entry.instrumentId.value: entry.totalValue.micros ~/ 1000000,
    };

    final rows = <BarDatum>[];
    final ordered = spendByCard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final item in ordered) {
      final reward = rewardByCard[item.key] ?? 0;
      rows.add(
        BarDatum(
          label: _cardName(item.key),
          value: item.value,
          detail: '還元 ${_group(reward)}円',
        ),
      );
    }

    return <Widget>[
      Text('カードごとの利用金額', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      SimpleBarRows(data: rows),
      const SizedBox(height: 8),
      Text(
        '※ 還元額は、その記録で使ったカードとお店の組み合わせで計算します。'
        '月間で合算するカードは月の合計から、取引ごとに計算するカードは1件ずつ計算します。',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      Text('カードごとの利用明細', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('明細を押すと、修正・削除ができます。', style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      for (final cardId in _cardOrder(records)) ...<Widget>[
        _groupHeader(
          theme,
          _cardName(cardId),
          '${records.where((r) => r.instrumentId == cardId).length}件 ・ '
              '${_group(spendByCard[cardId] ?? 0)}円',
          '還元 ${_group(rewardByCard[cardId] ?? 0)}円',
        ),
        for (final record in records)
          if (record.instrumentId == cardId) _recordTile(theme, record),
      ],
    ];
  }

  // ---------- 店舗別 ----------

  List<Widget> _buildStoreView(
    ThemeData theme,
    List<TransactionRecord> records,
  ) {
    final spendByStore = <String, int>{};
    final nameByStore = <String, String>{};
    for (final record in records) {
      spendByStore[record.merchantId] =
          (spendByStore[record.merchantId] ?? 0) + record.amountYen;
      nameByStore[record.merchantId] = _storeName(record);
    }

    final ordered = spendByStore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rows = <BarDatum>[
      for (final item in ordered)
        BarDatum(label: nameByStore[item.key] ?? item.key, value: item.value),
    ];

    return <Widget>[
      Text('店舗ごとの利用金額', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      SimpleBarRows(data: rows),
      const SizedBox(height: 20),
      Text('店舗ごとの利用明細', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('明細を押すと、修正・削除ができます。', style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      for (final item in ordered) ...<Widget>[
        _groupHeader(
          theme,
          nameByStore[item.key] ?? item.key,
          '${records.where((r) => r.merchantId == item.key).length}件 ・ '
              '${_group(item.value)}円',
          null,
        ),
        for (final record in records)
          if (record.merchantId == item.key) _recordTile(theme, record),
      ],
    ];
  }

  // ---------- 部品 ----------

  List<String> _cardOrder(List<TransactionRecord> records) {
    final spend = <String, int>{};
    for (final record in records) {
      spend[record.instrumentId] =
          (spend[record.instrumentId] ?? 0) + record.amountYen;
    }
    final ordered = spend.keys.toList()
      ..sort((a, b) => (spend[b] ?? 0).compareTo(spend[a] ?? 0));

    return ordered;
  }

  String _cardName(String instrumentId) {
    final catalog = context.read<RankingController>().catalog;
    final id = StableId.create(instrumentId).fold<StableId?>(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );

    if (id == null) {
      return instrumentId;
    }

    return catalog.paymentInstrumentsById[id]?.name ?? instrumentId;
  }

  String _storeName(TransactionRecord record) {
    if (record.merchantName.isEmpty || record.merchantId.isEmpty) {
      return 'その他';
    }

    return record.merchantName;
  }

  Widget _groupHeader(
    ThemeData theme,
    String title,
    String subtitle,
    String? trailing,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _recordTile(ThemeData theme, TransactionRecord record) {
    return Card(
      child: ListTile(
        dense: true,
        title: Text('${_group(record.amountYen)}円'),
        subtitle: Text(
          '${record.occurredOn} ・ ${_storeName(record)} ・ '
          '${_cardName(record.instrumentId)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => _editRecord(record),
      ),
    );
  }

  /// 記録を修正・削除する（D-162）。
  Future<void> _editRecord(TransactionRecord record) async {
    final controller = context.read<RankingController>();
    final result = await showModalBottomSheet<RecordEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordEditorSheet(
        controller: controller,
        initial: record,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final List<TransactionRecord> next;
    if (result.deleted) {
      next = <TransactionRecord>[
        for (final item in _all)
          if (item.id != record.id) item,
      ];
    } else {
      final updated = result.record;
      if (updated == null) {
        return;
      }
      next = <TransactionRecord>[
        for (final item in _all)
          if (item.id == record.id) updated else item,
      ];
    }

    setState(() => _all = next);
    widget.onRecordsChanged?.call(next);
  }

  AnnualRewardSummary _summaryOf(List<TransactionRecord> records) {
    final controller = context.read<RankingController>();
    final transactions = <AnnualSpendTransaction>[];

    for (final record in records) {
      final merchant = controller.merchantById(record.merchantId);
      final date = CalculationDate.parse(record.occurredOn).fold(
        onSuccess: (value) => value,
        onFailure: (_) => controller.currentJstDate(),
      );
      final instrumentId = StableId.create(record.instrumentId).fold<StableId?>(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );

      transactions.add(
        AnnualSpendTransaction(
          date: date,
          amount: MoneyYen(record.amountYen),
          instrumentId: instrumentId,
          merchantId: merchant?.id,
          merchantGroupIds: merchant?.groupIds ?? const <StableId>[],
          categoryIds: merchant?.categoryIds ?? const <StableId>[],
        ),
      );
    }

    return controller.annualSummaryFor(transactions);
  }
}

String _group(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[index]);
  }

  return buffer.toString();
}
