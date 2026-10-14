import 'package:flutter/material.dart';

class DottedDivider extends StatelessWidget {
  final Color color;
  final bool notches;

  const DottedDivider({super.key, required this.color, this.notches = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(painter: _DottedPainter(color, notches)),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  final bool notches;
  _DottedPainter(this.color, this.notches);

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color.withValues(alpha: 0.9);
    const gap = 9.0;
    const radius = 1.6;
    final y = size.height / 2;
    for (double x = gap / 2; x < size.width; x += gap) {
      canvas.drawCircle(Offset(x, y), radius, dot);
    }
    if (notches) {
      final notch = Paint()..color = color;
      canvas.drawPath(
        Path()..moveTo(0, y - 4)..lineTo(4, y)..lineTo(0, y + 4)..close(),
        notch,
      );
      canvas.drawPath(
        Path()..moveTo(size.width, y - 4)..lineTo(size.width - 4, y)..lineTo(size.width, y + 4)..close(),
        notch,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.notches != notches;
}
