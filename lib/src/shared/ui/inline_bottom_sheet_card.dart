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

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0, double.infinity);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset >= widget.dismissThreshold || velocity > 700) {
      widget.onDismiss();
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('inline-bottom-sheet-card'),
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _handleDragUpdate,
      onVerticalDragEnd: _handleDragEnd,
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
