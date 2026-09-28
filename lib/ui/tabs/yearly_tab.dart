import 'package:bestpay/application/records/transaction_record_store.dart';
import 'package:bestpay/core/value_objects/calculation_date.dart';
import 'package:bestpay/core/value_objects/micros_yen.dart';
import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/core/value_objects/rational.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:bestpay/infrastructure/records/shared_preferences_transaction_record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';

/// 年間タブ（D-121）。
///
/// 会計ごとに「いつ・どの店で・いくら使ったか」を記録し、
/// 1月から12月末までの1年ごとに、使った額と還元された額をまとめて見る。
/// 年が変わると新しい年の集計が自動で始まる。
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
  final Map<String, int> _rewardYen = <String, int>{};
  final Map<String, String> _rewardPoints = <String, String>{};
  int? _selectedYear;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 保存先が応答しない場合でも画面は開けるようにする。
    final records = await _store
        .load()
        .timeout(const Duration(seconds: 5), onTimeout: () => const <TransactionRecord>[]);
    if (!mounted) {
      return;
    }

    setState(() {
      _records = records;
      _isLoading = false;
    });
    _recomputeRewards();
  }

  /// 記録ごとの還元額をカタログから計算し直す（保存はしない）。
  void _recomputeRewards() {
    final controller = context.read<RankingController>();
    _rewardYen.clear();
    _rewardPoints.clear();

    for (final record in _records) {
      final merchant = controller.merchantById(record.merchantId);
      if (merchant == null) {
        continue;
      }

      final date = CalculationDate.parse(record.occurredOn).fold(
            onSuccess: (value) => value,
            onFailure: (_) => controller.currentJstDate(),
          );

      final ranking = controller.evaluateAtMerchant(
        merchant: merchant,
        amount: MoneyYen(record.amountYen),
        date: date,
      );

      for (final entry in ranking.allEntries) {
        if (entry.instrumentId.value != record.instrumentId) {
          continue;
        }

        _rewardYen[record.id] = entry.confirmedValue.micros ~/
            MicrosYen.microsPerYen;
        _rewardPoints[record.id] = entry.programAwards
            .map((award) => '${award.points.points}${award.unitName}')
            .join('＋');
      }
    }
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

  int get _totalSpend {
    var total = 0;
    for (final record in _yearRecords) {
      total += record.amountYen;
    }

    return total;
  }

  int get _totalReward {
    var total = 0;
    for (final record in _yearRecords) {
      total += _rewardYen[record.id] ?? 0;
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: Text('記録を読み込んでいます…')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('年間'),
        actions: <Widget>[
          IconButton(
            tooltip: '記録を追加',
            onPressed: _addRecord,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('記録する年', style: theme.textTheme.labelLarge),
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
          const SizedBox(height: 12),
          _buildSummary(context),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _addRecord,
            icon: const Icon(Icons.add),
            label: const Text('会計を記録する'),
          ),
          const SizedBox(height: 20),
          if (_yearRecords.isEmpty)
            Text(
              'まだ記録がありません。「会計を記録する」から追加してください。',
              style: theme.textTheme.bodySmall,
            )
          else ...<Widget>[
            Text('店舗ごとの集計', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildMerchantTotals(context),
            const SizedBox(height: 20),
            Text('会計の記録', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final month in _monthsOf(_yearRecords)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text('$month月', style: theme.textTheme.titleSmall),
              ),
              for (final record in _yearRecords)
                if (record.month == month) _buildRecord(context, record),
            ],
          ],
        ],
      ),
    );
  }

  List<int> _monthsOf(List<TransactionRecord> records) {
    final months = <int>{for (final record in records) record.month}.toList()
      ..sort((a, b) => b.compareTo(a));

    return months;
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final spend = _totalSpend;
    final reward = _totalReward;
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
            Text(
              '記録 ${_yearRecords.length} 件',
              style: theme.textTheme.bodySmall,
            ),
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

  Widget _buildMerchantTotals(BuildContext context) {
    final theme = Theme.of(context);
    final totals = <String, _MerchantTotal>{};

    for (final record in _yearRecords) {
      final total = totals.putIfAbsent(
        record.merchantId,
        () => _MerchantTotal(name: record.merchantName),
      );
      total
        ..count += 1
        ..spend += record.amountYen
        ..reward += _rewardYen[record.id] ?? 0;
    }

    final ordered = totals.values.toList()
      ..sort((a, b) => b.spend.compareTo(a.spend));

    return Column(
      children: <Widget>[
        for (final total in ordered)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(total.name, style: theme.textTheme.titleSmall),
                        Text(
                          '${total.count}件 ・ ${_group(total.spend)}円',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_group(total.reward)}円',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecord(BuildContext context, TransactionRecord record) {
    final theme = Theme.of(context);
    final reward = _rewardYen[record.id];
    final points = _rewardPoints[record.id];
    final cardName = context
            .watch<RankingController>()
            .catalog
            .paymentInstrumentsById[
                _stableIdOrNull(record.instrumentId)]
            ?.name ??
        record.instrumentId;

    return Card(
      child: ListTile(
        title: Text(record.merchantName),
        subtitle: Text(
          '${record.occurredOn} ・ $cardName'
          '${points == null || points.isEmpty ? '' : ' ・ $points'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${_group(record.amountYen)}円',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  reward == null ? '—' : '還元 ${_group(reward)}円',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            IconButton(
              tooltip: '削除',
              onPressed: () => _deleteRecord(record),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRecord(TransactionRecord record) {
    final remaining = <TransactionRecord>[
      for (final item in _records)
        if (item.id != record.id) item,
    ];
    setState(() {
      _records = remaining;
      _rewardYen.remove(record.id);
      _rewardPoints.remove(record.id);
    });
    _store.save(remaining);
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
    _recomputeRewards();
    setState(() {});
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
      instrumentId = ranking.bestEntry?.instrumentId.value ??
          'mizuho_rakuten_card';
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

final class _MerchantTotal {
  _MerchantTotal({required this.name});

  final String name;
  int count = 0;
  int spend = 0;
  int reward = 0;
}

String _stableIdOrNull(String value) => value;

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
