import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';

/// 還元率の基準になる条件を設定する画面（D-101）。
///
/// カタログには条件の定義だけがあり、達成状態は利用者が決めて端末に保存する。
/// ここで決めた状態が、そのままランキングの計算に使われる。
final class ConditionSettingsScreen extends StatelessWidget {
  const ConditionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);
    final options = controller.conditionOptions;

    return Scaffold(
      appBar: AppBar(title: const Text('還元率の基準（条件）')),
      body: options.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('設定できる条件はまだありません。'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  'あてはまる状態を選ぶと、ランキングの計算に反映されます。'
                  '「不明」のあいだは、その分は確定値に含まれません。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final option in options)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(option.name, style: theme.textTheme.titleMedium),
                          if (option.description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              option.description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 8),
                          SegmentedButton<TriState>(
                            segments: const <ButtonSegment<TriState>>[
                              ButtonSegment<TriState>(
                                value: TriState.satisfied,
                                label: Text('満たす'),
                              ),
                              ButtonSegment<TriState>(
                                value: TriState.notSatisfied,
                                label: Text('満たさない'),
                              ),
                              ButtonSegment<TriState>(
                                value: TriState.unknown,
                                label: Text('不明'),
                              ),
                            ],
                            selected: <TriState>{
                              controller.conditionStateOf(option.id),
                            },
                            onSelectionChanged: (selection) {
                              controller.setConditionState(
                                option.id,
                                selection.first,
                              );
                            },
                          ),
                          for (final note in option.notes) ...<Widget>[
                            const SizedBox(height: 4),
                            Text('・$note', style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
