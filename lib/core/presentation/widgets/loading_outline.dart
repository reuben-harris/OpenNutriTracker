import 'package:flutter/material.dart';

/// Two eased strokes chase around the outline, finishing each cycle before
/// stopping. Only errors interrupt a cycle; loading state remains independent.
class LoadingOutline extends StatefulWidget {
  const LoadingOutline({
    super.key,
    required this.isLoading,
    required this.color,
    required this.borderRadius,
    required this.semanticIdentifier,
    required this.builder,
    this.hasError = false,
  });

  final bool isLoading;
  final bool hasError;
  final Color color;
  final BorderRadius borderRadius;
  final String semanticIdentifier;
  final Widget Function(BuildContext context, bool isAnimating) builder;

  @override
  State<LoadingOutline> createState() => _LoadingOutlineState();
}

class _LoadingOutlineState extends State<LoadingOutline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onStatus);
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _syncLoading();
  }

  @override
  void didUpdateWidget(covariant LoadingOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoading();
  }

  void _syncLoading() {
    if (widget.hasError) {
      _controller.stop();
      _visible = false;
    } else if (widget.isLoading && !_visible) {
      _visible = true;
      _controller.forward(from: 0);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.isLoading && !widget.hasError) {
      _controller.forward(from: 0);
    } else {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.builder(context, _visible),
      if (_visible)
        Positioned.fill(
          child: IgnorePointer(
            child: Semantics(
              identifier: widget.semanticIdentifier,
              child: CustomPaint(
                foregroundPainter: _LoadingOutlinePainter(
                  animation: _controller,
                  color: widget.color,
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _LoadingOutlinePainter extends CustomPainter {
  _LoadingOutlinePainter({
    required this.animation,
    required this.color,
    required this.borderRadius,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.5;
    final outline = borderRadius
        .toRRect((Offset.zero & size).deflate(strokeWidth / 2))
        .scaleRadii();
    final path = Path()
      ..moveTo(outline.center.dx, outline.top)
      ..lineTo(outline.right - outline.trRadiusX, outline.top)
      ..arcToPoint(
        Offset(outline.right, outline.top + outline.trRadiusY),
        radius: outline.trRadius,
      )
      ..lineTo(outline.right, outline.bottom - outline.brRadiusY)
      ..arcToPoint(
        Offset(outline.right - outline.brRadiusX, outline.bottom),
        radius: outline.brRadius,
      )
      ..lineTo(outline.left + outline.blRadiusX, outline.bottom)
      ..arcToPoint(
        Offset(outline.left, outline.bottom - outline.blRadiusY),
        radius: outline.blRadius,
      )
      ..lineTo(outline.left, outline.top + outline.tlRadiusY)
      ..arcToPoint(
        Offset(outline.left + outline.tlRadiusX, outline.top),
        radius: outline.tlRadius,
      )
      ..close();
    final metric = path.computeMetrics().first;
    final half = metric.length / 2;
    // Offset the tail's easing so each stroke grows, accelerates around the
    // corners, then shrinks to nothing before the next cycle begins.
    final head = Curves.easeInOutCubic.transform(
      (animation.value / 0.8).clamp(0.0, 1.0),
    );
    final tail = Curves.easeInOutCubic.transform(
      ((animation.value - 0.2) / 0.8).clamp(0.0, 1.0),
    );
    if (head <= tail) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (final start in [0.0, half]) {
      canvas.drawPath(
        metric.extractPath(start + tail * half, start + head * half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoadingOutlinePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius;
}
