import 'package:flutter/material.dart';

class InlineBottomSheetCard extends StatefulWidget {
  const InlineBottomSheetCard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissThreshold = 96,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final double dismissThreshold;

  @override
  State<InlineBottomSheetCard> createState() => _InlineBottomSheetCardState();
}

class _InlineBottomSheetCardState extends State<InlineBottomSheetCard> {
  double _dragOffset = 0;
  Offset? _dragStart;
  double _lastPrimaryVelocity = 0;

  void _handlePointerDown(PointerDownEvent event) {
    _dragStart = event.position;
    _lastPrimaryVelocity = 0;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _dragStart;
    if (start == null) {
      return;
    }
    final delta = event.position - start;
    if (delta.dy <= 0 || delta.dy.abs() < delta.dx.abs()) {
      return;
    }
    setState(() {
      _dragOffset = delta.dy.clamp(0, double.infinity);
    });
    _lastPrimaryVelocity = event.delta.dy;
  }

  void _handlePointerUp(PointerUpEvent event) {
    _finishDrag();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _finishDrag();
  }

  void _finishDrag() {
    _dragStart = null;
    final velocity = _lastPrimaryVelocity * 60;
    if (_dragOffset >= widget.dismissThreshold || velocity > 700) {
      widget.onDismiss();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      key: const ValueKey('inline-bottom-sheet-card'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedSlide(
        duration: _dragOffset == 0
            ? const Duration(milliseconds: 160)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        offset: Offset(0, _dragOffset / MediaQuery.sizeOf(context).height),
        child: widget.child,
      ),
    );
  }
}
