import 'package:bestpay/application/ranking/annual_reward_summary_usecase.dart';
import 'package:bestpay/application/records/transaction_record_store.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:bestpay/infrastructure/records/shared_preferences_transaction_record_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../screens/monthly_detail_screen.dart';
import '../widgets/charts.dart';
import '../widgets/record_editor_sheet.dart';

/// 年間タブ（D-121・D-161・D-162・D-163）。
///
/// 会計ごとに「いつ・どの店で・いくら使ったか」を記録し、1年ごとに
/// 「いくら還元されたか」を見える化する。
///
/// - 上: 店舗別の利用額（左）とカード別の還元額（右）の円グラフ
/// - 中: 月ごとの利用金額と還元額（棒グラフ・還元はオレンジ）
/// - 月を選ぶと、カード別／店舗別の内訳画面へ移動する
/// - 記入履歴は最新5件を表示し、押すと修正・削除できる
///
/// 会計の入力は右上の「＋」からのみ行う。
final class YearlyTab extends StatefulWidget {
  const YearlyTab({super.key, this.store});

  /// 保存先。テストでは差し替える。
  final TransactionRecordStore? store;

  @override
  State<YearlyTab> createState() => _YearlyTabState();
}

final class _YearlyTabState extends State<YearlyTab> {
  /// 記入履歴に出す件数（D-163）。
  static const int _historyLimit = 5;

  late final TransactionRecordStore _store =
      widget.store ?? const SharedPreferencesTransactionRecordStore();

  List<TransactionRecord> _records = const <TransactionRecord>[];
  int? _selectedYear;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 保存先が応答しない場合でも画面は開けるようにする。
    final records = await _store.load().timeout(
          const Duration(seconds: 5),
          onTimeout: () => const <TransactionRecord>[],
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  List<int> get _years {
    final years = <int>{DateTime.now().year};
    for (final record in _records) {
      if (record.year > 0) {
        years.add(record.year);
      }
    }

    final sorted = years.toList()..sort((a, b) => b.compareTo(a));

    return sorted;
  }

  int get _year => _selectedYear ?? DateTime.now().year;

  List<TransactionRecord> get _yearRecords {
    final records = <TransactionRecord>[
      for (final record in _records)
        if (record.year == _year) record,
    ];
    records.sort((a, b) => b.occurredOn.compareTo(a.occurredOn));

    return records;
  }

  List<int> get _months {
    final months = <int>{for (final record in _yearRecords) record.month}.toList()
      ..sort();

    return months;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: Text('記録を読み込んでいます…')),
      );
    }

    final records = _yearRecords;
    final summary = _summaryOf(records);
    final rewards = _perRecordRewards(records);

    return Scaffold(
      appBar: AppBar(
        title: const Text('年間'),
        actions: <Widget>[
          IconButton(
            tooltip: '会計を記録する',
            onPressed: _addRecord,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('見る年', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final year in _years)
                ChoiceChip(
                  label: Text('$year年'),
                  selected: year == _year,
                  onSelected: (_) => setState(() => _selectedYear = year),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '1月から12月末までを1年として数えます。年が変わると集計は新しく始まります。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'まだ記録がありません。右上の「＋」から会計を記録してください。',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else ...<Widget>[
            _buildSummary(theme, records, summary),
            const SizedBox(height: 20),
            _buildPies(theme, records, summary),
            const SizedBox(height: 24),
            Text('月ごとの利用金額と還元額', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SimpleColumnChart(
              data: <BarDatum>[
                for (var month = 1; month <= 12; month++)
                  BarDatum(
                    label: '$month月',
                    value: _spendOfMonth(records, month),
                    reward: _rewardOfMonth(records, rewards, month),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('月を選ぶ', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final month in _months)
                  ActionChip(
                    avatar: const Icon(Icons.chevron_right, size: 18),
                    label: Text('$month月'),
                    onPressed: () => _openMonth(month),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('記入履歴', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '新しい記入から$_historyLimit件を表示します。'
              'それより前の記録は、月の内訳画面から直せます。'
              '押すと金額・日付・お店・カードを直したり、削除したりできます。',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final record in records.take(_historyLimit))
              _buildRecordTile(theme, record, rewards[record.id] ?? 0),
            const SizedBox(height: 20),
            Text(
              '※ 還元額は、その記録で使ったカードとお店の組み合わせで計算し、'
              'カードごとの計算方法（月間の合計から計算するカードと、'
              '取引ごとに計算するカード）に合わせて積み上げています。'
              '条件つきの上乗せは「設定」タブの状態が反映されます。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  // ---------- 円グラフ ----------

  Widget _buildPies(
    ThemeData theme,
    List<TransactionRecord> records,
    AnnualRewardSummary summary,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _pieCard(
            theme,
            title: '店舗別の利用額（$_year年）',
            slices: _storeSlices(records),
            centerTitle: '使った額',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pieCard(
            theme,
            title: 'カード別の還元（$_year年）',
            slices: _rewardSlices(summary),
            centerTitle: '還元額',
          ),
        ),
      ],
    );
  }

  Widget _pieCard(
    ThemeData theme, {
    required String title,
    required List<PieSlice> slices,
    required String centerTitle,
  }) {
    var total = 0;
    for (final slice in slices) {
      total += slice.value;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('まだありません。', style: theme.textTheme.bodySmall),
              )
            else
              Center(
                child: SimplePieChart(
                  slices: slices,
                  size: 140,
                  centerTitle: centerTitle,
                  centerValue: '${_group(total)}円',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 店舗ごとの年間利用額（D-163）。
  List<PieSlice> _storeSlices(List<TransactionRecord> records) {
    final spend = <String, int>{};
    final names = <String, String>{};
    for (final record in records) {
      spend[record.merchantId] =
          (spend[record.merchantId] ?? 0) + record.amountYen;
      names[record.merchantId] = _storeName(record);
    }

    final ordered = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return <PieSlice>[
      for (var index = 0; index < ordered.length; index++)
        PieSlice(
          label: names[ordered[index].key] ?? ordered[index].key,
          value: ordered[index].value,
          color: chartColorAt(index),
        ),
    ];
  }

  /// カードごとの年間還元額。
  List<PieSlice> _rewardSlices(AnnualRewardSummary summary) {
    final ordered = summary.entries.toList()
      ..sort((a, b) => b.totalValue.compareTo(a.totalValue));

    final slices = <PieSlice>[];
    for (var index = 0; index < ordered.length; index++) {
      final yen = ordered[index].totalValue.micros ~/ 1000000;
      if (yen <= 0) {
        continue;
      }
      slices.add(
        PieSlice(
          label: ordered[index].instrumentName,
          value: yen,
          color: chartColorAt(index),
        ),
      );
    }

    return slices;
  }

  // ---------- 部品 ----------

  int _spendOfMonth(List<TransactionRecord> records, int month) {
    var total = 0;
    for (final record in records) {
      if (record.month == month) {
        total += record.amountYen;
      }
    }

    return total;
  }

  int _rewardOfMonth(
    List<TransactionRecord> records,
    Map<String, int> rewards,
    int month,
  ) {
    var total = 0;
    for (final record in records) {
      if (record.month == month) {
        total += rewards[record.id] ?? 0;
      }
    }

    return total;
  }

  Widget _buildRecordTile(
    ThemeData theme,
    TransactionRecord record,
    int reward,
  ) {
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

  Widget _buildSummary(
    ThemeData theme,
    List<TransactionRecord> records,
    AnnualRewardSummary summary,
  ) {
    var spend = 0;
    for (final record in records) {
      spend += record.amountYen;
    }
    var reward = 0;
    for (final entry in summary.entries) {
      reward += entry.totalValue.micros ~/ 1000000;
    }

    final rate = spend == 0
        ? Rational.zero
        : Rational.create(reward, spend).fold(
            onSuccess: (value) => value,
            onFailure: (_) => Rational.zero,
          );

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('$_year年の合計', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _metric(theme, '使った額', '${_group(spend)}円'),
                _metric(theme, '還元された額', '${_group(reward)}円'),
                _metric(theme, '還元率', _formatRate(rate)),
              ],
            ),
            const SizedBox(height: 4),
            Text('記録 ${records.length} 件', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _metric(ThemeData theme, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelSmall),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openMonth(int month) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MonthlyDetailScreen(
          year: _year,
          month: month,
          records: _records,
          onRecordsChanged: _applyRecords,
        ),
      ),
    );
  }

  String _storeName(TransactionRecord record) {
    if (record.merchantName.isEmpty || record.merchantId.isEmpty) {
      return 'その他';
    }

    return record.merchantName;
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

  AnnualRewardSummary _summaryOf(List<TransactionRecord> records) {
    final controller = context.read<RankingController>();
    final transactions = <AnnualSpendTransaction>[
      for (final record in records) _toTransaction(controller, record),
    ];

    return controller.annualSummaryFor(transactions);
  }

  /// 記録ごとの還元額（円）を、月内の累計を踏まえて求める（D-163）。
  Map<String, int> _perRecordRewards(List<TransactionRecord> records) {
    final controller = context.read<RankingController>();
    final byMonth = <int, List<TransactionRecord>>{};
    for (final record in records) {
      byMonth.putIfAbsent(record.month, () => <TransactionRecord>[]).add(record);
    }

    final result = <String, int>{};
    for (final entry in byMonth.entries) {
      final list = entry.value.toList()
        ..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
      final rewards = controller.rewardYenPerTransaction(
        <AnnualSpendTransaction>[
          for (final record in list) _toTransaction(controller, record),
        ],
      );
      for (var index = 0; index < list.length; index++) {
        result[list[index].id] = rewards[index];
      }
    }

    return result;
  }

  /// 記録を差し替えて保存する（D-162）。
  Future<void> _applyRecords(List<TransactionRecord> next) async {
    if (mounted) {
      setState(() => _records = next);
    }
    await _store.save(next);
  }

  Future<void> _addRecord() async {
    final controller = context.read<RankingController>();
    final result = await showModalBottomSheet<RecordEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordEditorSheet(
        controller: controller,
        allowDate: false,
      ),
    );

    final record = result?.record;
    if (record == null) {
      return;
    }

    await _applyRecords(<TransactionRecord>[..._records, record]);
  }

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

    if (result == null) {
      return;
    }

    final List<TransactionRecord> next;
    if (result.deleted) {
      next = <TransactionRecord>[
        for (final item in _records)
          if (item.id != record.id) item,
      ];
    } else {
      final updated = result.record;
      if (updated == null) {
        return;
      }
      next = <TransactionRecord>[
        for (final item in _records)
          if (item.id == record.id) updated else item,
      ];
    }

    await _applyRecords(next);
  }
}

String _formatRate(Rational rate) {
  final hundredths = (BigInt.from(rate.numerator) * BigInt.from(10000)) ~/
      BigInt.from(rate.denominator);
  final whole = hundredths ~/ BigInt.from(100);
  final fraction = (hundredths % BigInt.from(100)).toString().padLeft(2, '0');

  return '$whole.$fraction%';
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
