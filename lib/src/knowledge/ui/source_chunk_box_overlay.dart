import 'package:flutter/material.dart';

import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';
import 'source_chunk_rect.dart';

enum SourceChunkBoxMode { hidden, ai, manual }

class SourceChunkBox {
  const SourceChunkBox({
    required this.chunkId,
    required this.rect,
    required this.mode,
    required this.label,
  });

  final String chunkId;
  final Rect rect;
  final SourceChunkBoxMode mode;
  final String label;
}

List<SourceChunkBox> sourceChunkBoxesFromItems(
  List<ExtractedKnowledgeItem> items, {
  required SourceChunkBoxMode mode,
  required int pageNumber,
  Size? pageSize,
}) {
  if (mode == SourceChunkBoxMode.hidden) {
    return const [];
  }
  return [
    for (final item in items)
      if (_matchesMode(item, mode) && item.pageNumber == pageNumber)
        if (sourceRectFromJson(item.sourceRectJson) case final sourceRect?)
          SourceChunkBox(
            chunkId: item.id,
            rect: sourceRect.pageRectForSize(pageSize ?? Size.zero),
            mode: mode,
            label: item.chunkKind.label,
          ),
  ];
}

bool _matchesMode(ExtractedKnowledgeItem item, SourceChunkBoxMode mode) {
  return switch (mode) {
    SourceChunkBoxMode.hidden => false,
    SourceChunkBoxMode.ai => item.pipeline == LocalExtractionPipeline.ai,
    SourceChunkBoxMode.manual => item.pipeline != LocalExtractionPipeline.ai,
  };
}

class SourceChunkBoxOverlay extends StatelessWidget {
  const SourceChunkBoxOverlay({
    super.key,
    required this.boxes,
    required this.onTapBox,
  });

  final List<SourceChunkBox> boxes;
  final ValueChanged<String> onTapBox;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _SourceChunkBoxPainter(boxes)),
          ),
        ),
        for (final box in boxes)
          Positioned.fromRect(
            rect: box.rect,
            child: InkWell(
              key: ValueKey('source-chunk-box-${box.chunkId}'),
              onTap: () => onTapBox(box.chunkId),
              child: Align(
                alignment: Alignment.topLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _colorFor(box.mode),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      box.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceChunkBoxPainter extends CustomPainter {
  const _SourceChunkBoxPainter(this.boxes);

  final List<SourceChunkBox> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final color = _colorFor(box.mode);
      final fill = Paint()..color = color.withValues(alpha: 0.10);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final rrect = RRect.fromRectAndRadius(box.rect, const Radius.circular(8));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SourceChunkBoxPainter oldDelegate) {
    return oldDelegate.boxes != boxes;
  }
}

Color _colorFor(SourceChunkBoxMode mode) {
  return switch (mode) {
    SourceChunkBoxMode.hidden => const Color(0xFF64748B),
    SourceChunkBoxMode.ai => const Color(0xFF2563EB),
    SourceChunkBoxMode.manual => const Color(0xFF059669),
  };
}
