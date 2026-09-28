import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/settings/condition_option.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';

/// 還元率の条件をカードごとに設定する画面（D-114・D-119・D-122）。
///
/// 条件は今後も増えるため、カードをタップすると中身が出し入れできる。
/// 三つの状態（満たす／満たさない／不明）は分かりにくいため、
/// 「その条件を計算に入れるかどうか」の入切で選ぶ。
/// 個数で決まる条件は、1項目のまま数を増減できる。
final class ConditionSettingsScreen extends StatefulWidget {
  const ConditionSettingsScreen({super.key});

  @override
  State<ConditionSettingsScreen> createState() =>
      _ConditionSettingsScreenState();
}

final class _ConditionSettingsScreenState extends State<ConditionSettingsScreen> {
  /// 開いているカード。最初はすべて閉じておく。
  final Set<String> _expanded = <String>{};

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
                for (final instrument in instruments)
                  _buildCardSection(context, controller, instrument.id.value,
                      instrument.name),
              ],
            ),
    );
  }

  Widget _buildCardSection(
    BuildContext context,
    RankingController controller,
    String instrumentId,
    String name,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOpen = _expanded.contains(instrumentId);
    final options = _visibleOptions(
      controller.conditionsForInstrument(instrumentId),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => setState(() {
              if (isOpen) {
                _expanded.remove(instrumentId);
              } else {
                _expanded.add(instrumentId);
              }
            }),
            child: Container(
              padding: const EdgeInsets.all(12),
              color: colorScheme.surfaceContainerHighest,
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
                  Icon(
                    isOpen ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: <Widget>[
                  for (final option in options)
                    _buildOption(context, controller, option),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 個数で選ぶ条件は、まとまりの先頭だけを出す（D-119）。
  List<ConditionOption> _visibleOptions(List<ConditionOption> options) {
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

      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(option.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(option.description, style: theme.textTheme.bodySmall),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: count <= 0
                      ? null
                      : () => controller.setConditionCount(groupId, count - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$count / $max 件', style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: count >= max
                      ? null
                      : () => controller.setConditionCount(groupId, count + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const Spacer(),
                Text(
                  count == 0 ? '計算に入れない' : '+$count.0%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            _notesTile(theme, option.notes),
          ],
        ),
      );
    }

    final isOn = controller.conditionStateOf(option.id) == TriState.satisfied;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
