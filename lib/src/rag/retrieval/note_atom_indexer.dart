import '../../local_store/entities.dart';
import '../../notes/models/note_document.dart';
import '../models/source_evidence.dart';

class NoteAtomIndexer {
  const NoteAtomIndexer();

  List<SourceEvidence> buildEvidence({
    required String noteId,
    required String noteTitle,
    required NoteDocument document,
  }) {
    final atoms = <SourceEvidence>[];
    final documentSearchText = document.searchMetadataText;
    for (final block in document.blocks) {
      if (NoteSearchRoles.normalize(block.searchRole) ==
          NoteSearchRoles.ignore) {
        continue;
      }
      final state = block.isIndexFresh
          ? ValidationState.validated
          : ValidationState.unreviewed;
      final blockSearchText = _joinSearchText([
        documentSearchText,
        _blockSearchMetadataText(block),
      ]);
      switch (block.type) {
        case NoteBlockType.heading:
        case NoteBlockType.paragraph:
        case NoteBlockType.mixed:
          atoms.addAll(
            _textAtoms(
              noteId: noteId,
              noteTitle: noteTitle,
              block: block,
              state: state,
              inheritedSearchText: blockSearchText,
            ),
          );
          break;
        case NoteBlockType.listItem:
          atoms.addAll(
            _listAtoms(
              noteId: noteId,
              noteTitle: noteTitle,
              block: block,
              state: state,
              inheritedSearchText: blockSearchText,
            ),
          );
          break;
        case NoteBlockType.table:
          atoms.addAll(
            _tableAtoms(
              noteId: noteId,
              noteTitle: noteTitle,
              block: block,
              state: state,
              inheritedSearchText: blockSearchText,
            ),
          );
          break;
        case NoteBlockType.flowchart:
          atoms.addAll(
            _flowchartAtoms(
              noteId: noteId,
              noteTitle: noteTitle,
              block: block,
              state: state,
              inheritedSearchText: blockSearchText,
            ),
          );
          break;
      }
    }
    return List.unmodifiable(atoms);
  }

  List<SourceEvidence> _textAtoms({
    required String noteId,
    required String noteTitle,
    required NoteBlock block,
    required ValidationState state,
    required String inheritedSearchText,
  }) {
    final units = _textUnits(
      block.type == NoteBlockType.mixed ? block.plainText : block.text,
    );
    if (units.isEmpty) {
      return const [];
    }
    final chunkTitle = block.title?.trim();
    return [
      for (var i = 0; i < units.length; i += 1)
        SourceEvidence(
          id: units.length == 1
              ? 'note:$noteId:${block.id}'
              : 'note:$noteId:${block.id}:part-$i',
          sourceType: EvidenceSourceType.textChunk,
          text: chunkTitle == null || chunkTitle.isEmpty
              ? units[i].text
              : '$chunkTitle: ${units[i].text}',
          label: units.length == 1
              ? _label(noteTitle, _kindLabel(block.type), chunkTitle)
              : '${_label(noteTitle, _kindLabel(block.type), chunkTitle)} · részlet ${i + 1}',
          validationState: state,
          documentId: noteId,
          searchText: _joinSearchText([
            inheritedSearchText,
            chunkTitle,
            _textRangeSearchText(block, units[i]),
          ]),
          atomType: NoteEvidenceAtomType.textSentence,
          noteTitle: noteTitle,
          chunkId: block.id,
          chunkTitle: chunkTitle,
          sourceStart: units[i].start,
          sourceEnd: units[i].end,
          fullChunkText: block.displayTextForIndexing,
        ),
    ];
  }

  List<SourceEvidence> _listAtoms({
    required String noteId,
    required String noteTitle,
    required NoteBlock block,
    required ValidationState state,
    required String inheritedSearchText,
  }) {
    final chunkTitle = block.title?.trim();
    final fullChunkText = block.displayTextForIndexing;
    if (block.listItems.isEmpty) {
      final text = block.text.trim();
      if (text.isEmpty) {
        return const [];
      }
      return [
        SourceEvidence(
          id: 'note:$noteId:${block.id}:item-0',
          sourceType: EvidenceSourceType.textChunk,
          text: chunkTitle == null || chunkTitle.isEmpty
              ? text
              : '$chunkTitle: $text',
          label:
              '${_label(noteTitle, _kindLabel(block.type), chunkTitle)} · listaelem 1',
          validationState: state,
          documentId: noteId,
          searchText: _joinSearchText([inheritedSearchText, chunkTitle]),
          atomType: NoteEvidenceAtomType.listItem,
          noteTitle: noteTitle,
          chunkId: block.id,
          chunkTitle: chunkTitle,
          sourceStart: 0,
          sourceEnd: text.length,
          fullChunkText: fullChunkText,
        ),
      ];
    }
    return [
      for (var i = 0; i < block.listItems.length; i += 1)
        if (block.listItems[i].text.trim().isNotEmpty)
          SourceEvidence(
            id: 'note:$noteId:${block.id}:item-$i',
            sourceType: EvidenceSourceType.textChunk,
            text: chunkTitle == null || chunkTitle.isEmpty
                ? block.listItems[i].text.trim()
                : '$chunkTitle: ${block.listItems[i].text.trim()}',
            label:
                '${_label(noteTitle, _kindLabel(block.type), chunkTitle)} · listaelem ${i + 1}',
            validationState: state,
            documentId: noteId,
            searchText: _joinSearchText([
              inheritedSearchText,
              chunkTitle,
              block.listItems[i].searchMetadataText,
            ]),
            atomType: NoteEvidenceAtomType.listItem,
            noteTitle: noteTitle,
            chunkId: block.id,
            chunkTitle: chunkTitle,
            fullChunkText: fullChunkText,
          ),
    ];
  }

  List<SourceEvidence> _tableAtoms({
    required String noteId,
    required String noteTitle,
    required NoteBlock block,
    required ValidationState state,
    required String inheritedSearchText,
  }) {
    final rows = [
      for (var index = 0; index < block.rows.length; index += 1)
        if (block.rows[index].any((cell) => cell.trim().isNotEmpty))
          _IndexedTableRow(index: index, row: block.rows[index]),
    ];
    if (rows.isEmpty) {
      return const [];
    }
    final title = block.title?.trim();
    final firstRow = rows.first.row;
    final hasHeader =
        rows.length > 1 &&
        firstRow.every((cell) => cell.trim().isNotEmpty) &&
        firstRow.join(' ').length < 120;
    final headers = hasHeader ? firstRow : const <String>[];
    final start = hasHeader ? 1 : 0;
    final fullChunkText = block.displayTextForIndexing;
    final atoms = <SourceEvidence>[];
    for (var rowPosition = start; rowPosition < rows.length; rowPosition += 1) {
      final indexedRow = rows[rowPosition];
      final rowIndex = indexedRow.index;
      final row = indexedRow.row;
      if (!hasHeader) {
        atoms.add(
          SourceEvidence(
            id: 'note:$noteId:${block.id}:row-$rowIndex',
            sourceType: EvidenceSourceType.tableChunk,
            text: _tableRowText(row: row, headers: headers, title: title),
            label:
                '${_label(noteTitle, _kindLabel(block.type), title)} · sor ${rowIndex + 1}',
            validationState: state,
            documentId: noteId,
            searchText: _joinSearchText([
              inheritedSearchText,
              title,
              _tableScopedSearchText(block, rowIndex: rowIndex),
            ]),
            atomType: NoteEvidenceAtomType.tableRow,
            noteTitle: noteTitle,
            chunkId: block.id,
            chunkTitle: title,
            fullChunkText: fullChunkText,
          ),
        );
        continue;
      }
      final rowHeader = _rowHeader(row);
      for (var columnIndex = 0; columnIndex < row.length; columnIndex += 1) {
        final value = row[columnIndex].trim();
        if (value.isEmpty) {
          continue;
        }
        final columnHeader = columnIndex < headers.length
            ? headers[columnIndex].trim()
            : '';
        final rowHeaderLabel = headers.isNotEmpty ? headers.first.trim() : '';
        atoms.add(
          SourceEvidence(
            id: 'note:$noteId:${block.id}:row-$rowIndex-cell-$columnIndex',
            sourceType: EvidenceSourceType.tableChunk,
            text: _tableCellText(
              title: title,
              rowHeaderLabel: rowHeaderLabel,
              rowHeader: rowHeader,
              columnHeader: columnHeader,
              value: value,
            ),
            label:
                '${_label(noteTitle, _kindLabel(block.type), title)} · sor ${rowIndex + 1} · cella ${columnIndex + 1}',
            validationState: state,
            documentId: noteId,
            searchText: _joinSearchText([
              inheritedSearchText,
              title,
              rowHeader,
              columnHeader,
              value,
              _tableScopedSearchText(
                block,
                rowIndex: rowIndex,
                columnIndex: columnIndex,
              ),
            ]),
            atomType: NoteEvidenceAtomType.tableCell,
            noteTitle: noteTitle,
            chunkId: block.id,
            chunkTitle: title,
            fullChunkText: fullChunkText,
          ),
        );
      }
    }
    return atoms;
  }

  List<SourceEvidence> _flowchartAtoms({
    required String noteId,
    required String noteTitle,
    required NoteBlock block,
    required ValidationState state,
    required String inheritedSearchText,
  }) {
    final title = block.title?.trim();
    final nodesById = {for (final node in block.nodes) node.id: node};
    final fullChunkText = block.displayTextForIndexing;
    final atoms = <SourceEvidence>[];
    for (final node in block.nodes) {
      final text = node.label.trim();
      if (text.isEmpty) {
        continue;
      }
      atoms.add(
        SourceEvidence(
          id: 'note:$noteId:${block.id}:node-${node.id}',
          sourceType: EvidenceSourceType.flowchartNode,
          text: text,
          label: '${_label(noteTitle, _kindLabel(block.type), title)} · node',
          validationState: state,
          documentId: noteId,
          searchText: _joinSearchText([
            inheritedSearchText,
            title,
            _flowchartScopedSearchText(
              block,
              kind: NoteTagTargetKind.flowchartNode,
              elementId: node.id,
            ),
          ]),
          atomType: NoteEvidenceAtomType.flowchartNode,
          noteTitle: noteTitle,
          chunkId: block.id,
          chunkTitle: title,
          fullChunkText: fullChunkText,
        ),
      );
    }
    for (final edge in block.edges) {
      final from = nodesById[edge.fromNodeId];
      final to = nodesById[edge.toNodeId];
      if (from == null || to == null) {
        continue;
      }
      final label = _edgeLabelFromPort(edge, from);
      final relation = label.trim().isEmpty
          ? '${from.label.trim()} -> ${to.label.trim()}'
          : '${from.label.trim()} -> ${to.label.trim()} [$label]';
      atoms.add(
        SourceEvidence(
          id: 'note:$noteId:${block.id}:edge-${edge.id}',
          sourceType: EvidenceSourceType.flowchartEdge,
          text: relation,
          label:
              '${_label(noteTitle, _kindLabel(block.type), title)} · kapcsolat',
          validationState: state,
          documentId: noteId,
          searchText: _joinSearchText([
            inheritedSearchText,
            title,
            from.label,
            to.label,
            label,
            _flowchartScopedSearchText(
              block,
              kind: NoteTagTargetKind.flowchartEdge,
              elementId: edge.id,
            ),
          ]),
          atomType: NoteEvidenceAtomType.flowchartEdge,
          noteTitle: noteTitle,
          chunkId: block.id,
          chunkTitle: title,
          fullChunkText: fullChunkText,
        ),
      );
    }
    if (atoms.isEmpty && block.displayTextForIndexing.trim().isNotEmpty) {
      atoms.add(
        SourceEvidence(
          id: 'note:$noteId:${block.id}',
          sourceType: EvidenceSourceType.flowchartNode,
          text: block.displayTextForIndexing,
          label: _label(noteTitle, _kindLabel(block.type), title),
          validationState: state,
          documentId: noteId,
          searchText: _joinSearchText([inheritedSearchText, title]),
          atomType: NoteEvidenceAtomType.flowchartNode,
          noteTitle: noteTitle,
          chunkId: block.id,
          chunkTitle: title,
          fullChunkText: fullChunkText,
        ),
      );
    }
    return atoms;
  }

  String _blockSearchMetadataText(NoteBlock block) {
    final parts = <String>[];
    final context = block.searchContext?.trim();
    if (context != null && context.isNotEmpty) {
      parts.add(context);
    }
    parts.addAll(
      block.searchAliases
          .map((alias) => alias.trim())
          .where((alias) => alias.isNotEmpty),
    );
    final tagMetadata = _tagSearchText(block.tags);
    if (tagMetadata.isNotEmpty) {
      parts.add(tagMetadata);
    }
    return parts.join('\n').trim();
  }

  List<_TextUnit> _textUnits(String text) {
    if (text.trim().isEmpty) {
      return const [];
    }
    final delimiter = RegExp(
      r'(?:[.!?]+\s+|;\s*|\n+|\s+(?=(?:Rejtett\s+jegyzet|Definíció|Definicio|Megjegyzés|Megjegyzes)\s*:))',
      caseSensitive: false,
    );
    final units = <_TextUnit>[];
    var segmentStart = 0;
    for (final match in delimiter.allMatches(text)) {
      _addTextUnit(units, source: text, start: segmentStart, end: match.start);
      segmentStart = match.end;
    }
    _addTextUnit(units, source: text, start: segmentStart, end: text.length);
    return units;
  }

  void _addTextUnit(
    List<_TextUnit> units, {
    required String source,
    required int start,
    required int end,
  }) {
    if (start >= end) {
      return;
    }
    final segment = source.substring(start, end);
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final leading = segment.length - segment.trimLeft().length;
    final trailing = segment.length - segment.trimRight().length;
    units.add(
      _TextUnit(text: trimmed, start: start + leading, end: end - trailing),
    );
  }

  String _textRangeSearchText(NoteBlock block, _TextUnit unit) {
    final tags = <NoteKnowledgeTag>[];
    for (final rangeTag in block.rangeTags) {
      if (!rangeTag.isValid) {
        continue;
      }
      if (rangeTag.start < unit.end && rangeTag.end > unit.start) {
        tags.addAll(rangeTag.resolvedTags);
      }
    }
    return _tagSearchText(tags);
  }

  String _tableScopedSearchText(
    NoteBlock block, {
    required int rowIndex,
    int? columnIndex,
  }) {
    final tags = <NoteKnowledgeTag>[];
    for (final assignment in block.scopedTags) {
      final target = assignment.target;
      switch (target.kind) {
        case NoteTagTargetKind.tableRow:
          if (target.rowIndex == rowIndex) {
            tags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.tableColumn:
          if (columnIndex == null || target.columnIndex == columnIndex) {
            tags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.tableCell:
          if (target.rowIndex == rowIndex &&
              (columnIndex == null || target.columnIndex == columnIndex)) {
            tags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.textRange:
        case NoteTagTargetKind.listItem:
        case NoteTagTargetKind.flowchartNode:
        case NoteTagTargetKind.flowchartEdge:
          break;
      }
    }
    return _tagSearchText(tags);
  }

  String _flowchartScopedSearchText(
    NoteBlock block, {
    required NoteTagTargetKind kind,
    required String elementId,
  }) {
    final tags = <NoteKnowledgeTag>[];
    for (final assignment in block.scopedTags) {
      final target = assignment.target;
      if (target.kind == kind && target.elementId == elementId) {
        tags.addAll(assignment.tags);
      }
    }
    return _tagSearchText(tags);
  }

  String _edgeLabelFromPort(NoteFlowchartEdge edge, NoteFlowchartNode from) {
    final portId = edge.fromPortId;
    if (portId != null) {
      for (final port in from.ports) {
        if (port.id == portId && port.label.trim().isNotEmpty) {
          return port.label.trim();
        }
      }
    }
    return edge.label.trim();
  }

  String _rowHeader(List<String> row) {
    for (final cell in row) {
      final value = cell.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _tableCellText({
    required String? title,
    required String rowHeaderLabel,
    required String rowHeader,
    required String columnHeader,
    required String value,
  }) {
    final cells = <String>[];
    if (rowHeader.isNotEmpty && rowHeader != value) {
      cells.add(
        rowHeaderLabel.isEmpty ? rowHeader : '$rowHeaderLabel: $rowHeader',
      );
    }
    if (columnHeader.isNotEmpty && columnHeader != rowHeader) {
      cells.add('$columnHeader: ${value.trim()}');
    }
    if (cells.isEmpty) {
      cells.add(value.trim());
    }
    final body = cells.join(' | ');
    final prefix = title == null || title.isEmpty ? '' : '$title | ';
    return '$prefix$body'.trim();
  }

  String _tableRowText({
    required List<String> row,
    required List<String> headers,
    required String? title,
  }) {
    final cells = <String>[];
    for (var i = 0; i < row.length; i += 1) {
      final value = row[i].trim();
      if (value.isEmpty) {
        continue;
      }
      final header = i < headers.length ? headers[i].trim() : '';
      cells.add(header.isEmpty ? value : '$header: $value');
    }
    final prefix = title == null || title.isEmpty ? '' : '$title | ';
    return '$prefix${cells.join(' | ')}'.trim();
  }

  String _label(String noteTitle, String kindLabel, String? chunkTitle) {
    final suffix = chunkTitle == null || chunkTitle.isEmpty
        ? kindLabel
        : '$kindLabel · $chunkTitle';
    return 'Jegyzet · $noteTitle · $suffix';
  }

  String _kindLabel(NoteBlockType type) {
    return switch (type) {
      NoteBlockType.table => 'Táblázat',
      NoteBlockType.flowchart => 'Flowchart',
      NoteBlockType.listItem => 'Lista',
      NoteBlockType.heading => 'Címsor',
      NoteBlockType.paragraph => 'Szöveg',
      NoteBlockType.mixed => 'Szöveg',
    };
  }

  String _tagSearchText(Iterable<NoteKnowledgeTag> tags) {
    final values = <String>{};
    for (final tag in tags) {
      final metadata = tag.metadataText.trim();
      if (metadata.isNotEmpty) {
        values.add(metadata);
      }
      final label = tag.label.trim();
      if (label.isNotEmpty) {
        values.add(label);
      }
    }
    return values.join('\n').trim();
  }

  String _joinSearchText(Iterable<String?> values) {
    return values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join('\n')
        .trim();
  }
}

class _TextUnit {
  const _TextUnit({required this.text, required this.start, required this.end});

  final String text;
  final int start;
  final int end;
}

class _IndexedTableRow {
  const _IndexedTableRow({required this.index, required this.row});

  final int index;
  final List<String> row;
}
