import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 円グラフの1片（D-161）。
final class PieSlice {
  const PieSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// 内訳画面で使う1項目（利用金額と還元金額の両方を持つ・D-167）。
final class BreakdownItem {
  const BreakdownItem({
    required this.label,
    required this.color,
    required this.spendYen,
    required this.rewardYen,
  });

  final String label;
  final Color color;
  final int spendYen;
  final int rewardYen;
}

/// 棒グラフの1本（D-161・D-163・D-167）。
final class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    this.reward = 0,
    this.detail,
    this.color,
    this.separated = false,
  });

  final String label;

  /// 利用金額（円）。
  final int value;

  /// 還元額（円）。グラフではオレンジで重ねて表示する（D-163）。
  final int reward;

  /// 棒の下に出す補足（「還元 120円」など）。
  final String? detail;

  /// 棒の色。null のときは [chartColorAt] が順番に割り当てる。
  final Color? color;

  /// グラフの最下部に分離して表示するか（「その他」用・D-167）。
  final bool separated;
}

/// グラフ用の色。カードや店舗に順番に割り当てる（D-163）。
///
/// 還元額のオレンジ（[rewardOrange]）と同化しないよう、オレンジ系・茶系は
/// 使わない。
const List<Color> chartPalette = <Color>[
  Color(0xFF1F6F8B),
  Color(0xFF3FA7A0),
  Color(0xFF7FB069),
  Color(0xFF4E8FD0),
  Color(0xFF7A6FB0),
  Color(0xFFC86A6A),
  Color(0xFFA96FA0),
  Color(0xFF5B8C5A),
  Color(0xFF3D6E9E),
  Color(0xFF8E7CC3),
];

Color chartColorAt(int index) => chartPalette[index % chartPalette.length];

/// 還元額を表す色。すべてのグラフでオレンジに統一する（D-163）。
const Color rewardOrange = Color(0xFFE07A1F);

/// グラフの凡例の1項目（D-163）。
final class ChartLegendItem {
  const ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;
}

/// グラフの凡例（D-163）。
final class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<ChartLegendItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: <Widget>[
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 4),
              Text(item.label, style: theme.textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

/// 依存を増やさないための簡易円グラフ（D-161・D-167）。
final class SimplePieChart extends StatelessWidget {
  const SimplePieChart({
    super.key,
    required this.slices,
    this.size = 180,
    this.centerTitle,
    this.centerValue,
    this.legendLimit,
    this.onTap,
    this.showLegend = true,
  });

  final List<PieSlice> slices;
  final double size;
  final String? centerTitle;
  final String? centerValue;

  /// 凡例に出す最大件数。null ならすべて表示する。
  final int? legendLimit;

  /// タップしたときの動作（別画面で全件を見る・D-167）。
  final VoidCallback? onTap;

  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);

    if (slices.isEmpty || total <= 0) {
      return Text('データがありません。', style: theme.textTheme.bodySmall);
    }

    final chart = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiePainter(
          slices: slices,
          total: total,
          surface: theme.colorScheme.surface,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (centerTitle != null)
                Text(centerTitle!, style: theme.textTheme.labelSmall),
              if (centerValue != null)
                Text(
                  centerValue!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final limit = legendLimit ?? slices.length;
    final shown = slices.take(limit).toList();

    return Column(
      children: <Widget>[
        if (onTap == null)
          chart
        else
          InkWell(
            borderRadius: BorderRadius.circular(size / 2),
            onTap: onTap,
            child: chart,
          ),
        if (showLegend) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (final slice in shown)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${slice.label} ${_group(slice.value)}円',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
        ],

      ],
    );
  }
}

final class _PiePainter extends CustomPainter {
  const _PiePainter({
    required this.slices,
    required this.total,
    required this.surface,
  });

  final List<PieSlice> slices;
  final int total;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    var start = -math.pi / 2;

    for (final slice in slices) {
      final sweep = 2 * math.pi * (slice.value / total);
      final paint = Paint()..color = slice.color;
      canvas.drawArc(rect.deflate(2), start, sweep, true, paint);
      start += sweep;
    }

    // 中心をくり抜いてドーナツにする。
    final hole = Paint()..color = surface;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.3, hole);
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.total != total;
  }
}

/// 縦棒グラフ（月ごとの利用金額・D-161・D-163）。
///
/// 棒の青緑が利用金額、根元（下側）に重ねたオレンジが還元額。
final class SimpleColumnChart extends StatelessWidget {
  const SimpleColumnChart({
    super.key,
    required this.data,
    this.height = 160,
    this.valueSuffix = '円',
  });

  final List<BarDatum> data;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.fold<int>(
      0,
      (max, item) => math.max(max, item.value),
    );
    final hasReward = data.any((item) => item.reward > 0);

    if (data.isEmpty || maxValue <= 0) {
      return Text('この年の利用はまだありません。', style: theme.textTheme.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: height,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ColumnPainter(
              data: data,
              maxValue: maxValue,
              labelStyle:
                  theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
              axisColor: theme.colorScheme.outlineVariant,
              barColor: theme.colorScheme.primary,
              rewardColor: rewardOrange,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ChartLegend(
          items: <ChartLegendItem>[
            ChartLegendItem(color: theme.colorScheme.primary, label: '利用金額'),
            if (hasReward)
              const ChartLegendItem(color: rewardOrange, label: '還元額'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '※ 棒の青緑が利用金額、その根元（下側）に重ねたオレンジが還元額です。'
          'オレンジの高さが、利用金額に対する還元の割合を表します。'
          '月の内訳は下の「月を選ぶ」から開けます。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

final class _ColumnPainter extends CustomPainter {
  const _ColumnPainter({
    required this.data,
    required this.maxValue,
    required this.labelStyle,
    required this.axisColor,
    required this.barColor,
    required this.rewardColor,
    required this.onSurface,
  });

  final List<BarDatum> data;
  final int maxValue;
  final TextStyle labelStyle;
  final Color axisColor;
  final Color barColor;
  final Color rewardColor;
  final Color onSurface;

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 18.0;
    const top = 16.0;
    final chartHeight = size.height - bottom - top;
    final slot = size.width / data.length;
    final barWidth = math.min(slot * 0.6, 26.0);

    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - bottom),
      Offset(size.width, size.height - bottom),
      axis,
    );

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final centerX = slot * index + slot / 2;
      final baseY = size.height - bottom;

      final spendHeight = chartHeight * (item.value / maxValue);

      final bar = Paint()..color = item.color ?? barColor;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centerX - barWidth / 2,
            baseY - spendHeight,
            barWidth,
            spendHeight,
          ),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        bar,
      );

      if (item.reward > 0) {
        // 還元額は棒の根元（下側）に重ね、利用金額に対する割合として見せる（D-164）。
        var rewardHeight = chartHeight * (item.reward / maxValue);
        if (rewardHeight < 2) {
          rewardHeight = 2;
        }
        if (rewardHeight > spendHeight) {
          rewardHeight = spendHeight;
        }

        final reward = Paint()..color = rewardColor;
        canvas.drawRect(
          Rect.fromLTWH(
            centerX - barWidth / 2,
            baseY - rewardHeight,
            barWidth,
            rewardHeight,
          ),
          reward,
        );
      }

      _text(
        canvas,
        item.label,
        Offset(centerX, size.height - bottom + 2),
        labelStyle,
        maxWidth: slot,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: onSurface)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_ColumnPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}

/// 横棒グラフ（カード別・店舗別の比較・D-161・D-163・D-167）。
///
/// 棒の色が利用金額、左端に重ねたオレンジが還元額。
/// [BarDatum.separated] を立てた行は、いったん区切ってグラフの最下部に表示する
/// （「その他」が大きいときに他の行が埋もれるのを防ぐ）。棒の長さは（分離行を
/// 除く）最大値を基準に、[maxBarRatio] までの長さに固定する。
final class SimpleBarRows extends StatelessWidget {
  const SimpleBarRows({
    super.key,
    required this.data,
    this.valueSuffix = '円',
    this.maxBarRatio = 1.0,
  });

  final List<BarDatum> data;
  final String valueSuffix;

  /// 最大値の棒が占める幅の割合（例 0.9 で 90%）。
  final double maxBarRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final main = data.where((item) => !item.separated).toList();
    final separated = data.where((item) => item.separated).toList();
    final maxValue = main.isEmpty
        ? 0
        : main.fold<int>(0, (max, item) => math.max(max, item.value));
    final hasReward = data.any((item) => item.reward > 0);

    if (data.isEmpty || (maxValue <= 0 && separated.isEmpty)) {
      return Text('データがありません。', style: theme.textTheme.bodySmall);
    }

    double ratioOf(int value) {
      if (maxValue <= 0) {
        return 1.0;
      }
      final raw = value / maxValue;
      return raw.clamp(0.0, 1.0) * maxBarRatio;
    }

    Widget row(int index, BarDatum item, Color color) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Text(
                item.label,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final spendWidth = width * ratioOf(item.value);
                  var rewardWidth = width * ratioOf(item.reward);
                  if (item.reward > 0 && rewardWidth < 2) {
                    rewardWidth = 2;
                  }
                  if (rewardWidth > spendWidth) {
                    rewardWidth = spendWidth;
                  }

                  return Stack(
                    children: <Widget>[
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: spendWidth,
                          height: 18,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      if (rewardWidth > 0)
                        // 還元額は棒の根元（左側）に重ねる（D-164）。
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: rewardWidth,
                            height: 18,
                            decoration: BoxDecoration(
                              color: rewardOrange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${_group(item.value)}$valueSuffix',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (item.reward > 0)
                    Text(
                      '還元 ${_group(item.reward)}$valueSuffix',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: rewardOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < main.length; index++)
          row(index, main[index], main[index].color ?? chartColorAt(index)),
        if (separated.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          for (final item in separated)
            row(
              main.length,
              item,
              item.color ?? theme.colorScheme.outline,
            ),
        ],
        const SizedBox(height: 6),
        if (hasReward)
          const ChartLegend(
            items: <ChartLegendItem>[
              ChartLegendItem(color: rewardOrange, label: '還元額（棒の左端のオレンジ）'),
            ],
          ),
      ],
    );
  }
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
