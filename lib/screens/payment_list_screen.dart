import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/formatter.dart';
import '../widgets/payment_color_dot.dart';

class PaymentListScreen extends StatelessWidget {
  const PaymentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('保有決済方法の管理')),
      body: ListView.separated(
        itemCount: state.payments.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = state.payments[i];
          return SwitchListTile(
            value: p.enabled,
            onChanged: (v) => state.togglePayment(p.id!, v),
            secondary: PaymentColorDot(hex: p.color, size: 18),
            title: Text(p.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Chip(
                      label: Text(p.typeLabel,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 6),
                    Text('基本 ${Fmt.pctShort(p.baseRate)}',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                        '年会費 ${p.annualFee == 0 ? "無料" : Fmt.yen(p.annualFee)}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                if (p.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(p.note,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
