import 'package:flutter/material.dart';

/// Coordinates one open row across all sections on a screen.
class SwipeRevealScope extends StatefulWidget {
  final Widget child;
  final bool active;

  const SwipeRevealScope({super.key, required this.child, this.active = true});

  static SwipeRevealController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SwipeRevealScope>()
      ?.controller;

  @override
  State<SwipeRevealScope> createState() => _SwipeRevealScopeState();
}

class _SwipeRevealScopeState extends State<SwipeRevealScope> {
  final _controller = SwipeRevealController();

  @override
  void didUpdateWidget(SwipeRevealScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active) _controller.close();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.isCurrentOf(context) == false) _controller.close();
  }

  @override
  Widget build(BuildContext context) => _SwipeRevealScope(
    controller: _controller,
    child: NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) _controller.close();
        return false;
      },
      child: widget.child,
    ),
  );
}

class SwipeRevealController {
  VoidCallback? _close;

  void open(VoidCallback close) {
    if (_close == close) return;
    this.close();
    _close = close;
  }

  void release(VoidCallback close) {
    if (_close == close) _close = null;
  }

  void close() {
    final close = _close;
    _close = null;
    close?.call();
  }
}

class _SwipeRevealScope extends InheritedWidget {
  final SwipeRevealController controller;

  const _SwipeRevealScope({required this.controller, required super.child});

  @override
  bool updateShouldNotify(_SwipeRevealScope oldWidget) =>
      controller != oldWidget.controller;
}
