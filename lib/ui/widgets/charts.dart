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

/// 棒グラフの1本（D-161）。
final class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final int value;

  /// 棒の下に出す補足（「還元 120円」など）。
  final String? detail;
}

/// グラフ用の色。カードや店舗に順番に割り当てる。
const List<Color> chartPalette = <Color>[
  Color(0xFF1F6F8B),
  Color(0xFF3FA7A0),
  Color(0xFF7FB069),
  Color(0xFFE0A458),
  Color(0xFFC86A6A),
  Color(0xFF7A6FB0),
  Color(0xFF4E8FD0),
  Color(0xFFB08968),
  Color(0xFF6A9E7F),
  Color(0xFFA96FA0),
];

Color chartColorAt(int index) => chartPalette[index % chartPalette.length];

/// 依存を増やさないための簡易円グラフ（D-161）。
final class SimplePieChart extends StatelessWidget {
  const SimplePieChart({
    super.key,
    required this.slices,
    this.size = 180,
    this.centerTitle,
    this.centerValue,
  });

  final List<PieSlice> slices;
  final double size;
  final String? centerTitle;
  final String? centerValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);

    if (total <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: Size.square(size),
                painter: _PiePainter(
                  slices: slices,
                  total: total,
                  surface: theme.colorScheme.surface,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (centerTitle != null)
                    Text(centerTitle!, style: theme.textTheme.labelSmall),
                  if (centerValue != null)
                    Text(
                      centerValue!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: <Widget>[
            for (final slice in slices)
              if (slice.value > 0)
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
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
          ],
        ),
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
    final rect = Offset.zero & size;
    final paint = Paint()..style = PaintingStyle.fill;
    var start = -math.pi / 2;

    for (final slice in slices) {
      if (slice.value <= 0) {
        continue;
      }

      final sweep = 2 * math.pi * (slice.value / total);
      paint.color = slice.color;
      canvas.drawArc(rect.deflate(2), start, sweep, true, paint);
      start += sweep;
    }

    // 真ん中をくり抜いてドーナツにする。
    final hole = Paint()..color = surface;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.28, hole);
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.slices != slices;
  }
}

/// 縦棒グラフ（月ごとの利用金額など・D-161）。
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
    final maxValue = data.fold<int>(0, (max, item) => math.max(max, item.value));

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
              labelStyle: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
              valueStyle: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
              axisColor: theme.colorScheme.outlineVariant,
              barColor: theme.colorScheme.primary,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '※ 棒の高さは利用金額です。タップすると月ごとの内訳を開けます。',
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
    required this.valueStyle,
    required this.axisColor,
    required this.barColor,
    required this.onSurface,
  });

  final List<BarDatum> data;
  final int maxValue;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final Color axisColor;
  final Color barColor;
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
      final barHeight = chartHeight * (item.value / maxValue);
      final rect = Rect.fromLTWH(
        centerX - barWidth / 2,
        size.height - bottom - barHeight,
        barWidth,
        barHeight,
      );

      final bar = Paint()..color = barColor;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        bar,
      );

      _text(canvas, item.label, Offset(centerX, size.height - bottom + 2),
          labelStyle, TextAlign.center, maxWidth: slot);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
    TextAlign align, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(color: onSurface)),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy),
    );
  }

  @override
  bool shouldRepaint(_ColumnPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}

/// 横棒グラフ（カード別・店舗別の比較・D-161）。
final class SimpleBarRows extends StatelessWidget {
  const SimpleBarRows({
    super.key,
    required this.data,
    this.valueSuffix = '円',
  });

  final List<BarDatum> data;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = data.fold<int>(0, (max, item) => math.max(max, item.value));

    if (data.isEmpty || maxValue <= 0) {
      return Text('データがありません。', style: theme.textTheme.bodySmall);
    }

    return Column(
      children: <Widget>[
        for (var index = 0; index < data.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 96,
                  child: Text(
                    data[index].label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (data[index].value / maxValue).clamp(0.0, 1.0),
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: chartColorAt(index),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${_group(data[index].value)}$valueSuffix',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (data[index].detail != null)
                        Text(
                          data[index].detail!,
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
