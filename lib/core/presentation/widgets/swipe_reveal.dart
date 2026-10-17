import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/swipe_reveal_scope.dart';

class SwipeRevealAction {
  final IconData icon;
  final String label;
  final String semanticsIdentifier;
  final VoidCallback onTap;
  final double revealThreshold;
  final double iconSize;
  final Color? color;
  final Color? foregroundColor;

  const SwipeRevealAction({
    required this.icon,
    required this.label,
    required this.semanticsIdentifier,
    required this.onTap,
    this.iconSize = 28,
    this.color,
    this.foregroundColor,
    this.revealThreshold = SwipeReveal.actionWidth / 2,
  }) : assert(
         revealThreshold >= 0 && revealThreshold <= SwipeReveal.actionWidth,
       );
}

/// Left actions reveal on a right swipe; right actions share a compact strip.
class SwipeReveal extends StatefulWidget {
  static const double actionWidth = 104;
  static const double flingThreshold = 250;
  static const settleDuration = Duration(milliseconds: 200);

  final Widget child;
  final SwipeRevealAction? leftAction;
  final List<SwipeRevealAction> rightActions;
  final double rightActionWidth;
  final double actionSpacing;
  final bool enabled;
  final Object? resetKey;
  final EdgeInsets actionInsets;
  final double actionRadius;

  const SwipeReveal({
    super.key,
    required this.child,
    this.leftAction,
    this.rightActions = const [],
    this.rightActionWidth = actionWidth,
    this.actionSpacing = 6,
    this.enabled = true,
    this.resetKey,
    this.actionInsets = EdgeInsets.zero,
    this.actionRadius = 0,
  }) : assert(rightActionWidth > 0),
       assert(actionSpacing >= 0);

  @override
  State<SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<SwipeReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  SwipeRevealController? _group;
  double _startOffset = 0;
  double _rightExtent = 0;
  double get _offset =>
      _slide.value *
      (_slide.value < 0 ? _rightExtent : SwipeReveal.actionWidth);

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      lowerBound: -1,
      upperBound: 1,
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
        (_offset < 0 &&
            (widget.rightActions.isEmpty ||
                oldWidget.rightActions.length != widget.rightActions.length))) {
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
    final closingThreshold = _startOffset > 0
        ? widget.leftAction?.revealThreshold
        : widget.rightActions.firstOrNull?.revealThreshold;
    if (_startOffset != 0 &&
        (velocity * _startOffset < 0 ||
            _startOffset.abs() - _offset.abs() >=
                (closingThreshold ?? SwipeReveal.actionWidth / 2))) {
      _settle(0);
    } else if (widget.leftAction != null &&
        (velocity > SwipeReveal.flingThreshold ||
            (velocity >= -SwipeReveal.flingThreshold &&
                _offset >= widget.leftAction!.revealThreshold))) {
      _settle(1);
    } else if (widget.rightActions.isNotEmpty &&
        (velocity < -SwipeReveal.flingThreshold ||
            (velocity <= SwipeReveal.flingThreshold &&
                _offset <=
                    -math.min(
                      widget.rightActions.first.revealThreshold,
                      _rightExtent,
                    )))) {
      _settle(-1);
    } else {
      _settle(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draggable =
        widget.enabled &&
        (widget.leftAction != null || widget.rightActions.isNotEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(
          0.0,
          constraints.maxWidth - widget.actionInsets.horizontal,
        );
        _rightExtent = widget.rightActions.isEmpty
            ? 0
            : math.min(
                widget.rightActions.length * widget.rightActionWidth +
                    (widget.rightActions.length - 1) * widget.actionSpacing,
                available,
              );
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
                    final next = (_offset + details.delta.dx).clamp(
                      -_rightExtent,
                      widget.leftAction == null ? 0.0 : SwipeReveal.actionWidth,
                    );
                    _slide.value = next == 0
                        ? 0
                        : next /
                              (next < 0
                                  ? _rightExtent
                                  : SwipeReveal.actionWidth);
                  },
            onHorizontalDragEnd: draggable ? _onDragEnd : null,
            onHorizontalDragCancel: draggable ? _close : null,
            child: ClipRect(
              child: Stack(
                children: [
                  if (_offset <= 0 && widget.rightActions.isNotEmpty)
                    _actions(context, widget.rightActions, left: false),
                  if (_offset >= 0 && widget.leftAction != null)
                    _actions(context, [widget.leftAction!], left: true),
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
      },
    );
  }

  Widget _actions(
    BuildContext context,
    List<SwipeRevealAction> actions, {
    required bool left,
  }) {
    final exposed =
        widget.enabled &&
        !_slide.isAnimating &&
        _slide.value == (left ? 1 : -1);
    final extent = left ? SwipeReveal.actionWidth : _rightExtent;
    final spacing = math.min(widget.actionSpacing, extent / actions.length);
    return Positioned(
      left: left ? widget.actionInsets.left : null,
      right: left ? null : widget.actionInsets.right,
      top: widget.actionInsets.top,
      bottom: widget.actionInsets.bottom,
      width: extent,
      child: IgnorePointer(
        ignoring: !exposed,
        child: ExcludeSemantics(
          excluding: !exposed,
          child: Row(
            // Swipe directions and action order stay physical in RTL layouts.
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: _actionButton(context, actions[i], exposed)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    SwipeRevealAction action,
    bool exposed,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = action.foregroundColor ?? scheme.onPrimary;
    return Semantics(
      identifier: action.semanticsIdentifier,
      label: action.label,
      child: Tooltip(
        message: action.label,
        excludeFromSemantics: true,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: action.color ?? scheme.primary,
            foregroundColor: foreground,
            disabledForegroundColor: foreground,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.actionRadius),
            ),
          ),
          onPressed: !exposed
              ? null
              : () {
                  _reset();
                  action.onTap();
                },
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: action.iconSize),
                const SizedBox(height: 2),
                Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
