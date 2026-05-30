import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/calculator.dart';
import '../utils/formatter.dart';
import '../widgets/payment_color_dot.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  int _monthly = 50000;
  final _ctrl = TextEditingController(text: '50000');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final payments = state.payments.where((p) => p.enabled).toList();
    payments.sort((a, b) => b.baseRate.compareTo(a.baseRate));

    return Scaffold(
      appBar: AppBar(title: const Text('積立還元シミュレーション')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('月間利用額',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixText: '円',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        _monthly = int.tryParse(v) ?? 0;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '※ 各決済の「基本還元率」のみで試算。条件達成や店舗特典は反映していません。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          ...payments.map((p) {
            final m = Calculator.monthlyEstimate(
                rate: p.baseRate, monthlyAmount: _monthly);
            final y = Calculator.yearlyEstimate(
                rate: p.baseRate, monthlyAmount: _monthly);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    PaymentColorDot(hex: p.color, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text('還元率 ${Fmt.pctShort(p.baseRate)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('月 ${Fmt.yen(m)}',
                            style: const TextStyle(fontSize: 13)),
                        Text('年 ${Fmt.yen(y)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
