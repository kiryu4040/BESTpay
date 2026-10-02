import 'package:bestpay/application/ranking/annual_reward_summary_usecase.dart';
import 'package:bestpay/application/records/transaction_record_store.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/core/value_objects/stable_id.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:bestpay/infrastructure/records/shared_preferences_transaction_record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../screens/monthly_detail_screen.dart';
import '../widgets/charts.dart';

/// 年間タブ（D-121・D-161）。
///
/// 会計ごとに「いつ・どの店で・いくら使ったか」を記録し、1年ごとに
/// 「いくら還元されたか」を見える化する。
///
/// - 上: その年のカード別の還元ポイント（円グラフ）
/// - 中: 月ごとの利用金額（棒グラフ）
/// - 月を選ぶと、カード別／店舗別の内訳画面へ移動する
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
            Text(
              'カード別の還元（$_year年）',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildRewardPie(theme, summary),
            const SizedBox(height: 24),
            Text('月ごとの利用金額', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SimpleColumnChart(
              data: <BarDatum>[
                for (var month = 1; month <= 12; month++)
                  BarDatum(
                    label: '$month月',
                    value: _spendOfMonth(records, month),
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
            Text(
              '※ 還元額はカードごとの計算方法（月間の合計から計算するカードと、'
              '取引ごとに計算するカード）に合わせて積み上げています。'
              '条件つきの上乗せは「設定」タブの状態が反映されます。',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  int _spendOfMonth(List<TransactionRecord> records, int month) {
    var total = 0;
    for (final record in records) {
      if (record.month == month) {
        total += record.amountYen;
      }
    }

    return total;
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

  Widget _buildRewardPie(ThemeData theme, AnnualRewardSummary summary) {
    final ordered = summary.entries.toList()
      ..sort((a, b) => b.totalValue.compareTo(a.totalValue));

    final slices = <PieSlice>[];
    for (var index = 0; index < ordered.length; index++) {
      final entry = ordered[index];
      final yen = entry.totalValue.micros ~/ 1000000;
      if (yen <= 0) {
        continue;
      }

      slices.add(
        PieSlice(
          label: entry.instrumentName,
          value: yen,
          color: chartColorAt(index),
        ),
      );
    }

    if (slices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'この年の還元はまだありません。',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    var total = 0;
    for (final slice in slices) {
      total += slice.value;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SimplePieChart(
            slices: slices,
            centerTitle: '合計',
            centerValue: '${_group(total)}円',
          ),
        ),
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
        ),
      ),
    );
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

      transactions.add(
        AnnualSpendTransaction(
          date: date,
          amount: MoneyYen(record.amountYen),
          merchantId: merchant?.id,
          merchantGroupIds: merchant?.groupIds ?? const <StableId>[],
          categoryIds: merchant?.categoryIds ?? const <StableId>[],
        ),
      );
    }

    return controller.annualSummaryFor(transactions);
  }

  Future<void> _addRecord() async {
    final controller = context.read<RankingController>();
    final draft = await showModalBottomSheet<TransactionRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordEditor(controller: controller),
    );

    if (draft == null) {
      return;
    }

    final updated = <TransactionRecord>[..._records, draft];
    setState(() => _records = updated);
    await _store.save(updated);
  }
}

/// 会計1件を入力するシート。
final class _RecordEditor extends StatefulWidget {
  const _RecordEditor({required this.controller});

  final RankingController controller;

  @override
  State<_RecordEditor> createState() => _RecordEditorState();
}

final class _RecordEditorState extends State<_RecordEditor> {
  late final TextEditingController _amount = TextEditingController();
  late String _date = _today();
  MerchantEntry? _merchant;
  String? _instrumentId;
  String? _error;

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = widget.controller.catalog.paymentInstrumentsById.values
        .where((card) => widget.controller.isCardVisible(card.id.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Text('会計を記録する', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: '使った金額（円）',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(_merchant?.name ?? 'お店を選ぶ'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickMerchant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _instrumentId,
            decoration: const InputDecoration(
              labelText: '使ったカード',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              for (final card in cards)
                DropdownMenuItem<String>(
                  value: card.id.value,
                  child: Text(card.name),
                ),
            ],
            onChanged: (value) => setState(() => _instrumentId = value),
          ),
          const SizedBox(height: 8),
          Text(
            'カードを選ばないときは、その店でいちばん得なカードとして記録します。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('記録する'),
          ),
        ],
      ),
    );
  }

  void _pickMerchant() {
    final controller = widget.controller;
    final categories = controller.orderedCategories;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          children: <Widget>[
            for (final category in categories) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  category.name,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
              for (final merchant
                  in controller.merchantsInCategoryOrdered(category.id))
                ListTile(
                  title: Text(merchant.name),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _merchant = merchant);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    final merchant = _merchant;

    if (merchant == null) {
      setState(() => _error = 'お店を選んでください。');
      return;
    }

    if (amount < 1) {
      setState(() => _error = '1円以上の整数を入力してください。');
      return;
    }

    var instrumentId = _instrumentId;
    if (instrumentId == null) {
      final ranking = widget.controller.evaluateAtMerchant(
        merchant: merchant,
        amount: MoneyYen(amount),
      );
      instrumentId =
          ranking.bestEntry?.instrumentId.value ?? 'mizuho_rakuten_card';
    }

    Navigator.of(context).pop(
      TransactionRecord(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        occurredOn: _date,
        merchantId: merchant.id.value,
        merchantName: merchant.name,
        instrumentId: instrumentId,
        amountYen: amount,
      ),
    );
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
