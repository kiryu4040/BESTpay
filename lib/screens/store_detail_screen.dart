import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/payment_method.dart';
import '../models/reward_rule.dart';
import '../models/store.dart';
import '../providers/app_state.dart';
import '../utils/calculator.dart';
import '../utils/formatter.dart';
import '../widgets/payment_color_dot.dart';

class StoreDetailScreen extends StatefulWidget {
  final int storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  Store? _store;
  List<RewardRule> _rules = [];
  List<PaymentMethod> _payments = [];
  List<RankItem> _ranking = [];
  int _amount = 1000;
  final _amountController = TextEditingController(text: '1000');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final state = context.read<AppState>();
    final store = await db.getStore(widget.storeId);
    final rules = await db.getRulesForStore(widget.storeId);
    final payments = state.payments;
    final ranking = Calculator.rank(
      storeId: widget.storeId,
      amount: _amount,
      payments: payments,
      storeRules: rules,
      conditions: state.conditions,
    );
    if (!mounted) return;
    setState(() {
      _store = store;
      _rules = rules;
      _payments = payments;
      _ranking = ranking;
    });
  }

  void _recompute() {
    final state = context.read<AppState>();
    setState(() {
      _ranking = Calculator.rank(
        storeId: widget.storeId,
        amount: _amount,
        payments: _payments,
        storeRules: _rules,
        conditions: state.conditions,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _store!;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(s.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(child: Text(s.name)),
        ]),
        actions: [
          IconButton(
            icon: Icon(s.isFavorite ? Icons.star : Icons.star_border,
                color: s.isFavorite ? Colors.amber : null),
            onPressed: () async {
              await context
                  .read<AppState>()
                  .toggleFavorite(s.id!, !s.isFavorite);
              setState(() => s.isFavorite = !s.isFavorite);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Chip(
            label: Text(Store.categoryLabel(s.category)),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('利用金額',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixText: '円',
                        isDense: true,
                      ),
                      onChanged: (v) {
                        _amount = int.tryParse(v) ?? 0;
                        _recompute();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [500, 1000, 3000, 5000, 10000, 30000]
                .map((v) => ActionChip(
                      label: Text('¥$v'),
                      onPressed: () {
                        _amount = v;
                        _amountController.text = '$v';
                        _recompute();
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text('決済方法ランキング',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_ranking.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('この店舗での還元ルールが登録されていません')))
          else
            ..._ranking.asMap().entries.map((e) => _RankCard(
                  rank: e.key + 1,
                  item: e.value,
                  amount: _amount,
                )),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '還元率は条件達成状況に応じて変動します。「条件管理」画面で達成状況を更新してください。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final RankItem item;
  final int amount;
  const _RankCard(
      {required this.rank, required this.item, required this.amount});

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '  $rank ';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(medal, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                PaymentColorDot(hex: item.payment.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.payment.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.pctShort(item.rate),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: rank == 1
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '+${Fmt.yen(item.rewardYen)}相当',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: -8,
              children: [
                _Tag('基本 ${Fmt.pctShort(item.baseRate)}'),
                if (item.bonusRate > 0)
                  _Tag('店舗特典 +${Fmt.pctShort(item.bonusRate)}',
                      color: Colors.orange),
                if (item.conditionRate > 0)
                  _Tag('条件達成 +${Fmt.pctShort(item.conditionRate)}',
                      color: Colors.green),
              ],
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.note,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;
  const _Tag(this.text, {this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: c)),
    );
  }
}
