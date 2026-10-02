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

/// 1か月分の内訳を見る画面（D-161・D-162・D-163・D-167）。
///
/// 「カード別」と「店舗別」を切り替えられる。どちらも上に比較の棒グラフ
/// （利用金額＋還元額はオレンジで重ねる）、下に入力した順の利用明細を並べる。
/// 明細はまとまりごとに最新3件だけを表示し、それを超える分は折りたたむ。
/// 明細を押すと修正・削除ができる。
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
  /// 常時表示する明細の件数（D-167）。
  static const int _visibleRecords = 3;

  _DetailMode _mode = _DetailMode.card;
  late List<TransactionRecord> _all = widget.records;
  final Set<String> _expanded = <String>{};

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
    final rewards = _perRecordRewards(records);

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
                  ..._buildCardView(theme, records, rewards)
                else
                  ..._buildStoreView(theme, records, rewards),
              ],
            ),
    );
  }

  // ---------- カード別 ----------

  List<Widget> _buildCardView(
    ThemeData theme,
    List<TransactionRecord> records,
    Map<String, int> rewards,
  ) {
    final spendByCard = <String, int>{};
    final rewardByCard = <String, int>{};
    for (final record in records) {
      spendByCard[record.instrumentId] =
          (spendByCard[record.instrumentId] ?? 0) + record.amountYen;
      rewardByCard[record.instrumentId] =
          (rewardByCard[record.instrumentId] ?? 0) + (rewards[record.id] ?? 0);
    }

    final ordered = spendByCard.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rows = <BarDatum>[
      for (var index = 0; index < ordered.length; index++)
        BarDatum(
          label: _cardName(ordered[index].key),
          value: ordered[index].value,
          reward: rewardByCard[ordered[index].key] ?? 0,
          color: chartColorAt(index),
        ),
    ];

    return <Widget>[
      Text('カードごとの利用金額と還元額', style: theme.textTheme.titleMedium),
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
      Text(
        '明細を押すと、修正・削除ができます。最新$_visibleRecords件を表示しています。',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (final entry in ordered) ...<Widget>[
        _groupHeader(
          theme,
          _cardName(entry.key),
          '${records.where((r) => r.instrumentId == entry.key).length}件 ・ '
              '${_group(entry.value)}円',
          '還元 ${_group(rewardByCard[entry.key] ?? 0)}円',
        ),
        ..._recordList(
          theme,
          groupKey: 'card:${entry.key}',
          records: <TransactionRecord>[
            for (final record in records)
              if (record.instrumentId == entry.key) record,
          ],
          rewards: rewards,
        ),
      ],
    ];
  }

  // ---------- 店舗別 ----------

  List<Widget> _buildStoreView(
    ThemeData theme,
    List<TransactionRecord> records,
    Map<String, int> rewards,
  ) {
    final spendByStore = <String, int>{};
    final rewardByStore = <String, int>{};
    final nameByStore = <String, String>{};
    for (final record in records) {
      spendByStore[record.merchantId] =
          (spendByStore[record.merchantId] ?? 0) + record.amountYen;
      rewardByStore[record.merchantId] =
          (rewardByStore[record.merchantId] ?? 0) + (rewards[record.id] ?? 0);
      nameByStore[record.merchantId] = _storeName(record);
    }

    // グラフと明細を連動させ、利用金額の多い順、その他は最後にする（D-167）。
    final ordered = spendByStore.keys.toList()
      ..sort((a, b) {
        final aOther = a.isEmpty;
        final bOther = b.isEmpty;
        if (aOther != bOther) {
          return aOther ? 1 : -1;
        }
        return (spendByStore[b] ?? 0).compareTo(spendByStore[a] ?? 0);
      });

    final rows = <BarDatum>[];
    var colorIndex = 0;
    for (final key in ordered) {
      final isOther = key.isEmpty;
      rows.add(
        BarDatum(
          label: nameByStore[key] ?? key,
          value: spendByStore[key] ?? 0,
          reward: rewardByStore[key] ?? 0,
          color: isOther ? null : chartColorAt(colorIndex),
          separated: isOther,
        ),
      );
      if (!isOther) {
        colorIndex += 1;
      }
    }

    return <Widget>[
      Text('店舗ごとの利用金額と還元額', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      SimpleBarRows(data: rows, maxBarRatio: 0.9),
      const SizedBox(height: 8),
      Text(
        '※ 店舗を指定しなかった「その他」は、他店舗と混ざらないようグラフの最下部に分けて表示します。'
        '棒の長さは最大値の90%までに収めています。',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      Text('店舗ごとの利用明細', style: theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        '明細を押すと、修正・削除ができます。最新$_visibleRecords件を表示しています。',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (final key in ordered) ...<Widget>[
        _groupHeader(
          theme,
          nameByStore[key] ?? key,
          '${records.where((r) => r.merchantId == key).length}件 ・ '
              '${_group(spendByStore[key] ?? 0)}円',
          '還元 ${_group(rewardByStore[key] ?? 0)}円',
        ),
        ..._recordList(
          theme,
          groupKey: 'store:$key',
          records: <TransactionRecord>[
            for (final record in records)
              if (record.merchantId == key) record,
          ],
          rewards: rewards,
        ),
      ],
    ];
  }

  // ---------- 部品 ----------

  /// まとまり（カード／店舗）ごとの明細。最新3件のみ表示し、残りは折りたたむ（D-167）。
  List<Widget> _recordList(
    ThemeData theme, {
    required String groupKey,
    required List<TransactionRecord> records,
    required Map<String, int> rewards,
  }) {
    if (records.isEmpty) {
      return const <Widget>[];
    }

    final expanded = _expanded.contains(groupKey);
    final visible =
        expanded ? records : records.take(_visibleRecords).toList();
    final hidden = records.length - visible.length;

    return <Widget>[
      for (final record in visible)
        _recordTile(theme, record, rewards[record.id] ?? 0),
      if (records.length > _visibleRecords)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              if (expanded) {
                _expanded.remove(groupKey);
              } else {
                _expanded.add(groupKey);
              }
            }),
            icon: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              expanded ? '折りたたむ' : '残り$hidden件を表示（全${records.length}件）',
            ),
          ),
        ),
    ];
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
            Text(
              trailing,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: rewardOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _recordTile(ThemeData theme, TransactionRecord record, int reward) {
    return Card(
      child: ListTile(
        dense: true,
        title: Row(
          children: <Widget>[
            Text('${_group(record.amountYen)}円'),
            const SizedBox(width: 8),
            Text(
              '${_group(reward)}円還元',
              style: theme.textTheme.labelMedium?.copyWith(
                color: rewardOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

  /// 記録ごとの還元額（円）を、月内の累計を踏まえて求める（D-163）。
  Map<String, int> _perRecordRewards(List<TransactionRecord> records) {
    final controller = context.read<RankingController>();
    final list = records.toList()
      ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
    final rewards = controller.rewardYenPerTransaction(
      <AnnualSpendTransaction>[
        for (final record in list) _toTransaction(controller, record),
      ],
    );

    return <String, int>{
      for (var index = 0; index < list.length; index++)
        list[index].id: rewards[index],
    };
  }

  AnnualSpendTransaction _toTransaction(
    RankingController controller,
    TransactionRecord record,
  ) {
    final merchant = controller.merchantById(record.merchantId);
    final date = CalculationDate.parse(record.occurredOn).fold(
      onSuccess: (value) => value,
      onFailure: (_) => controller.currentJstDate(),
    );
    final instrumentId = StableId.create(record.instrumentId).fold<StableId?>(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );

    return AnnualSpendTransaction(
      date: date,
      amount: MoneyYen(record.amountYen),
      instrumentId: instrumentId,
      merchantId: merchant?.id,
      merchantGroupIds: merchant?.groupIds ?? const <StableId>[],
      categoryIds: merchant?.categoryIds ?? const <StableId>[],
    );
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
