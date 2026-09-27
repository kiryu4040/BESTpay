import 'package:bestpay/core/time/clock.dart';

final class FixedClock implements Clock {
  FixedClock(DateTime instant) : _instant = instant.toUtc();

  final DateTime _instant;

  @override
  DateTime nowUtc() => _instant;
}
