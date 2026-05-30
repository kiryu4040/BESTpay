import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/payment_method.dart';
import '../models/reward_rule.dart';
import '../models/store.dart';
import '../providers/app_state.dart';

class CustomRuleScreen extends StatefulWidget {
  const CustomRuleScreen({super.key});
  @override
  State<CustomRuleScreen> createState() => _CustomRuleScreenState();
}

class _CustomRuleScreenState extends State<CustomRuleScreen> {
  List<CustomRule> _rules = [];
  List<Store> _stores = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    _rules = await db.getCustomRules();
    _stores = await db.getStores();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _storeName(int id) => _stores
      .firstWhere((e) => e.id == id,
          orElse: () => Store(name: '?', category: 'other'))
      .name;

  String _payName(int id, List<PaymentMethod> ps) => ps
      .firstWhere(
        (e) => e.id == id,
        orElse: () => PaymentMethod(
          name: '?',
          type: 'credit',
          issuer: '',
          baseRate: 0,
          annualFee: 0,
          color: '#999',
        ),
      )
      .name;

  Future<void> _showAdd(BuildContext ctx) async {
    final db = DatabaseHelper.instance;
    final state = ctx.read<AppState>();
    final payments = state.payments;
    int? selectedStore = _stores.isNotEmpty ? _stores.first.id : null;
    int? selectedPay = payments.isNotEmpty ? payments.first.id : null;
    final rateCtrl = TextEditingController(text: '5.0');
    final memoCtrl = TextEditingController();

    await showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (c, setStateD) => AlertDialog(
          title: const Text('カスタムルール追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedStore,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '店舗'),
                  items: _stores
                      .map((s) => DropdownMenuItem(
                          value: s.id, child: Text('${s.icon} ${s.name}')))
                      .toList(),
                  onChanged: (v) => setStateD(() => selectedStore = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedPay,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '決済方法'),
                  items: payments
                      .map((p) => DropdownMenuItem(
                          value: p.id, child: Text(p.name)))
                      .toList(),
                  onChanged: (v) => setStateD(() => selectedPay = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rateCtrl,
                  decoration: const InputDecoration(
                      labelText: '還元率 (%)', suffixText: '%'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(labelText: 'メモ (任意)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                if (selectedStore == null || selectedPay == null) return;
                await db.insertCustomRule(CustomRule(
                  storeId: selectedStore!,
                  paymentId: selectedPay!,
                  customRate: double.tryParse(rateCtrl.text) ?? 0,
                  memo: memoCtrl.text,
                  createdAt: DateTime.now().toIso8601String(),
                ));
                if (c.mounted) Navigator.pop(c);
                await _load();
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('カスタムルール')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('追加'),
        onPressed: () => _showAdd(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '独自の還元ルールを登録できます。\n例: 特定店舗で使えるクーポン適用後の還元率など',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _rules.length,
                  itemBuilder: (_, i) {
                    final r = _rules[i];
                    return ListTile(
                      title: Text(
                          '${_storeName(r.storeId)} × ${_payName(r.paymentId, state.payments)}'),
                      subtitle: Text(
                          '${r.customRate.toStringAsFixed(1)}% ${r.memo.isNotEmpty ? "・${r.memo}" : ""}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await DatabaseHelper.instance.deleteCustomRule(r.id!);
                          await _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
