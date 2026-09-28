import 'package:bestpay/core/value_objects/tri_state.dart';
import 'package:bestpay/domain/settings/condition_option.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ranking_controller.dart';
import '../widgets/logo_tile.dart';

/// 1枚のカードの条件を入切する画面（D-123）。
///
/// 三状態（満たす／満たさない／不明）は分かりにくいため、条件として
/// 計算に入れるかどうかのオンオフだけにする（D-124）。
/// 個数で決まる条件は1項目の増減にまとめる（D-119）。
final class CardConditionScreen extends StatelessWidget {
  const CardConditionScreen({
    super.key,
    required this.instrumentId,
    required this.instrumentName,
  });

  final String instrumentId;
  final String instrumentName;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RankingController>();
    final theme = Theme.of(context);
    final options = controller.conditionsForInstrument(instrumentId);

    // まとめる条件（特定サービスの契約数など）は1項目に畳む。
    final grouped = <String, List<ConditionOption>>{};
    final singles = <ConditionOption>[];
    for (final option in options) {
      final groupId = option.countGroupId;
      if (groupId == null) {
        singles.add(option);
      } else {
        grouped.putIfAbsent(groupId, () => <ConditionOption>[]).add(option);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(instrumentName)),
      body: options.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('このカードに設定できる条件はありません。'),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    LogoTile(
                      assetPath: cardLogoPath(instrumentId),
                      label: instrumentName,
                      size: 48,
                      padding: 3,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'オンにした条件だけが還元率の計算に入ります。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final option in singles) _ToggleCard(
                  option: option,
                  value: controller.conditionStateOf(option.id) ==
                      TriState.satisfied,
                  onChanged: (value) => controller.setConditionState(
                    option.id,
                    value ? TriState.satisfied : TriState.notSatisfied,
                  ),
                ),
                for (final entry in grouped.entries)
                  _CountGroupCard(
                    title: _groupTitle(entry.value),
                    description: entry.value.first.description.split('。').first,
                    count: entry.value
                        .where((option) =>
                            controller.conditionStateOf(option.id) ==
                            TriState.satisfied)
                        .length,
                    maximum: entry.value.first.countGroupMax == 0
                        ? entry.value.length
                        : entry.value.first.countGroupMax,
                    onChanged: (value) {
                      final sorted = entry.value.toList()
                        ..sort((left, right) =>
                            left.id.compareTo(right.id));
                      for (var index = 0; index < sorted.length; index++) {
                        controller.setConditionState(
                          sorted[index].id,
                          index < value
                              ? TriState.satisfied
                              : TriState.notSatisfied,
                        );
                      }
                    },
                  ),
              ],
            ),
    );
  }

  String _groupTitle(List<ConditionOption> options) {
    return options.first.name.replaceAll(RegExp(r'（\d+件目）$'), '（契約数）');
  }
}

final class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.option,
    required this.value,
    required this.onChanged,
  });

  final ConditionOption option;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(option.name, style: theme.textTheme.titleMedium),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            if (option.description.isNotEmpty)
              Text(option.description, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

final class _CountGroupCard extends StatelessWidget {
  const _CountGroupCard({
    required this.title,
    required this.description,
    required this.count,
    required this.maximum,
    required this.onChanged,
  });

  final String title;
  final String description;
  final int count;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleMedium),
            if (description.isNotEmpty)
              Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: count > 0 ? () => onChanged(count - 1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$count 個', style: theme.textTheme.titleMedium),
                ),
                IconButton.filledTonal(
                  onPressed: count < maximum ? () => onChanged(count + 1) : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '1個につき+1.0%（最大$maximum個）',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
