import 'package:flutter/material.dart';

import '../../flowchart/ui/mobile_flowchart_viewer.dart';
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
  });

  final NoteBlock block;
  final bool expanded;
  final Widget dragHandle;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenEditor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(block.type);
    return DecoratedBox(
      key: ValueKey('note-chunk-card-${block.id}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onOpenEditor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox.square(dimension: 36, child: Center(child: dragHandle)),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_iconFor(block.type), color: accent, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleFor(block),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: _statusChips(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('note-chunk-delete-${block.id}'),
                      tooltip: 'Chunk törlése',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                    IconButton(
                      tooltip: expanded ? 'Összecsukás' : 'Kinyitás',
                      onPressed: onToggleExpanded,
                      icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.fromLTRB(46, 10, 8, 2),
                    child: _ChunkBody(block: block),
                  ),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 160),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _statusChips() {
    final chips = <Widget>[];
    if (block.hasContent) {
      chips.add(const _StatusChip(label: 'Kinyerve', color: Color(0xFF059669)));
    }
    if (block.isIndexFresh) {
      chips.add(const _StatusChip(label: 'Indexelve', color: Color(0xFF2563EB)));
    } else if (block.needsReindex) {
      chips.add(const _StatusChip(label: 'Újraindexelendő', color: Color(0xFFD97706)));
    }
    if (chips.isEmpty) {
      chips.add(const _StatusChip(label: 'Üres', color: Color(0xFF6B7280)));
    }
    return chips;
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

  Color _accentFor(NoteBlockType type) {
    return switch (type) {
      NoteBlockType.heading => const Color(0xFF7C3AED),
      NoteBlockType.paragraph => const Color(0xFF2563EB),
      NoteBlockType.listItem => const Color(0xFF059669),
      NoteBlockType.table => const Color(0xFFEA580C),
      NoteBlockType.flowchart => const Color(0xFF9333EA),
    };
  }

  IconData _iconFor(NoteBlockType type) {
    return switch (type) {
      NoteBlockType.heading => Icons.title,
      NoteBlockType.paragraph => Icons.notes_outlined,
      NoteBlockType.listItem => Icons.checklist_outlined,
      NoteBlockType.table => Icons.table_chart_outlined,
      NoteBlockType.flowchart => Icons.account_tree_outlined,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
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
      NoteBlockType.heading || NoteBlockType.paragraph => _ParagraphBody(block: block),
    };
  }
}

class _ParagraphBody extends StatelessWidget {
  const _ParagraphBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final text = block.text.trim();
    if (text.isEmpty) {
      return const _EmptyBody();
    }
    return SelectableText(
      text,
      style: TextStyle(
        fontSize: block.type == NoteBlockType.heading ? 18 : 14,
        fontWeight: block.type == NoteBlockType.heading ? FontWeight.w800 : FontWeight.w500,
        color: const Color(0xFF111827),
        height: 1.35,
      ),
    );
  }
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
              padding: EdgeInsets.only(left: 18.0 * item.level.clamp(0, 8).toDouble(), bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.checked ? Icons.check_box : Icons.check_box_outline_blank,
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
    final rows = block.rows.where((row) => row.any((cell) => cell.trim().isNotEmpty)).toList();
    if (rows.isEmpty) {
      return const _EmptyBody();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB))),
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
                          fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
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
    title: block.title?.trim().isNotEmpty == true ? block.title!.trim() : 'Flowchart',
    nodes: [
      for (final node in nodes)
        MobileFlowchartNode(
          id: node.id,
          label: node.label,
          shape: node.shape.wireName,
          x: node.x,
          y: node.y,
        ),
    ],
    edges: [
      for (final edge in edges)
        MobileFlowchartEdge(
          id: edge.id,
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          label: edge.label,
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
