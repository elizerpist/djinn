import 'dart:convert';

import '../../notes/models/note_document.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';

NoteBlock noteBlockFromPdfChunk(ExtractedKnowledgeItem item) {
  final structured = _structuredNoteBlockFromPdfChunk(item);
  if (structured != null) {
    return structured;
  }
  final title = item.sectionTitle?.trim();
  final blockTitle = title == null || title.isEmpty ? null : title;
  return switch (item.chunkKind) {
    LocalChunkKind.list => NoteBlock(
      id: item.id,
      type: NoteBlockType.listItem,
      title: blockTitle,
      listItems: _listItems(item.text),
      tags: item.tags,
    ),
    LocalChunkKind.table => NoteBlock(
      id: item.id,
      type: NoteBlockType.table,
      title: blockTitle,
      rows: _tableRows(item.text),
      tags: item.tags,
    ),
    LocalChunkKind.flowchart => NoteBlock(
      id: item.id,
      type: NoteBlockType.flowchart,
      title: blockTitle,
      text: item.text,
      nodes: [
        NoteFlowchartNode(
          id: '${item.id}-node',
          label: item.text.trim().isEmpty ? 'Flowchart elem' : item.text.trim(),
          x: 120,
          y: 120,
        ),
      ],
      tags: item.tags,
    ),
    LocalChunkKind.text => NoteBlock(
      id: item.id,
      type: NoteBlockType.paragraph,
      title: blockTitle,
      text: item.text,
      tags: item.tags,
    ),
  };
}

NoteBlock? _structuredNoteBlockFromPdfChunk(ExtractedKnowledgeItem item) {
  final raw = item.structuredContentJson?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final block = NoteBlock.fromJson(Map<String, Object?>.from(decoded));
    final title = block.title?.trim();
    final fallbackTitle = item.sectionTitle?.trim();
    return block.copyWith(
      id: block.id.trim().isEmpty ? item.id : block.id,
      title: title?.isNotEmpty == true ? block.title : fallbackTitle,
    );
  } catch (_) {
    return null;
  }
}

LocalChunkKind localChunkKindFromNoteBlock(NoteBlock block) {
  return switch (block.type) {
    NoteBlockType.listItem => LocalChunkKind.list,
    NoteBlockType.table => LocalChunkKind.table,
    NoteBlockType.flowchart => LocalChunkKind.flowchart,
    NoteBlockType.heading ||
    NoteBlockType.paragraph ||
    NoteBlockType.mixed => LocalChunkKind.text,
  };
}

String pdfChunkTextFromNoteBlock(NoteBlock block) {
  return switch (block.type) {
    NoteBlockType.listItem => _listText(block),
    NoteBlockType.table => _tableText(block),
    NoteBlockType.flowchart => _flowchartText(block),
    NoteBlockType.heading || NoteBlockType.paragraph => block.text.trim(),
    NoteBlockType.mixed => block.plainText,
  };
}

List<NoteListItem> _listItems(String text) {
  final lines = text
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return const [NoteListItem(id: 'item-1', text: '')];
  }
  return [
    for (var index = 0; index < lines.length; index += 1)
      _listItemFromLine(index, lines[index]),
  ];
}

NoteListItem _listItemFromLine(int index, String line) {
  final leadingSpaces = line.length - line.trimLeft().length;
  final level = (leadingSpaces / 2).floor();
  final trimmed = line.trimLeft();
  final checkboxMatch = RegExp(r'^\[(x|X| )\]\s*(.*)$').firstMatch(trimmed);
  if (checkboxMatch == null) {
    return NoteListItem(id: 'item-${index + 1}', text: trimmed, level: level);
  }
  return NoteListItem(
    id: 'item-${index + 1}',
    text: checkboxMatch.group(2)?.trim() ?? '',
    level: level,
    checked: checkboxMatch.group(1)?.toLowerCase() == 'x',
  );
}

List<List<String>> _tableRows(String text) {
  final rows = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) {
        final separator = line.contains('|') ? '|' : ';';
        return line
            .split(separator)
            .map((cell) => cell.trim())
            .toList(growable: false);
      })
      .where((row) => row.any((cell) => cell.isNotEmpty))
      .toList(growable: false);
  if (rows.isEmpty) {
    return const [
      ['', ''],
    ];
  }
  return rows;
}

String _listText(NoteBlock block) {
  if (block.listItems.isEmpty) {
    return block.text.trim();
  }
  return block.listItems
      .map((item) {
        final text = item.text.trim();
        if (text.isEmpty) {
          return '';
        }
        final indent = '  ' * item.level.clamp(0, 8).toInt();
        final marker = item.checked ? '[x]' : '[ ]';
        return '$indent$marker $text';
      })
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}

String _tableText(NoteBlock block) {
  return block.rows
      .map((row) => row.map((cell) => cell.trim()).join(' | '))
      .where((line) => line.replaceAll('|', '').trim().isNotEmpty)
      .join('\n')
      .trim();
}

String _flowchartText(NoteBlock block) {
  final labelsById = {
    for (final node in block.nodes)
      if (node.label.trim().isNotEmpty) node.id: node.label.trim(),
  };
  final lines = [
    for (final node in block.nodes)
      if (node.label.trim().isNotEmpty) node.label.trim(),
    for (final edge in block.edges)
      if (edge.fromNodeId.trim().isNotEmpty && edge.toNodeId.trim().isNotEmpty)
        _flowchartEdgeText(edge, labelsById),
  ];
  final generated = lines.where((line) => line.isNotEmpty).join('\n').trim();
  return generated.isNotEmpty ? generated : block.text.trim();
}

String _flowchartEdgeText(
  NoteFlowchartEdge edge,
  Map<String, String> labelsById,
) {
  final from = labelsById[edge.fromNodeId] ?? edge.fromNodeId.trim();
  final to = labelsById[edge.toNodeId] ?? edge.toNodeId.trim();
  final label = edge.label.trim();
  if (from.isEmpty || to.isEmpty) {
    return '';
  }
  if (label.isEmpty) {
    return '$from -> $to';
  }
  return '$from -> $to: $label';
}
