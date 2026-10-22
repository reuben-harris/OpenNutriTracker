import 'dart:async';

import 'package:flutter/material.dart';

/// Keeps content mounted but hidden until loading and its minimum feedback
/// interval finish. Errors reveal the available content immediately.
class LoadingContent extends StatefulWidget {
  const LoadingContent({
    super.key,
    required this.isLoading,
    required this.semanticIdentifier,
    required this.child,
    this.hasError = false,
  });

  final bool isLoading;
  final bool hasError;
  final String semanticIdentifier;
  final Widget child;

  @override
  State<LoadingContent> createState() => _LoadingContentState();
}

class _LoadingContentState extends State<LoadingContent> {
  Timer? _minimumTimer;
  bool _showLoading = false;

  @override
  void initState() {
    super.initState();
    _updateLoading();
  }

  @override
  void didUpdateWidget(covariant LoadingContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateLoading();
  }

  void _updateLoading() {
    if (widget.hasError) {
      _minimumTimer?.cancel();
      _minimumTimer = null;
      _showLoading = false;
    } else if (widget.isLoading && !_showLoading) {
      _showLoading = true;
      _minimumTimer = Timer(const Duration(milliseconds: 500), () {
        _minimumTimer = null;
        if (!widget.isLoading) setState(() => _showLoading = false);
      });
    } else if (!widget.isLoading && _minimumTimer == null && _showLoading) {
      // Let the mounted content apply the final record and its derived
      // previews before revealing it on the following frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.isLoading && _minimumTimer == null) {
          setState(() => _showLoading = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Visibility(
        visible: !_showLoading,
        maintainState: true,
        child: widget.child,
      ),
      if (_showLoading)
        Center(
          child: Semantics(
            identifier: widget.semanticIdentifier,
            child: const CircularProgressIndicator(),
          ),
        ),
    ],
  );
}
