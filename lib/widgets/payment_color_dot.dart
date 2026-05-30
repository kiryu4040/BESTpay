import 'package:flutter/material.dart';

class PaymentColorDot extends StatelessWidget {
  final String hex;
  final double size;
  const PaymentColorDot({super.key, required this.hex, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _parse(hex),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }

  static Color _parse(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF1976D2);
  }
}
