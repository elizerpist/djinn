import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../../notes/data/note_chunk_builder.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/models/note_document.dart';
import '../../offline/local_vector_search_service.dart';
import '../../offline/offline_search_service.dart';
import '../models/source_evidence.dart';
import 'local_retriever.dart';

class NoteAwareLocalRetriever implements LocalRetriever {
  NoteAwareLocalRetriever({
    required LocalRetriever base,
    required NoteRepository noteRepository,
    OfflineSearchService offlineSearch = const OfflineSearchService(),
    LocalVectorSearchService localVectorSearch =
        const LocalVectorSearchService(),
    LocalKnowledgeGraphExpander graphExpander =
        const LocalKnowledgeGraphExpander(),
  }) : _base = base,
       _noteRepository = noteRepository,
       _offlineSearch = offlineSearch,
       _localVectorSearch = localVectorSearch,
       _graphExpander = graphExpander;

  final LocalRetriever _base;
  final NoteRepository _noteRepository;
  final OfflineSearchService _offlineSearch;
  final LocalVectorSearchService _localVectorSearch;
  final LocalKnowledgeGraphExpander _graphExpander;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? query,
    bool allowKeywordExpansion = false,
  }) async {
    final baseResults = await _base.retrieve(
      queryVector: queryVector,
      limit: limit,
      minimumSimilarity: minimumSimilarity,
      query: query,
      allowKeywordExpansion: allowKeywordExpansion,
    );
    final trimmed = query?.trim() ?? '';
    if (trimmed.isEmpty || baseResults.length >= limit) {
      return baseResults;
    }
    final noteEvidence = await _loadNoteEvidence(
      logEmbeddingFallback: allowKeywordExpansion,
      granular: !allowKeywordExpansion,
    );
    final List<SourceEvidence> noteMatches;
    if (allowKeywordExpansion) {
      noteMatches = _keywordMatches(
        query: trimmed,
        evidence: noteEvidence,
        limit: limit - baseResults.length,
      );
    } else {
      final noteById = {for (final item in noteEvidence) item.id: item};
      final vectorMatches = _localVectorSearch.search(
        query: trimmed,
        mode: 'note_vector',
        limit: limit - baseResults.length,
        chunks: [
          for (final item in noteEvidence)
            LocalVectorChunk(
              id: item.id,
              label: item.label,
              text: item.searchableText,
            ),
        ],
      );
      noteMatches = _pruneCompetingEvidence(
        query: trimmed,
        seeds: [
          for (final match in vectorMatches)
            if (noteById[match.id] != null)
              SourceEvidence(
                id: noteById[match.id]!.id,
                sourceType: noteById[match.id]!.sourceType,
                text: noteById[match.id]!.text,
                label: noteById[match.id]!.label,
                validationState: noteById[match.id]!.validationState,
                documentId: noteById[match.id]!.documentId,
                pageNumber: noteById[match.id]!.pageNumber,
                score: match.score,
                searchText: noteById[match.id]!.searchText,
              ),
        ],
      );
      DebugConsole.log(
        '[VectorGraph] note local vector expansion mode=note_vector '
        'candidates=${noteEvidence.length} matches=${noteMatches.length}',
      );
    }
    final combined = _dedupe([...baseResults, ...noteMatches]);
    final expanded = _graphExpander.expand(
      query: trimmed,
      seeds: combined,
      candidates: noteEvidence,
      existing: combined,
      limit: _graphExpansionLimit(limit, noteEvidence.length),
    );
    final result = _pruneCompetingEvidence(
      query: trimmed,
      seeds: _dedupe([...combined, ...expanded]),
    ).take(limit).toList();
    DebugConsole.log(
      '[VectorGraph] note-aware retrieval base=${baseResults.length} '
      'noteMatches=${noteMatches.length} graph=${expanded.length} '
      'total=${result.length}',
    );
    return result;
  }

  @override
  Future<List<SourceEvidence>> retrieveLocalVector({
    required String query,
    required int limit,
    required String mode,
  }) async {
    final baseResults = await _base.retrieveLocalVector(
      query: query,
      limit: limit,
      mode: mode,
    );
    final noteEvidence = await _loadNoteEvidence(granular: true);
    final noteById = {for (final item in noteEvidence) item.id: item};
    final noteMatches = _localVectorSearch.search(
      query: query,
      mode: mode,
      limit: limit,
      chunks: [
        for (final item in noteEvidence)
          LocalVectorChunk(
            id: item.id,
            label: item.label,
            text: item.searchableText,
          ),
      ],
    );
    final noteSeeds = _pruneCompetingEvidence(
      query: query,
      seeds: [
        for (final match in noteMatches)
          if (noteById[match.id] != null)
            SourceEvidence(
              id: noteById[match.id]!.id,
              sourceType: noteById[match.id]!.sourceType,
              text: noteById[match.id]!.text,
              label: noteById[match.id]!.label,
              validationState: noteById[match.id]!.validationState,
              documentId: noteById[match.id]!.documentId,
              pageNumber: noteById[match.id]!.pageNumber,
              score: match.score,
              searchText: noteById[match.id]!.searchText,
            ),
      ],
    );
    final combined = _dedupe([...baseResults, ...noteSeeds]);
    final expanded = _graphExpander.expand(
      query: query,
      seeds: combined,
      candidates: noteEvidence,
      existing: combined,
      limit: _graphExpansionLimit(limit, noteEvidence.length),
    );
    final result = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([...combined, ...expanded]),
    ).take(limit).toList();
    DebugConsole.log(
      '[LocalVector] note search mode=$mode base=${baseResults.length} '
      'candidates=${noteEvidence.length} matches=${noteSeeds.length} '
      'graph=${expanded.length} total=${result.length}',
    );
    return result;
  }

  @override
  Future<List<SourceEvidence>> retrieveHybrid({
    required String query,
    required int limit,
    required String vectorMode,
  }) async {
    final baseResults = await _base.retrieveHybrid(
      query: query,
      limit: limit,
      vectorMode: vectorMode,
    );
    final noteEvidence = await _loadNoteEvidence(granular: true);
    final noteById = {for (final item in noteEvidence) item.id: item};
    final vectorMatches = _localVectorSearch.search(
      query: query,
      mode: vectorMode,
      limit: limit,
      chunks: [
        for (final item in noteEvidence)
          LocalVectorChunk(
            id: item.id,
            label: item.label,
            text: item.searchableText,
          ),
      ],
    );
    final vectorSeeds = [
      for (final match in vectorMatches)
        if (noteById[match.id] != null)
          SourceEvidence(
            id: noteById[match.id]!.id,
            sourceType: noteById[match.id]!.sourceType,
            text: noteById[match.id]!.text,
            label: noteById[match.id]!.label,
            validationState: noteById[match.id]!.validationState,
            documentId: noteById[match.id]!.documentId,
            pageNumber: noteById[match.id]!.pageNumber,
            score: match.score,
            searchText: noteById[match.id]!.searchText,
          ),
    ];
    final keywordSeeds = _keywordMatches(
      query: query,
      evidence: noteEvidence,
      limit: limit,
    );
    final symbolSeeds = _symbolMatches(
      query: query,
      evidence: noteEvidence,
      limit: limit,
    );
    final combined = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([
        ...baseResults,
        ...vectorSeeds,
        ...keywordSeeds,
        ...symbolSeeds,
      ]),
    );
    final expanded = _graphExpander.expand(
      query: query,
      seeds: combined,
      candidates: noteEvidence,
      existing: combined,
      limit: _graphExpansionLimit(limit, noteEvidence.length),
    );
    final result = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([...combined, ...expanded]),
    ).take(limit).toList();
    DebugConsole.log(
      '[HybridSearch] note search mode=$vectorMode base=${baseResults.length} '
      'candidates=${noteEvidence.length} vector=${vectorSeeds.length} '
      'keyword=${keywordSeeds.length} symbol=${symbolSeeds.length} '
      'graph=${expanded.length} total=${result.length}',
    );
    return result;
  }

  List<SourceEvidence> _pruneCompetingEvidence({
    required String query,
    required List<SourceEvidence> seeds,
  }) {
    if (seeds.length < 2) {
      return seeds;
    }
    final queryTerms = _simpleTerms(query);
    if (queryTerms.isEmpty) {
      return seeds;
    }
    final groups = <String, List<SourceEvidence>>{};
    for (final seed in seeds) {
      final group = _competingGroupId(seed.id);
      if (group != null) {
        groups.putIfAbsent(group, () => []).add(seed);
      }
    }
    if (groups.isEmpty) {
      return seeds;
    }
    final removedIds = <String>{};
    for (final entry in groups.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      final scores = <String, int>{};
      var best = 0;
      for (final seed in entry.value) {
        final normalized = _simpleNormalize(seed.text);
        final coverage = queryTerms
            .where((term) => _simpleContainsTerm(normalized, term))
            .length;
        scores[seed.id] = coverage;
        if (coverage > best) {
          best = coverage;
        }
      }
      if (best <= 0) {
        continue;
      }
      for (final seed in entry.value) {
        final coverage = scores[seed.id] ?? 0;
        if (coverage < best) {
          removedIds.add(seed.id);
          DebugConsole.log(
            '[LocalIndex] competing evidence pruned id=${seed.id} '
            'group=${entry.key} reason=lower_query_term_coverage '
            'coverage=$coverage best=$best',
          );
        }
      }
    }
    if (removedIds.isEmpty) {
      return seeds;
    }
    return seeds
        .where((seed) => !removedIds.contains(seed.id))
        .toList(growable: false);
  }

  String? _competingGroupId(String id) {
    for (final marker in const [':row-', ':part-']) {
      final index = id.lastIndexOf(marker);
      if (index > 0) {
        return id.substring(0, index);
      }
    }
    return null;
  }

  Set<String> _simpleTerms(String value) {
    const stopWords = {
      'akkor',
      'eseten',
      'soran',
      'teendo',
      'tortenik',
      'mikor',
      'hogyan',
      'amely',
      'amikor',
      'szerint',
    };
    return _simpleNormalize(value)
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2 && !stopWords.contains(term))
        .toSet();
  }

  bool _simpleContainsTerm(String normalized, String term) {
    final tokens = normalized.split(RegExp(r'\s+'));
    return tokens.any(
      (token) => token == term || (term.length >= 4 && token.contains(term)),
    );
  }

  String _simpleNormalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ő', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ű', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  @override
  Future<List<SourceEvidence>> retrieveOffline({
    required String query,
    required int limit,
  }) async {
    final baseResults = await _base.retrieveOffline(query: query, limit: limit);
    final noteEvidence = await _loadNoteEvidence();
    final noteMatches = _keywordMatches(
      query: query,
      evidence: noteEvidence,
      limit: limit,
    );
    final combined = _dedupe([...baseResults, ...noteMatches]);
    final expanded = _graphExpander.expand(
      query: query,
      seeds: combined,
      candidates: noteEvidence,
      existing: combined,
      limit: limit,
    );
    final result = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([...combined, ...expanded]),
    ).take(limit).toList();
    DebugConsole.log(
      '[Offline] note-aware retrieval base=${baseResults.length} '
      'noteMatches=${noteMatches.length} graph=${expanded.length} '
      'total=${result.length}',
    );
    return result;
  }

  Future<List<SourceEvidence>> _loadNoteEvidence({
    bool logEmbeddingFallback = false,
    bool granular = false,
  }) async {
    final notes = await _noteRepository.listNotes();
    final evidence = <SourceEvidence>[];
    for (final note in notes) {
      if (note.auditState.wireName == 'rejected') {
        DebugConsole.log(
          '[LocalIndex] note skipped id=${note.id} reason=rejected',
        );
        continue;
      }
      final chunks = const NoteChunkBuilder().build(
        noteId: note.id,
        noteTitle: note.title,
        document: note.document,
      );
      for (final chunk in chunks) {
        DebugConsole.log(
          '[LocalIndex] note chunk id=${chunk.id} note=${note.id} '
          'block=${chunk.blockId} kind=${chunk.kind.name} '
          'chars=${chunk.text.length} indexFresh=${chunk.isIndexFresh} '
          'needsReindex=${chunk.needsReindex}',
        );
        if (logEmbeddingFallback) {
          DebugConsole.log(
            '[LocalEmbedding] note chunk id=${chunk.id} state=keyword_selected '
            'reason=explicit_keyword_mode indexFresh=${chunk.isIndexFresh}',
          );
        }
        if (granular) {
          evidence.addAll(_granularEvidenceForChunk(note.document, chunk));
        } else {
          evidence.add(
            SourceEvidence(
              id: 'note:${chunk.noteId}:${chunk.blockId}',
              sourceType: _sourceTypeFor(chunk.kind),
              text: chunk.text,
              label: 'Jegyzet · ${chunk.noteTitle} · ${_kindLabel(chunk.kind)}',
              validationState: chunk.isIndexFresh
                  ? ValidationState.validated
                  : ValidationState.unreviewed,
              documentId: chunk.noteId,
              searchText: chunk.searchText,
            ),
          );
        }
      }
    }
    DebugConsole.log(
      '[LocalIndex] note evidence loaded count=${evidence.length}',
    );
    return evidence;
  }

  List<SourceEvidence> _granularEvidenceForChunk(
    NoteDocument document,
    NoteChunkViewModel chunk,
  ) {
    NoteBlock? block;
    for (final candidate in document.blocks) {
      if (candidate.id == chunk.blockId) {
        block = candidate;
        break;
      }
    }
    if (block == null) {
      return const [];
    }
    final state = chunk.isIndexFresh
        ? ValidationState.validated
        : ValidationState.unreviewed;
    final baseLabel =
        'Jegyzet · ${chunk.noteTitle} · ${_kindLabel(chunk.kind)}';
    switch (block.type) {
      case NoteBlockType.table:
        return _tableRowEvidence(block, chunk, baseLabel, state);
      case NoteBlockType.listItem:
        return _listItemEvidence(block, chunk, baseLabel, state);
      case NoteBlockType.flowchart:
        return _flowchartUnitEvidence(block, chunk, baseLabel, state);
      case NoteBlockType.heading:
      case NoteBlockType.paragraph:
        return _textUnitEvidence(block, chunk, baseLabel, state);
    }
  }

  List<SourceEvidence> _textUnitEvidence(
    NoteBlock block,
    NoteChunkViewModel chunk,
    String baseLabel,
    ValidationState state,
  ) {
    final units = _textUnits(block.text);
    if (units.isEmpty) {
      return const [];
    }
    final title = block.title?.trim();
    return [
      for (var i = 0; i < units.length; i += 1)
        SourceEvidence(
          id: units.length == 1
              ? 'note:${chunk.noteId}:${chunk.blockId}'
              : 'note:${chunk.noteId}:${chunk.blockId}:part-$i',
          sourceType: EvidenceSourceType.textChunk,
          text: title == null || title.isEmpty
              ? units[i]
              : '$title: ${units[i]}',
          label: units.length == 1
              ? baseLabel
              : '$baseLabel · részlet ${i + 1}',
          validationState: state,
          documentId: chunk.noteId,
          searchText: chunk.searchText,
        ),
    ];
  }

  List<String> _textUnits(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const [];
    }
    final boundaryAware = normalized.replaceAllMapped(
      RegExp(
        r'\s+(?=(?:Rejtett\s+jegyzet|Definíció|Definicio|Megjegyzés|Megjegyzes)\s*:)',
        caseSensitive: false,
      ),
      (_) => '. ',
    );
    final parts = boundaryAware
        .split(RegExp(r'(?:[.!?]+\s+|;\s*|\n+)'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length <= 1) {
      return [normalized];
    }
    return parts;
  }

  List<SourceEvidence> _tableRowEvidence(
    NoteBlock block,
    NoteChunkViewModel chunk,
    String baseLabel,
    ValidationState state,
  ) {
    final rows = block.rows
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList(growable: false);
    if (rows.isEmpty) {
      return const [];
    }
    final firstRow = rows.first;
    final hasHeader =
        rows.length > 1 &&
        firstRow.every((cell) => cell.trim().isNotEmpty) &&
        firstRow.join(' ').length < 80;
    final headers = hasHeader ? firstRow : const <String>[];
    final start = hasHeader ? 1 : 0;
    final title = block.title?.trim();
    final results = <SourceEvidence>[];
    for (var i = start; i < rows.length; i += 1) {
      final row = rows[i];
      final definitionCells = _independentDefinitionCells(row);
      if (definitionCells.isNotEmpty) {
        for (
          var cellIndex = 0;
          cellIndex < definitionCells.length;
          cellIndex += 1
        ) {
          final cell = definitionCells[cellIndex].trim();
          if (cell.isEmpty) {
            continue;
          }
          final header = _headerForDefinitionCell(headers, cellIndex);
          results.add(
            SourceEvidence(
              id: 'note:${chunk.noteId}:${chunk.blockId}:row-$i-cell-$cellIndex',
              sourceType: EvidenceSourceType.tableChunk,
              text: _tableCellText(cell: cell, header: header, title: title),
              label: '$baseLabel · sor ${i + 1} · cella ${cellIndex + 1}',
              validationState: state,
              documentId: chunk.noteId,
              searchText: chunk.searchText,
            ),
          );
        }
      } else {
        results.add(
          SourceEvidence(
            id: 'note:${chunk.noteId}:${chunk.blockId}:row-$i',
            sourceType: EvidenceSourceType.tableChunk,
            text: _tableRowText(row: row, headers: headers, title: title),
            label: '$baseLabel · sor ${i + 1}',
            validationState: state,
            documentId: chunk.noteId,
            searchText: chunk.searchText,
          ),
        );
      }
    }
    return results;
  }

  List<String> _independentDefinitionCells(List<String> row) {
    final cells = row
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toList(growable: false);
    if (cells.isEmpty) {
      return const [];
    }
    final logicalCells = <String>[];
    for (final cell in cells) {
      final split = _splitPipePackedDefinitions(cell);
      logicalCells.addAll(split.length > 1 ? split : [cell]);
    }
    if (logicalCells.length > 1 &&
        logicalCells.every(_looksLikeInlineDefinition)) {
      return logicalCells;
    }
    return const [];
  }

  List<String> _splitPipePackedDefinitions(String value) {
    final parts = value
        .split(RegExp(r'\s*\|\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length <= 1 || !parts.every(_looksLikeInlineDefinition)) {
      return const [];
    }
    return parts;
  }

  String _headerForDefinitionCell(List<String> headers, int cellIndex) {
    if (cellIndex < headers.length) {
      return headers[cellIndex].trim();
    }
    if (headers.length == 1) {
      return headers.single.trim();
    }
    return '';
  }

  bool _looksLikeInlineDefinition(String value) {
    return RegExp(r'^.{1,80}\s*[:=]\s*.{1,}$').hasMatch(value.trim());
  }

  String _tableCellText({
    required String cell,
    required String header,
    required String? title,
  }) {
    final body = header.isEmpty ? cell.trim() : '$header: ${cell.trim()}';
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
      final cell = row[i].trim();
      if (cell.isEmpty) {
        continue;
      }
      final header = i < headers.length ? headers[i].trim() : '';
      cells.add(header.isEmpty ? cell : '$header: $cell');
    }
    final prefix = title == null || title.isEmpty ? '' : '$title | ';
    return '$prefix${cells.join(' | ')}'.trim();
  }

  List<SourceEvidence> _listItemEvidence(
    NoteBlock block,
    NoteChunkViewModel chunk,
    String baseLabel,
    ValidationState state,
  ) {
    if (block.listItems.isEmpty) {
      final text = block.text.trim();
      if (text.isEmpty) {
        return const [];
      }
      final title = block.title?.trim();
      return [
        SourceEvidence(
          id: 'note:${chunk.noteId}:${chunk.blockId}:item-0',
          sourceType: EvidenceSourceType.textChunk,
          text: title == null || title.isEmpty ? text : '$title: $text',
          label: '$baseLabel · listaelem 1',
          validationState: state,
          documentId: chunk.noteId,
          searchText: chunk.searchText,
        ),
      ];
    }
    final title = block.title?.trim();
    return [
      for (var i = 0; i < block.listItems.length; i += 1)
        if (block.listItems[i].text.trim().isNotEmpty)
          SourceEvidence(
            id: 'note:${chunk.noteId}:${chunk.blockId}:item-$i',
            sourceType: EvidenceSourceType.textChunk,
            text: title == null || title.isEmpty
                ? block.listItems[i].text.trim()
                : '$title: ${block.listItems[i].text.trim()}',
            label: '$baseLabel · listaelem ${i + 1}',
            validationState: state,
            documentId: chunk.noteId,
            searchText: chunk.searchText,
          ),
    ];
  }

  List<SourceEvidence> _flowchartUnitEvidence(
    NoteBlock block,
    NoteChunkViewModel chunk,
    String baseLabel,
    ValidationState state,
  ) {
    final nodesById = {for (final node in block.nodes) node.id: node};
    final results = <SourceEvidence>[];
    for (final node in block.nodes) {
      if (node.label.trim().isEmpty) {
        continue;
      }
      results.add(
        SourceEvidence(
          id: 'note:${chunk.noteId}:${chunk.blockId}:node-${node.id}',
          sourceType: EvidenceSourceType.flowchartNode,
          text: node.label.trim(),
          label: '$baseLabel · node',
          validationState: state,
          documentId: chunk.noteId,
          searchText: chunk.searchText,
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
      results.add(
        SourceEvidence(
          id: 'note:${chunk.noteId}:${chunk.blockId}:edge-${edge.id}',
          sourceType: EvidenceSourceType.flowchartEdge,
          text: relation,
          label: '$baseLabel · kapcsolat',
          validationState: state,
          documentId: chunk.noteId,
          searchText: chunk.searchText,
        ),
      );
    }
    if (results.isEmpty && chunk.text.trim().isNotEmpty) {
      results.add(
        SourceEvidence(
          id: 'note:${chunk.noteId}:${chunk.blockId}',
          sourceType: EvidenceSourceType.flowchartNode,
          text: chunk.text,
          label: baseLabel,
          validationState: state,
          documentId: chunk.noteId,
          searchText: chunk.searchText,
        ),
      );
    }
    return results;
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

  List<SourceEvidence> _keywordMatches({
    required String query,
    required List<SourceEvidence> evidence,
    required int limit,
  }) {
    if (query.trim().isEmpty || evidence.isEmpty || limit <= 0) {
      return const [];
    }
    final byId = {for (final item in evidence) item.id: item};
    final chunks = evidence
        .map(
          (item) => OfflineChunk(
            id: item.id,
            label: item.label,
            text: item.searchableText,
          ),
        )
        .toList(growable: false);
    final matches = _offlineSearch.search(
      query: query,
      chunks: chunks,
      limit: limit,
    );
    final results = <SourceEvidence>[];
    for (final match in matches) {
      final evidence = byId[match.id];
      if (evidence != null) {
        results.add(evidence);
        DebugConsole.log(
          '[LocalIndex] note keyword match id=${evidence.id} '
          'label=${evidence.label}',
        );
      }
    }
    return results;
  }

  List<SourceEvidence> _symbolMatches({
    required String query,
    required List<SourceEvidence> evidence,
    required int limit,
  }) {
    final symbols = _acronyms(query);
    if (symbols.isEmpty || evidence.isEmpty || limit <= 0) {
      return const [];
    }
    final results = <SourceEvidence>[];
    for (final item in evidence) {
      if (results.length >= limit) {
        break;
      }
      final text = item.searchableText;
      for (final symbol in symbols) {
        final escaped = RegExp.escape(symbol);
        final definitionPattern = RegExp(
          '(^|\\n|\\s)$escaped\\s*[:=\\-]',
          caseSensitive: false,
        );
        if (definitionPattern.hasMatch(text)) {
          results.add(item);
          DebugConsole.log(
            '[LocalIndex] note symbol match id=${item.id} symbol=$symbol',
          );
          break;
        }
      }
    }
    return results;
  }

  List<SourceEvidence> _dedupe(List<SourceEvidence> items) {
    final seen = <String>{};
    final results = <SourceEvidence>[];
    for (final item in items) {
      if (seen.add(item.id)) {
        results.add(item);
      }
    }
    return results;
  }

  int _graphExpansionLimit(int resultLimit, int candidateCount) {
    final expandedLimit = resultLimit + 8;
    if (candidateCount < expandedLimit) {
      return candidateCount;
    }
    return expandedLimit;
  }

  EvidenceSourceType _sourceTypeFor(NoteChunkKind kind) {
    return switch (kind) {
      NoteChunkKind.table => EvidenceSourceType.tableChunk,
      NoteChunkKind.flowchart => EvidenceSourceType.flowchartNode,
      NoteChunkKind.text || NoteChunkKind.list => EvidenceSourceType.textChunk,
    };
  }

  String _kindLabel(NoteChunkKind kind) {
    return switch (kind) {
      NoteChunkKind.text => 'Szöveg',
      NoteChunkKind.list => 'Lista',
      NoteChunkKind.table => 'Táblázat',
      NoteChunkKind.flowchart => 'Flowchart',
    };
  }

  Set<String> _acronyms(String value) {
    return RegExp(
      r'\b[A-ZÁÉÍÓÖŐÚÜŰ]{2,}[0-9]*\b',
    ).allMatches(value).map((match) => match.group(0)!).toSet();
  }
}

class LocalKnowledgeGraphExpander {
  const LocalKnowledgeGraphExpander();

  List<SourceEvidence> expand({
    required String query,
    required List<SourceEvidence> seeds,
    required List<SourceEvidence> candidates,
    required List<SourceEvidence> existing,
    required int limit,
  }) {
    if (seeds.isEmpty || candidates.isEmpty || existing.length >= limit) {
      DebugConsole.log(
        '[LocalGraph] expand skipped seeds=${seeds.length} '
        'candidates=${candidates.length} existing=${existing.length}',
      );
      return const [];
    }
    final existingIds = existing.map((item) => item.id).toSet();
    final queryTerms = _terms(query).toSet();
    DebugConsole.log(
      '[LocalGraph] expand start seeds=${seeds.length} '
      'candidates=${candidates.length} queryTerms=${queryTerms.length}',
    );
    var existingLinks = 0;
    final scannedSeedIds = <String>{};
    final pendingById = <String, _PendingGraphLink>{};
    void collectLinks(SourceEvidence seed) {
      if (!scannedSeedIds.add(seed.id)) {
        return;
      }
      final seedTerms = {
        ...queryTerms,
        ..._terms(seed.text),
      };
      final seedAcronyms = _acronyms('${seed.text}\n$query');
      DebugConsole.log(
        '[LocalGraph] seed source=${seed.id} type=${seed.sourceType.wireName} '
        'terms=${seedTerms.take(12).join(',')} '
        'symbols=${seedAcronyms.take(8).join(',')}',
      );
      for (final candidate in candidates) {
        if (candidate.id == seed.id) {
          continue;
        }
        final link = _linkReason(
          seed: seed,
          candidate: candidate,
          seedTerms: seedTerms,
          queryTerms: queryTerms,
          seedAcronyms: seedAcronyms,
        );
        if (link == null) {
          continue;
        }
        if (existingIds.contains(candidate.id)) {
          existingLinks += 1;
          DebugConsole.log(
            '[LocalGraph] link existing type=${link.type} source=${seed.id} '
            'target=${candidate.id} reason=${link.reason}',
          );
          continue;
        }
        final pending = _PendingGraphLink(
          seed: seed,
          candidate: candidate,
          link: link,
        );
        final previous = pendingById[candidate.id];
        if (previous == null || pending.comparePriority(previous) < 0) {
          pendingById[candidate.id] = pending;
        }
      }
    }

    for (final seed in seeds) {
      collectLinks(seed);
    }

    final results = <SourceEvidence>[];
    while (pendingById.isNotEmpty && results.length + existing.length < limit) {
      final pending = pendingById.values.toList(growable: false)
        ..sort((a, b) => a.comparePriority(b));
      final item = pending.first;
      pendingById.remove(item.candidate.id);
      if (existingIds.contains(item.candidate.id)) {
        continue;
      }
      existingIds.add(item.candidate.id);
      results.add(item.candidate);
      DebugConsole.log(
        '[LocalGraph] link type=${item.link.type} source=${item.seed.id} '
        'target=${item.candidate.id} reason=${item.link.reason}',
      );
      collectLinks(item.candidate);
    }
    if (pendingById.isNotEmpty) {
      final pending = pendingById.values.toList(growable: false)
        ..sort((a, b) => a.comparePriority(b));
      for (final item in pending) {
        DebugConsole.log(
          '[LocalGraph] link skipped source=${item.seed.id} '
          'target=${item.candidate.id} reason=limit type=${item.link.type}',
        );
      }
    }
    DebugConsole.log(
      '[LocalGraph] expand result count=${results.length} '
      'existingLinks=$existingLinks candidates=${pendingById.length}',
    );
    return results;
  }

  _GraphLink? _linkReason({
    required SourceEvidence seed,
    required SourceEvidence candidate,
    required Set<String> seedTerms,
    required Set<String> queryTerms,
    required Set<String> seedAcronyms,
  }) {
    final branchLink = _branchValueLink(
      seed: seed,
      candidate: candidate,
      seedTerms: seedTerms,
    );
    if (branchLink != null) {
      return branchLink;
    }
    final reverseBranchLink = _branchValueLink(
      seed: candidate,
      candidate: seed,
      seedTerms: seedTerms,
    );
    if (reverseBranchLink != null) {
      return _GraphLink(
        reverseBranchLink.type,
        'reverse:${reverseBranchLink.reason}',
      );
    }

    final candidateText = candidate.text;
    for (final acronym in seedAcronyms) {
      final escaped = RegExp.escape(acronym);
      final definitionPattern = RegExp(
        '(^|\\n|\\s)$escaped\\s*[:=\\-]',
        caseSensitive: false,
      );
      if (definitionPattern.hasMatch(candidateText)) {
        return _GraphLink('definition', 'symbol:$acronym');
      }
    }
    final candidateTerms = _terms(candidate.text).toSet();
    final queryOverlap = candidateTerms.intersection(queryTerms);
    if (queryOverlap.length >= 2 && _looksLikeDefinitionStatement(candidate.text)) {
      return _GraphLink(
        'definition',
        'query_terms:${queryOverlap.take(4).join(',')}',
      );
    }
    final definitionKeys = _definitionKeys(candidate.text);
    final definitionOverlap = definitionKeys.intersection(seedTerms);
    if (definitionOverlap.isNotEmpty) {
      return _GraphLink(
        'definition',
        'keys:${definitionOverlap.take(4).join(',')}',
      );
    }
    if (_hasUnmatchedBranchContext(seed: seed, candidate: candidate)) {
      DebugConsole.log(
        '[LocalGraph] link skipped source=${seed.id} target=${candidate.id} '
        'reason=branch_context_without_value',
      );
      return null;
    }
    if (_looksLikeFlowchart(candidate.text)) {
      final flowTerms = _terms(candidate.text).toSet();
      final overlap = flowTerms.intersection(seedTerms).length;
      if (overlap >= 2) {
        return _GraphLink('flowchart', 'term_overlap:$overlap');
      }
    }
    if (candidate.sourceType == EvidenceSourceType.tableChunk) {
      if (_sameTableRowGroup(seed.id, candidate.id)) {
        DebugConsole.log(
          '[LocalGraph] link skipped source=${seed.id} target=${candidate.id} '
          'reason=competing_table_row',
        );
        return null;
      }
      final tableTerms = candidateTerms;
      final overlap = tableTerms.intersection(seedTerms).length;
      if (overlap >= 2 || definitionKeys.intersection(seedTerms).isNotEmpty) {
        return _GraphLink('table_join', 'term_overlap:$overlap');
      }
    }
    final overlap = candidateTerms.intersection(seedTerms).length;
    if (overlap >= 3) {
      return _GraphLink('semantic_keyword', 'term_overlap:$overlap');
    }
    return null;
  }

  bool _hasUnmatchedBranchContext({
    required SourceEvidence seed,
    required SourceEvidence candidate,
  }) {
    final branches = _branchSignals(seed.text);
    if (branches.isEmpty) {
      return false;
    }
    final candidateNormalized = _normalize(candidate.text);
    final candidateUnits = _candidateUnits(candidate.text);
    var hasContext = false;
    for (final branch in branches) {
      if (branch.contextTerms.isEmpty) {
        continue;
      }
      final contextScore = _contextScore(
        candidateNormalized,
        branch.contextTerms,
      );
      if (contextScore == 0) {
        continue;
      }
      hasContext = true;
      for (final unit in candidateUnits) {
        if (_branchValueMatches(branch, unit)) {
          return false;
        }
      }
    }
    return hasContext;
  }

  bool _sameTableRowGroup(String a, String b) {
    final first = _rowGroupId(a);
    final second = _rowGroupId(b);
    return first != null && first == second;
  }

  String? _rowGroupId(String id) {
    final index = id.lastIndexOf(':row-');
    if (index <= 0) {
      return null;
    }
    return id.substring(0, index);
  }

  _GraphLink? _branchValueLink({
    required SourceEvidence seed,
    required SourceEvidence candidate,
    required Set<String> seedTerms,
  }) {
    final branches = _branchSignals(seed.text);
    if (branches.isEmpty) {
      return null;
    }
    final candidateNormalized = _normalize(candidate.text);
    final candidateUnits = _candidateUnits(candidate.text);
    _BranchMatch? best;
    for (final branch in branches) {
      DebugConsole.log(
        '[LocalGraph] branch signal source=${seed.id} key=${branch.key} '
        'value=${branch.value} polarity=${branch.polarity ?? 'custom'} '
        'context=${branch.contextTerms.join(',')}',
      );
      final wholeContextScore = _contextScore(
        candidateNormalized,
        branch.contextTerms,
      );
      for (final unit in candidateUnits) {
        final unitContextScore = _contextScore(unit, branch.contextTerms);
        final contextScore = unitContextScore > wholeContextScore
            ? unitContextScore
            : wholeContextScore;
        if (branch.contextTerms.isNotEmpty && contextScore == 0) {
          continue;
        }
        if (!_branchValueMatches(branch, unit)) {
          continue;
        }
        final queryScore = _contextScore(
          unit,
          seedTerms.toList(growable: false),
        );
        final branchQueryScore = _contextScore(
          branch.value,
          seedTerms.toList(growable: false),
        );
        final score = contextScore * 4 + queryScore + branchQueryScore * 3;
        final match = _BranchMatch(
          branch: branch,
          score: score,
          contextScore: contextScore,
          unit: unit,
        );
        if (best == null || match.score > best.score) {
          best = match;
        }
      }
    }
    if (best == null) {
      DebugConsole.log(
        '[LocalGraph] branch candidate skipped source=${seed.id} '
        'target=${candidate.id} reason=no_branch_value_match',
      );
      return null;
    }
    final branch = best.branch;
    DebugConsole.log(
      '[LocalGraph] branch candidate matched source=${seed.id} '
      'target=${candidate.id} key=${branch.key} value=${branch.value} '
      'polarity=${branch.polarity ?? 'custom'} context=${best.contextScore} '
      'score=${best.score} unit=${best.unit}',
    );
    return _GraphLink(
      'branch_value',
      'key=${branch.key} value=${branch.value} '
          'polarity:${branch.polarity ?? 'custom'} context:${best.contextScore}',
    );
  }

  List<_BranchSignal> _branchSignals(String text) {
    final signals = <_BranchSignal>[];
    final edgePattern = RegExp(r'^(.+?)\s*->\s*(.+?)(?:\s*\[(.+?)\])?\s*$');
    for (final rawLine in text.split(RegExp(r'\n+'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final match = edgePattern.firstMatch(line);
      if (match == null) {
        continue;
      }
      final source = match.group(1)!.trim();
      final label = (match.group(3) ?? '').trim();
      if (!source.contains('?') || label.isEmpty) {
        continue;
      }
      final keyText = source.replaceAll('?', ' ').trim();
      final key = _normalize(keyText);
      final value = _normalize(label);
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      final polarity = _polarityFor(value);
      final keyTerms = _terms(keyText);
      final valueTerms = polarity == null
          ? _terms(label)
          : _conditionValueTerms(keyTerms);
      final valueTermSet = valueTerms.toSet();
      final contextTerms = polarity == null
          ? keyTerms
          : keyTerms
                .where((term) => !valueTermSet.contains(term))
                .toList(growable: false);
      signals.add(
        _BranchSignal(
          key: key,
          value: value,
          polarity: polarity,
          valueTerms: valueTerms,
          contextTerms: contextTerms,
        ),
      );
    }
    return signals;
  }

  String? _polarityFor(String normalizedValue) {
    if (normalizedValue == 'igen' || normalizedValue == 'yes') {
      return 'positive';
    }
    if (normalizedValue == 'nem' || normalizedValue == 'no') {
      return 'negative';
    }
    return null;
  }

  List<String> _conditionValueTerms(List<String> keyTerms) {
    if (keyTerms.isEmpty) {
      return const [];
    }
    if (keyTerms.length >= 3) {
      const valueMarkers = {
        'szine',
        'erteke',
        'tipusa',
        'allapota',
        'foka',
        'szintje',
        'merteke',
      };
      for (var i = 0; i < keyTerms.length - 1; i += 1) {
        if (valueMarkers.contains(keyTerms[i])) {
          return keyTerms.sublist(i + 1);
        }
      }
      return [keyTerms.first];
    }
    return [keyTerms.last];
  }

  int _contextScore(String candidateNormalized, List<String> contextTerms) {
    var score = 0;
    for (final term in contextTerms) {
      if (_containsTermFuzzy(candidateNormalized, term)) {
        score += 1;
      }
    }
    return score;
  }

  List<String> _candidateUnits(String text) {
    return text
        .split(RegExp(r'[\n;]+'))
        .map(_normalize)
        .where((unit) => unit.isNotEmpty)
        .toList(growable: false);
  }

  bool _branchValueMatches(_BranchSignal branch, String candidateNormalized) {
    if (branch.polarity == 'negative') {
      return _hasNegatedCondition(candidateNormalized, branch);
    }
    if (branch.polarity == 'positive') {
      return _hasAffirmedCondition(candidateNormalized, branch);
    }
    return _containsNormalizedPhrase(candidateNormalized, branch.value);
  }

  bool _hasNegatedCondition(String candidateNormalized, _BranchSignal branch) {
    if (_containsNegatedPhrase(candidateNormalized, branch.key)) {
      return true;
    }
    for (final term in branch.valueTerms) {
      if (_hasNegatedTerm(candidateNormalized, term)) {
        return true;
      }
    }
    return false;
  }

  bool _hasAffirmedCondition(String candidateNormalized, _BranchSignal branch) {
    final hasNegatedValue = branch.valueTerms.any(
      (term) => _hasNegatedTerm(candidateNormalized, term),
    );
    if (_containsNormalizedPhrase(candidateNormalized, branch.key) &&
        !_containsNegatedPhrase(candidateNormalized, branch.key) &&
        !hasNegatedValue) {
      return true;
    }
    for (final term in branch.valueTerms) {
      if (_containsTermFuzzy(candidateNormalized, term) &&
          !_hasNegatedTerm(candidateNormalized, term)) {
        return true;
      }
    }
    return false;
  }

  bool _containsNegatedPhrase(String candidateNormalized, String phrase) {
    final compactCandidate = candidateNormalized.replaceAll(' ', '');
    final compactPhrase = phrase.replaceAll(' ', '');
    return candidateNormalized.contains('nem $phrase') ||
        compactCandidate.contains('nem$compactPhrase');
  }

  bool _hasNegatedTerm(String candidateNormalized, String term) {
    final compactCandidate = candidateNormalized.replaceAll(' ', '');
    if (compactCandidate.contains('nem$term')) {
      return true;
    }
    final tokens = candidateNormalized.split(RegExp(r'\s+'));
    for (var i = 0; i < tokens.length - 1; i += 1) {
      if (tokens[i] == 'nem' &&
          (tokens[i + 1] == term ||
              (term.length >= 4 && tokens[i + 1].contains(term)))) {
        return true;
      }
    }
    return false;
  }

  bool _containsNormalizedPhrase(String candidateNormalized, String phrase) {
    if (phrase.isEmpty) {
      return false;
    }
    if (candidateNormalized.contains(phrase)) {
      return true;
    }
    final terms = phrase.split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
    return terms.every((term) => _containsTermFuzzy(candidateNormalized, term));
  }

  bool _containsTermFuzzy(String candidateNormalized, String term) {
    if (term.isEmpty) {
      return false;
    }
    final tokens = candidateNormalized.split(RegExp(r'\s+'));
    return tokens.any(
      (token) => token == term || (term.length >= 4 && token.contains(term)),
    );
  }

  Set<String> _definitionKeys(String text) {
    final keys = <String>{};
    for (final rawLine in text.split(RegExp(r'\n+'))) {
      var line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      RegExpMatch? match;
      String head;
      while (true) {
        final delimiter = RegExp(r'\s*(:|=|\|| - | – | — )\s*');
        match = delimiter.firstMatch(line);
        if (match == null || match.start == 0) {
          head = '';
          break;
        }
        head = line.substring(0, match.start).trim();
        if (!_isGenericDefinitionHead(head)) {
          break;
        }
        line = line.substring(match.end).trim();
      }
      if (match == null || head.isEmpty) {
        continue;
      }
      final headTerms = _terms(head);
      if (headTerms.isEmpty || headTerms.length > 4) {
        continue;
      }
      keys.addAll(headTerms);
      keys.add(_normalize(head));
    }
    return keys.where((key) => key.length > 2).toSet();
  }

  bool _looksLikeDefinitionStatement(String text) {
    final normalized = _normalize(text);
    return text.contains('<') ||
        text.contains('=') ||
        normalized.contains('akkor all fenn') ||
        normalized.contains('definicio') ||
        normalized.contains('jelentese');
  }

  bool _isGenericDefinitionHead(String value) {
    final normalized = _normalize(value);
    const generic = {
      'jegyzet',
      'rejtett jegyzet',
      'magyarazat',
      'szoveg',
      'lista',
      'tablazat',
      'flowchart',
      'kapcsolat',
      'node',
      'cim',
      'reszlet',
      'elem',
      'sor',
      'cella',
    };
    return generic.contains(normalized);
  }

  bool _looksLikeFlowchart(String text) => text.contains('->');

  List<String> _terms(String value) {
    return _normalize(value)
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2)
        .toSet()
        .toList(growable: false);
  }

  Set<String> _acronyms(String value) {
    return RegExp(
      r'\b[A-ZÁÉÍÓÖŐÚÜŰ]{2,}[0-9]*\b',
    ).allMatches(value).map((match) => match.group(0)!).toSet();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ő', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ű', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}

class _BranchSignal {
  const _BranchSignal({
    required this.key,
    required this.value,
    required this.polarity,
    required this.valueTerms,
    required this.contextTerms,
  });

  final String key;
  final String value;
  final String? polarity;
  final List<String> valueTerms;
  final List<String> contextTerms;
}

class _BranchMatch {
  const _BranchMatch({
    required this.branch,
    required this.score,
    required this.contextScore,
    required this.unit,
  });

  final _BranchSignal branch;
  final int score;
  final int contextScore;
  final String unit;
}

class _PendingGraphLink {
  const _PendingGraphLink({
    required this.seed,
    required this.candidate,
    required this.link,
  });

  final SourceEvidence seed;
  final SourceEvidence candidate;
  final _GraphLink link;

  int comparePriority(_PendingGraphLink other) {
    final priority = link.priority.compareTo(other.link.priority);
    if (priority != 0) {
      return priority;
    }
    final sourceType = _sourceTypePriority(
      candidate,
    ).compareTo(_sourceTypePriority(other.candidate));
    if (sourceType != 0) {
      return sourceType;
    }
    return candidate.id.compareTo(other.candidate.id);
  }

  int _sourceTypePriority(SourceEvidence evidence) {
    return switch (evidence.sourceType) {
      EvidenceSourceType.textChunk => 0,
      EvidenceSourceType.tableChunk => 1,
      EvidenceSourceType.flowchartNode => 2,
      EvidenceSourceType.flowchartEdge => 3,
      EvidenceSourceType.scoreChunk => 4,
    };
  }
}

class _GraphLink {
  const _GraphLink(this.type, this.reason);

  final String type;
  final String reason;

  int get priority {
    if (type == 'definition' && reason.startsWith('symbol:')) {
      return 0;
    }
    if (type == 'definition' && reason.startsWith('query_terms:')) {
      return 1;
    }
    return switch (type) {
      'definition' => 2,
      'branch_value' => 3,
      'table_join' => 4,
      'semantic_keyword' => 5,
      'flowchart' => 6,
      _ => 7,
    };
  }
}
