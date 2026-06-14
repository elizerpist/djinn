import 'package:flutter/material.dart';

class DraggableBottomCard extends StatefulWidget {
  const DraggableBottomCard({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dismissThreshold = 120,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final double dismissThreshold;

  @override
  State<DraggableBottomCard> createState() => _DraggableBottomCardState();
}

class _DraggableBottomCardState extends State<DraggableBottomCard> {
  double _dragOffset = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    final next = _dragOffset + details.delta.dy;
    setState(() => _dragOffset = next < 0 ? 0 : next);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > widget.dismissThreshold || velocity > 900) {
      widget.onDismiss();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('draggable-bottom-card'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
      child: AnimatedContainer(
        duration: _dragOffset == 0
            ? const Duration(milliseconds: 180)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: widget.child,
      ),
    );
  }
}
