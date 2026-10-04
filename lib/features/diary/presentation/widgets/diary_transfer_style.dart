import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

const diaryCopyColor = Color(0xFF70BDF0);
const diaryCopyButtonColor = Color(0xFF0277BD);

BoxDecoration diaryTransferDecoration(
  Color color, {
  Color foreground = Colors.white,
  bool hovering = false,
}) {
  return BoxDecoration(
    // Material's hover state layer uses the content color at 8% opacity.
    // Keep the original drag target's solid fill and contrasting content.
    color: hovering
        ? Color.alphaBlend(foreground.withValues(alpha: 0.08), color)
        : color,
    borderRadius: Dimens.borderRadiusL,
  );
}

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
