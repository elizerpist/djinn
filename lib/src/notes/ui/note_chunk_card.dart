import 'package:flutter/material.dart';

import '../../flowchart/ui/mobile_flowchart_viewer.dart';
import '../../shared/chunks/shared_chunk.dart';
import '../../shared/chunks/shared_chunk_card.dart';
import '../models/note_document.dart';

class NoteChunkCard extends StatelessWidget {
  const NoteChunkCard({
    super.key,
    required this.block,
    required this.expanded,
    required this.dragHandle,
    required this.onToggleExpanded,
    required this.onOpenEditor,
    required this.onDelete,
    this.inheritedTags = const [],
    this.onEditTags,
  });

  final NoteBlock block;
  final bool expanded;
  final Widget dragHandle;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenEditor;
  final VoidCallback onDelete;
  final List<NoteKnowledgeTag> inheritedTags;
  final VoidCallback? onEditTags;

  @override
  Widget build(BuildContext context) {
    return SharedChunkCard(
      id: block.id,
      keyPrefix: 'note-chunk-card',
      kind: sharedKindFromNoteBlockType(block.type),
      title: _titleFor(block),
      expanded: expanded,
      statusChips: _statusChips(),
      leading: dragHandle,
      actions: [
        if (onEditTags != null)
          IconButton(
            key: ValueKey('note-chunk-tags-${block.id}'),
            tooltip: 'Chunk tagek',
            onPressed: onEditTags,
            icon: const Icon(Icons.sell_outlined),
          ),
        IconButton(
          key: ValueKey('note-chunk-delete-${block.id}'),
          tooltip: 'Chunk törlése',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      expandedBodyKey: ValueKey(
        'note-chunk-expanded-body-${block.type.wireName}',
      ),
      expandedPadding: block.type == NoteBlockType.flowchart
          ? const EdgeInsets.fromLTRB(8, 10, 8, 2)
          : const EdgeInsets.fromLTRB(46, 10, 8, 2),
      expandedBody: _ChunkBody(block: block),
      onToggleExpanded: onToggleExpanded,
      onOpenEditor: onOpenEditor,
    );
  }

  List<SharedChunkStatusChip> _statusChips() {
    final chips = <SharedChunkStatusChip>[];
    if (block.hasContent) {
      chips.add(
        const SharedChunkStatusChip(
          label: 'Kinyerve',
          color: Color(0xFF059669),
        ),
      );
    }
    if (block.isIndexFresh) {
      chips.add(
        const SharedChunkStatusChip(
          label: 'Indexelve',
          color: Color(0xFF2563EB),
        ),
      );
    } else if (block.needsReindex) {
      chips.add(
        const SharedChunkStatusChip(
          label: 'Újraindexelendő',
          color: Color(0xFFD97706),
        ),
      );
    }
    for (final tag in block.tags) {
      final label = _tagLabel('Tag', tag);
      if (label != null) {
        chips.add(
          SharedChunkStatusChip(
            label: label,
            color: Color(tag.resolvedColorValue),
          ),
        );
      }
    }
    for (final rangeTag in block.rangeTags) {
      final label = _tagLabel('Részlet tag', rangeTag.tag);
      if (label != null) {
        chips.add(
          SharedChunkStatusChip(
            label: label,
            color: Color(rangeTag.tag.resolvedColorValue),
          ),
        );
      }
    }
    final directTagKeys = {
      for (final tag in block.tags)
        '${NoteKnowledgeTagTypes.normalize(tag.type)}:${tag.label.trim().toLowerCase()}',
    };
    for (final tag in inheritedTags) {
      final key =
          '${NoteKnowledgeTagTypes.normalize(tag.type)}:${tag.label.trim().toLowerCase()}';
      if (!directTagKeys.contains(key)) {
        final label = _tagLabel('Örökölt tag', tag);
        if (label != null) {
          chips.add(
            SharedChunkStatusChip(
              label: label,
              color: Color(tag.resolvedColorValue),
            ),
          );
        }
      }
    }
    if (chips.isEmpty) {
      chips.add(
        const SharedChunkStatusChip(label: 'Üres', color: Color(0xFF6B7280)),
      );
    }
    return chips;
  }

  String? _tagLabel(String prefix, NoteKnowledgeTag tag) {
    final label = tag.label.trim();
    if (label.isEmpty) {
      return null;
    }
    return '$prefix: ${NoteKnowledgeTagTypes.normalize(tag.type)} $label';
  }

  String _titleFor(NoteBlock block) {
    final explicit = block.title?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return switch (block.type) {
      NoteBlockType.heading => 'Címsor chunk',
      NoteBlockType.paragraph => 'Szöveg chunk',
      NoteBlockType.listItem => 'Lista chunk',
      NoteBlockType.table => 'Táblázat chunk',
      NoteBlockType.flowchart => 'Flowchart chunk',
    };
  }
}

class _ChunkBody extends StatelessWidget {
  const _ChunkBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      NoteBlockType.table => _TableBody(block: block),
      NoteBlockType.flowchart => _FlowchartBody(block: block),
      NoteBlockType.listItem => _ListBody(block: block),
      NoteBlockType.heading ||
      NoteBlockType.paragraph => _ParagraphBody(block: block),
    };
  }
}

class _ParagraphBody extends StatelessWidget {
  const _ParagraphBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final text = block.text;
    if (text.trim().isEmpty) {
      return const _EmptyBody();
    }
    final style = TextStyle(
      fontSize: block.type == NoteBlockType.heading ? 18 : 14,
      fontWeight: block.type == NoteBlockType.heading
          ? FontWeight.w800
          : FontWeight.w500,
      color: const Color(0xFF111827),
      height: 1.35,
    );
    if (block.rangeTags.isEmpty) {
      return SelectableText(text.trim(), style: style);
    }
    return SelectableText.rich(_taggedTextSpan(text, block.rangeTags, style));
  }
}

TextSpan _taggedTextSpan(
  String text,
  List<NoteTextRangeTag> rangeTags,
  TextStyle style,
) {
  final validTags =
      rangeTags
          .map((tag) => tag.clampToTextLength(text.length))
          .where((tag) => tag.isValid)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  if (validTags.isEmpty) {
    return TextSpan(style: style, text: text.trim());
  }
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final rangeTag in validTags) {
    if (rangeTag.start < cursor) {
      continue;
    }
    if (rangeTag.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, rangeTag.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(rangeTag.start, rangeTag.end),
        style: TextStyle(
          backgroundColor: Color(
            rangeTag.tag.resolvedColorValue,
          ).withValues(alpha: 0.22),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    cursor = rangeTag.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: style, children: spans);
}

class _ListBody extends StatelessWidget {
  const _ListBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final items = block.listItems;
    if (items.isEmpty) {
      final text = block.text.trim();
      if (text.isEmpty) {
        return const _EmptyBody();
      }
      return SelectableText(text);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          if (item.text.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: 18.0 * item.level.clamp(0, 8).toDouble(),
                bottom: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.checked
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      item.text.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _TableBody extends StatelessWidget {
  const _TableBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final rows = block.rows
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
    if (rows.isEmpty) {
      return const _EmptyBody();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: Color(0xFFE5E7EB)),
            verticalInside: BorderSide(color: Color(0xFFE5E7EB)),
          ),
          children: [
            for (var i = 0; i < rows.length; i += 1)
              TableRow(
                decoration: BoxDecoration(
                  color: i == 0 ? const Color(0xFFF9FAFB) : Colors.white,
                ),
                children: [
                  for (final cell in rows[i])
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: SelectableText(
                        cell.trim().isEmpty ? ' ' : cell.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == 0
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FlowchartBody extends StatelessWidget {
  const _FlowchartBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.nodes.isEmpty && block.text.trim().isEmpty) {
      return const _EmptyBody();
    }
    if (block.nodes.isEmpty) {
      return SelectableText(block.text.trim());
    }
    return MobileFlowchartViewer(data: _mobileFlowchartDataFromBlock(block));
  }
}

MobileFlowchartData _mobileFlowchartDataFromBlock(NoteBlock block) {
  final nodes = [...block.nodes]..sort((a, b) => a.order.compareTo(b.order));
  final edges = [...block.edges]..sort((a, b) => a.order.compareTo(b.order));
  return MobileFlowchartData(
    id: block.id,
    title: block.title?.trim().isNotEmpty == true
        ? block.title!.trim()
        : 'Flowchart',
    nodes: [
      for (final node in nodes)
        MobileFlowchartNode(
          id: node.id,
          label: node.label,
          shape: node.shape.wireName,
          kind: node.kind.wireName,
          role: node.role.wireName,
          visualShape: NoteFlowchartVisualShape.rectangle.wireName,
          order: node.order,
          x: node.x,
          y: node.y,
          ports: [
            for (final port in node.ports)
              MobileFlowchartPort(
                id: port.id,
                side: port.side.wireName,
                label: port.label,
                semantic: port.semantic.wireName,
              ),
          ],
        ),
    ],
    edges: [
      for (final edge in edges)
        MobileFlowchartEdge(
          id: edge.id,
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          label: edge.label,
          fromPortId: edge.fromPortId,
          toPortId: edge.toPortId,
          routingMode: edge.routingMode.wireName,
          manualWaypoints: [
            for (final point in edge.manualWaypoints)
              MobileFlowchartWaypoint(point.x, point.y),
          ],
          order: edge.order,
        ),
    ],
  );
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Üres chunk',
      style: TextStyle(color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
    );
  }
}
