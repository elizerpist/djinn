import 'package:flutter/material.dart';

class SharedChunkDragHandle extends StatelessWidget {
  const SharedChunkDragHandle({
    super.key,
    required this.chunkId,
    required this.index,
  });

  final String chunkId;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: SizedBox.square(
        key: ValueKey('shared-chunk-drag-$chunkId'),
        dimension: 36,
        child: const Icon(
          Icons.drag_indicator,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
