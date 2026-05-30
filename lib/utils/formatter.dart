import 'package:intl/intl.dart';

class Fmt {
  static final _yen = NumberFormat('#,###', 'ja_JP');
  static String yen(num v) => '¥${_yen.format(v.round())}';
  static String yenSimple(num v) => _yen.format(v.round());
  static String pct(double v) => '${v.toStringAsFixed(1)}%';
  static String pctShort(double v) {
    if (v == v.roundToDouble()) return '${v.toInt()}%';
    return '${v.toStringAsFixed(1)}%';
  }
}
