import 'package:flutter/material.dart';

import '../../flowchart/ui/mobile_flowchart_viewer.dart';
import '../../shared/chunks/shared_chunk.dart';
import '../../shared/chunks/shared_chunk_card.dart';
import '../models/note_document.dart';
import 'tagged_text_visual.dart';

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
    final tags = _resolvedTags();
    return SharedChunkCard(
      id: block.id,
      keyPrefix: 'note-chunk-card',
      kind: sharedKindFromNoteBlockType(block.type),
      title: _titleFor(block),
      expanded: expanded,
      statusChips: _statusChips(),
      tagCount: tags.length,
      tagBadgeColor: tags.isEmpty ? null : Color(tags.first.resolvedColorValue),
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
      expandedBody: NoteChunkBody(block: block),
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
    if (chips.isEmpty) {
      chips.add(
        const SharedChunkStatusChip(label: 'Üres', color: Color(0xFF6B7280)),
      );
    }
    return chips;
  }

  List<NoteKnowledgeTag> _resolvedTags() {
    final byMetadata = <String, NoteKnowledgeTag>{};
    for (final tag in [...block.knownTags, ...inheritedTags]) {
      final key = tag.metadataText.trim().toLowerCase();
      if (key.isNotEmpty) {
        byMetadata[key] = tag;
      }
    }
    final tags = byMetadata.values.toList(growable: false);
    tags.sort((left, right) => left.metadataText.compareTo(right.metadataText));
    return tags;
  }

  String _titleFor(NoteBlock block) {
    final explicit = block.title?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return switch (block.type) {
      NoteBlockType.heading ||
      NoteBlockType.paragraph ||
      NoteBlockType.mixed ||
      NoteBlockType.listItem ||
      NoteBlockType.table => 'Jegyzetchunk',
      NoteBlockType.flowchart => 'Flowchart chunk',
    };
  }
}

/// Canonical read-only chunk renderer shared by Note and PDF scopes.
class NoteChunkBody extends StatelessWidget {
  const NoteChunkBody({super.key, required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      NoteBlockType.table => _TableBody(block: block),
      NoteBlockType.flowchart => _FlowchartBody(block: block),
      NoteBlockType.listItem => _ListBody(block: block),
      NoteBlockType.heading ||
      NoteBlockType.paragraph => _ParagraphBody(block: block),
      NoteBlockType.mixed => _MixedBody(block: block),
    };
  }
}

class _ParagraphBody extends StatelessWidget {
  const _ParagraphBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final text = block.type == NoteBlockType.mixed
        ? block.plainText
        : block.text;
    if (text.trim().isEmpty) {
      return const _EmptyBody();
    }
    final displayText = text.trim().isEmpty ? '' : text;
    final style = TextStyle(
      fontSize: block.type == NoteBlockType.heading ? 18 : 14,
      fontWeight: block.type == NoteBlockType.heading
          ? FontWeight.w800
          : FontWeight.w500,
      color: const Color(0xFF111827),
      height: 1.35,
    );
    if (block.textFills.isEmpty) {
      return SelectableText(displayText, style: style);
    }
    return SelectableText.rich(
      noteTextFillEditableTextSpan(
        text: displayText,
        fills: block.textFills,
        baseStyle: style,
      ),
    );
  }
}

class _MixedBody extends StatelessWidget {
  const _MixedBody({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.mixedSections.isEmpty) {
      return _ParagraphBody(block: block);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in block.mixedSections)
          Padding(
            key: ValueKey('unified-mixed-section-${section.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: switch (section.type) {
              NoteMixedSectionType.paragraph => _MixedParagraphBody(
                section: section,
              ),
              NoteMixedSectionType.list => _MixedListBody(section: section),
              NoteMixedSectionType.table => _MixedTableBody(section: section),
            },
          ),
      ],
    );
  }
}

class _MixedParagraphBody extends StatelessWidget {
  const _MixedParagraphBody({required this.section});

  final NoteMixedSection section;

  @override
  Widget build(BuildContext context) {
    final text = section.text;
    if (text.trim().isEmpty) {
      return const _EmptyBody();
    }
    final isHeading = section.paragraphRole == NoteMixedParagraphRole.heading;
    final headingLevel = section.headingLevel.clamp(1, 3).toInt();
    final style = TextStyle(
      color: section.textColorValue == null
          ? const Color(0xFF111827)
          : Color(section.textColorValue!),
      backgroundColor: section.backgroundColorValue == null
          ? null
          : Color(section.backgroundColorValue!),
      fontSize: isHeading
          ? switch (headingLevel) {
              1 => 22,
              2 => 19,
              _ => 17,
            }
          : 14,
      height: isHeading ? 1.25 : 1.35,
      fontWeight: isHeading ? FontWeight.w800 : FontWeight.w500,
      decoration: section.underlineColorValue == null
          ? TextDecoration.none
          : TextDecoration.underline,
      decorationColor: section.underlineColorValue == null
          ? null
          : Color(section.underlineColorValue!),
    );
    return Padding(
      padding: EdgeInsets.only(left: section.paragraphIndentLevel * 18.0),
      child: _filledSelectableText(
        key: ValueKey('unified-mixed-paragraph-${section.id}'),
        text: text,
        fills: _fillsFor(section, 'paragraph'),
        style: style,
      ),
    );
  }
}

class _MixedListBody extends StatelessWidget {
  const _MixedListBody({required this.section});

  final NoteMixedSection section;

  @override
  Widget build(BuildContext context) {
    if (section.listItems.isEmpty) {
      return _filledSelectableText(
        text: section.text,
        fills: _fillsFor(section, 'paragraph'),
        style: _mixedSectionTextStyle(section),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title?.trim().isNotEmpty == true)
          _SectionTitle(section.title!.trim()),
        for (var index = 0; index < section.listItems.length; index += 1)
          if (section.listItems[index].text.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left:
                    18.0 *
                    section.listItems[index].level.clamp(0, 8).toDouble(),
                bottom: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    section.listItems[index].checked
                        ? Icons.check_box
                        : section.listLayoutMode == NoteListLayoutMode.checkbox
                        ? Icons.check_box_outline_blank
                        : Icons.circle,
                    size: section.listLayoutMode == NoteListLayoutMode.checkbox
                        ? 18
                        : 7,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filledSelectableText(
                      key: ValueKey(
                        'unified-mixed-list-${section.id}-'
                        '${section.listItems[index].id}',
                      ),
                      text: section.listItems[index].text,
                      fills: _fillsFor(
                        section,
                        'list:${section.listItems[index].id}',
                      ),
                      style: _mixedSectionTextStyle(section),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _MixedTableBody extends StatelessWidget {
  const _MixedTableBody({required this.section});

  final NoteMixedSection section;

  @override
  Widget build(BuildContext context) {
    final rows = section.rows;
    if (rows.isEmpty ||
        rows.every((row) => row.every((cell) => cell.trim().isEmpty))) {
      return const _EmptyBody();
    }
    final columnCount = rows.fold<int>(
      0,
      (maximum, row) => row.length > maximum ? row.length : maximum,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title?.trim().isNotEmpty == true)
          _SectionTitle(section.title!.trim()),
        ClipRRect(
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
                for (var row = 0; row < rows.length; row += 1)
                  TableRow(
                    decoration: BoxDecoration(
                      color: row == 0 ? const Color(0xFFF9FAFB) : Colors.white,
                    ),
                    children: [
                      for (var column = 0; column < columnCount; column += 1)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _filledSelectableText(
                            key: ValueKey(
                              'unified-mixed-table-${section.id}-$row-$column',
                            ),
                            text: column < rows[row].length
                                ? rows[row][column]
                                : '',
                            fills: _fillsFor(section, 'table:$row:$column'),
                            style: _mixedSectionTextStyle(section).copyWith(
                              fontSize: 12,
                              fontWeight: row == 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

TextStyle _mixedSectionTextStyle(NoteMixedSection section) {
  return TextStyle(
    color: section.textColorValue == null
        ? const Color(0xFF111827)
        : Color(section.textColorValue!),
    backgroundColor: section.backgroundColorValue == null
        ? null
        : Color(section.backgroundColorValue!),
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w500,
    decoration: section.underlineColorValue == null
        ? TextDecoration.none
        : TextDecoration.underline,
    decorationColor: section.underlineColorValue == null
        ? null
        : Color(section.underlineColorValue!),
  );
}

List<NoteTextFill> _fillsFor(NoteMixedSection section, String targetKey) {
  return section.textFills
      .where(
        (fill) =>
            fill.targetKey == targetKey ||
            (fill.targetKey == null && targetKey == 'paragraph'),
      )
      .toList(growable: false);
}

Widget _filledSelectableText({
  Key? key,
  required String text,
  required List<NoteTextFill> fills,
  required TextStyle style,
}) {
  if (fills.isEmpty) {
    return SelectableText(text, key: key, style: style);
  }
  return SelectableText.rich(
    key: key,
    noteTextFillEditableTextSpan(text: text, fills: fills, baseStyle: style),
  );
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
          labelFills: [
            for (final fill in node.labelFills)
              MobileFlowchartTextFill(
                start: fill.start,
                end: fill.end,
                colorValue: fill.colorValue,
              ),
          ],
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
          labelFills: [
            for (final fill in edge.labelFills)
              MobileFlowchartTextFill(
                start: fill.start,
                end: fill.end,
                colorValue: fill.colorValue,
              ),
          ],
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
