import 'dart:math' as math;
import 'package:flutter/material.dart';

const diaryCopyColor = Color(0xFF70BDF0);
const diaryCopyButtonColor = Color(0xFF0277BD);

class DiaryDottedBorder extends CustomPainter {
  final Color color;
  const DiaryDottedBorder(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(16),
        ),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 1.5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DiaryDottedBorder oldDelegate) =>
      oldDelegate.color != color;
}
