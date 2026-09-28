import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/settings/condition_option.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';

/// 還元率の条件をカードごとに設定する画面（D-114・D-119）。
///
/// 三つの状態（満たす／満たさない／不明）は分かりにくいため、
/// 「その条件を計算に入れるかどうか」の入切で選ぶ。
/// 個数で決まる条件は、1項目のまま数を増減できる。
final class ConditionSettingsScreen extends StatelessWidget {
  const ConditionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);
    final instruments = controller.instrumentsWithConditions;

    return Scaffold(
      appBar: AppBar(title: const Text('還元率の条件')),
      body: instruments.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('設定できる条件はまだありません。'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'あてはまる条件をオンにすると、その分が還元率に加算されます。'
                      'オフのあいだは計算に入りません。',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final instrument in instruments) ...<Widget>[
                  _buildCardHeader(context, controller, instrument.id.value,
                      instrument.name),
                  const SizedBox(height: 8),
                  for (final option in _visibleOptions(
                      controller.conditionsForInstrument(instrument.id.value)))
                    _buildOption(context, controller, option),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  /// 個数で選ぶ条件は、まとまりの先頭だけを出す（D-119）。
  List<ConditionOption> _visibleOptions(
    List<ConditionOption> options,
  ) {
    final seenGroups = <String>{};
    final visible = <ConditionOption>[];

    for (final option in options) {
      final groupId = option.countGroupId;
      if (groupId == null) {
        visible.add(option);
        continue;
      }

      if (seenGroups.add(groupId)) {
        visible.add(option);
      }
    }

    return visible;
  }

  Widget _buildCardHeader(
    BuildContext context,
    RankingController controller,
    String instrumentId,
    String name,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          LogoTile(
            assetPath: cardLogoPath(instrumentId),
            label: name,
            size: 44,
            padding: 3,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: theme.textTheme.titleMedium),
                Text(
                  controller.conditionSummaryFor(instrumentId),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    RankingController controller,
    ConditionOption option,
  ) {
    final theme = Theme.of(context);
    final groupId = option.countGroupId;

    if (groupId != null) {
      final count = controller.conditionCountOf(groupId);
      final max = option.countGroupMax;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(option.name, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(option.description, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: count <= 0
                        ? null
                        : () => controller.setConditionCount(groupId, count - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$count / $max 件',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: count >= max
                        ? null
                        : () => controller.setConditionCount(groupId, count + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const Spacer(),
                  Text(
                    count == 0 ? '計算に入れない' : '+${count}.0%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              _notesTile(theme, option.notes),
            ],
          ),
        ),
      );
    }

    final isOn = controller.conditionStateOf(option.id) == TriState.satisfied;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(option.name, style: theme.textTheme.titleSmall),
                ),
                Switch(
                  value: isOn,
                  onChanged: (value) => controller.setConditionState(
                    option.id,
                    value ? TriState.satisfied : TriState.notSatisfied,
                  ),
                ),
              ],
            ),
            Text(option.description, style: theme.textTheme.bodySmall),
            _notesTile(theme, option.notes),
          ],
        ),
      ),
    );
  }

  Widget _notesTile(ThemeData theme, List<String> notes) {
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text('くわしい条件', style: theme.textTheme.labelSmall),
        children: <Widget>[
          for (final note in notes)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('・$note', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
