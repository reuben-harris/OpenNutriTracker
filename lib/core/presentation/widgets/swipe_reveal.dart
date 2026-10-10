import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';

class SwipeRevealAction {
  final IconData icon;
  final String label;
  final String semanticsIdentifier;
  final VoidCallback onTap;
  final double revealThreshold;

  const SwipeRevealAction({
    required this.icon,
    required this.label,
    required this.semanticsIdentifier,
    required this.onTap,
    this.revealThreshold = SwipeReveal.actionWidth / 2,
  }) : assert(
         revealThreshold >= 0 && revealThreshold <= SwipeReveal.actionWidth,
       );
}

/// One action on either side of a row. Left actions reveal on a right swipe.
class SwipeReveal extends StatefulWidget {
  static const double actionWidth = 104;
  static const double flingThreshold = 250;
  static const settleDuration = Duration(milliseconds: 200);

  final Widget child;
  final SwipeRevealAction? leftAction;
  final SwipeRevealAction? rightAction;
  final bool enabled;
  final Object? resetKey;
  final EdgeInsets actionInsets;
  final double actionRadius;

  const SwipeReveal({
    super.key,
    required this.child,
    this.leftAction,
    this.rightAction,
    this.enabled = true,
    this.resetKey,
    this.actionInsets = EdgeInsets.zero,
    this.actionRadius = 0,
  });

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  SwipeRevealController? _group;
  double _startOffset = 0;
  double get _offset => _slide.value;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      lowerBound: -SwipeReveal.actionWidth,
      upperBound: SwipeReveal.actionWidth,
      value: 0,
      duration: SwipeReveal.settleDuration,
    )..addListener(_onSlide);
  }

  void _onSlide() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = SwipeRevealScope.maybeOf(context);
    if (group != _group) {
      _reset();
      _group = group;
    }
  }

  @override
  void didUpdateWidget(SwipeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey ||
        !widget.enabled ||
        (_offset > 0 && widget.leftAction == null) ||
        (_offset < 0 && widget.rightAction == null)) {
      _reset();
    }
  }

  void _reset() {
    _group?.release(_close);
    _slide.stop();
    _slide.value = 0;
  }

  @override
  void dispose() {
    _group?.release(_close);
    _slide.dispose();
    super.dispose();
  }

  void _settle(double target) {
    if (target == 0) _group?.release(_close);
    if (MediaQuery.disableAnimationsOf(context)) {
      _slide.value = target;
    } else {
      _slide.animateTo(
        target,
        duration: SwipeReveal.settleDuration,
        curve: Curves.easeOut,
      );
    }
  }

  void _close() {
    if (_offset != 0 || _slide.isAnimating) _settle(0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_startOffset != 0 && velocity * _startOffset < 0) {
      _settle(0);
    } else if (widget.leftAction != null &&
        (velocity > SwipeReveal.flingThreshold ||
            (velocity >= -SwipeReveal.flingThreshold &&
                _offset >= widget.leftAction!.revealThreshold))) {
      _settle(SwipeReveal.actionWidth);
    } else if (widget.rightAction != null &&
        (velocity < -SwipeReveal.flingThreshold ||
            (velocity <= SwipeReveal.flingThreshold &&
                _offset <= -widget.rightAction!.revealThreshold))) {
      _settle(-SwipeReveal.actionWidth);
    } else {
      _settle(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draggable =
        widget.enabled &&
        (widget.leftAction != null || widget.rightAction != null);
    return TapRegion(
      onTapOutside: (_) => _close(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: !draggable
            ? null
            : (_) {
                _startOffset = _offset;
                _slide.stop();
                _group?.open(_close);
              },
        onHorizontalDragUpdate: !draggable
            ? null
            : (details) {
                _slide.value = (_offset + details.delta.dx).clamp(
                  widget.rightAction == null ? 0.0 : -SwipeReveal.actionWidth,
                  widget.leftAction == null ? 0.0 : SwipeReveal.actionWidth,
                );
              },
        onHorizontalDragEnd: draggable ? _onDragEnd : null,
        onHorizontalDragCancel: draggable ? _close : null,
        child: ClipRect(
          child: Stack(
            children: [
              if (_offset <= 0 && widget.rightAction != null)
                _action(context, widget.rightAction!, left: false),
              if (_offset >= 0 && widget.leftAction != null)
                _action(context, widget.leftAction!, left: true),
              Transform.translate(
                offset: Offset(_offset, 0),
                child: GestureDetector(
                  onTap: widget.enabled && _offset != 0 ? _close : null,
                  child: AbsorbPointer(
                    absorbing: !widget.enabled || _offset != 0,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    SwipeRevealAction action, {
    required bool left,
  }) {
    final exposed =
        widget.enabled &&
        !_slide.isAnimating &&
        _offset == (left ? SwipeReveal.actionWidth : -SwipeReveal.actionWidth);
    final radius = BorderRadius.circular(widget.actionRadius);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: left ? widget.actionInsets.left : null,
      right: left ? null : widget.actionInsets.right,
      top: widget.actionInsets.top,
      bottom: widget.actionInsets.bottom,
      width: SwipeReveal.actionWidth,
      child: IgnorePointer(
        ignoring: !exposed,
        child: ExcludeSemantics(
          excluding: !exposed,
          child: Semantics(
            identifier: action.semanticsIdentifier,
            child: Material(
              color: scheme.primary,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: !exposed
                    ? null
                    : () {
                        _reset();
                        action.onTap();
                      },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, size: 28, color: scheme.onPrimary),
                    const SizedBox(height: 2),
                    Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: scheme.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
