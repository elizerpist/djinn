import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../../notes/data/note_chunk_builder.dart';
import '../../notes/data/note_repository.dart';
import '../../offline/offline_search_service.dart';
import '../models/source_evidence.dart';
import 'local_retriever.dart';

class NoteAwareLocalRetriever implements LocalRetriever {
  NoteAwareLocalRetriever({
    required LocalRetriever base,
    required NoteRepository noteRepository,
    OfflineSearchService offlineSearch = const OfflineSearchService(),
    LocalKnowledgeGraphExpander graphExpander = const LocalKnowledgeGraphExpander(),
  })  : _base = base,
        _noteRepository = noteRepository,
        _offlineSearch = offlineSearch,
        _graphExpander = graphExpander;

  final LocalRetriever _base;
  final NoteRepository _noteRepository;
  final OfflineSearchService _offlineSearch;
  final LocalKnowledgeGraphExpander _graphExpander;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? query,
  }) async {
    final baseResults = await _base.retrieve(
      queryVector: queryVector,
      limit: limit,
      minimumSimilarity: minimumSimilarity,
      query: query,
    );
    final trimmed = query?.trim() ?? '';
    if (trimmed.isEmpty || baseResults.length >= limit) {
      return baseResults;
    }
    final noteEvidence = await _loadNoteEvidence(
      logEmbeddingFallback: true,
    );
    final noteMatches = _keywordMatches(
      query: trimmed,
      evidence: noteEvidence,
      limit: limit - baseResults.length,
    );
    final combined = _dedupe([...baseResults, ...noteMatches]);
    final expanded = _graphExpander.expand(
      query: trimmed,
      seeds: combined,
      candidates: noteEvidence,
      existing: combined,
      limit: limit,
    );
    final result = _dedupe([...combined, ...expanded]).take(limit).toList();
    DebugConsole.log(
      '[VectorGraph] note-aware retrieval base=${baseResults.length} '
      'noteMatches=${noteMatches.length} graph=${expanded.length} '
      'total=${result.length}',
    );
    return result;
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
    final result = _dedupe([...combined, ...expanded]).take(limit).toList();
    DebugConsole.log(
      '[Offline] note-aware retrieval base=${baseResults.length} '
      'noteMatches=${noteMatches.length} graph=${expanded.length} '
      'total=${result.length}',
    );
    return result;
  }

  Future<List<SourceEvidence>> _loadNoteEvidence({
    bool logEmbeddingFallback = false,
  }) async {
    final notes = await _noteRepository.listNotes();
    final evidence = <SourceEvidence>[];
    for (final note in notes) {
      if (note.auditState.wireName == 'rejected') {
        DebugConsole.log('[LocalIndex] note skipped id=${note.id} reason=rejected');
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
            '[LocalEmbedding] note chunk id=${chunk.id} state=keyword_only '
            'reason=no_note_vector_embedding indexFresh=${chunk.isIndexFresh}',
          );
        }
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
          ),
        );
      }
    }
    DebugConsole.log('[LocalIndex] note evidence loaded count=${evidence.length}');
    return evidence;
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
            text: item.text,
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
    final results = <SourceEvidence>[];
    final queryTerms = _terms(query).toSet();
    DebugConsole.log(
      '[LocalGraph] expand start seeds=${seeds.length} '
      'candidates=${candidates.length} queryTerms=${queryTerms.length}',
    );
    for (final seed in seeds) {
      final seedTerms = {
        ...queryTerms,
        ..._terms(seed.text),
        ..._terms(seed.label),
      };
      final seedAcronyms = _acronyms('${seed.text}\n${seed.label}\n$query');
      DebugConsole.log(
        '[LocalGraph] seed source=${seed.id} type=${seed.sourceType.wireName} '
        'terms=${seedTerms.take(12).join(',')} '
        'symbols=${seedAcronyms.take(8).join(',')}',
      );
      for (final candidate in candidates) {
        if (results.length + existing.length >= limit) {
          break;
        }
        if (existingIds.contains(candidate.id) || candidate.id == seed.id) {
          continue;
        }
        final link = _linkReason(
          seed: seed,
          candidate: candidate,
          seedTerms: seedTerms,
          seedAcronyms: seedAcronyms,
        );
        if (link == null) {
          continue;
        }
        existingIds.add(candidate.id);
        results.add(candidate);
        DebugConsole.log(
          '[LocalGraph] link type=${link.type} source=${seed.id} '
          'target=${candidate.id} reason=${link.reason}',
        );
      }
    }
    DebugConsole.log('[LocalGraph] expand result count=${results.length}');
    return results;
  }

  _GraphLink? _linkReason({
    required SourceEvidence seed,
    required SourceEvidence candidate,
    required Set<String> seedTerms,
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

    final definitionKeys = _definitionKeys(candidate.text);
    final definitionOverlap = definitionKeys.intersection(seedTerms);
    if (definitionOverlap.isNotEmpty) {
      return _GraphLink(
        'definition',
        'keys:${definitionOverlap.take(4).join(',')}',
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
    if (_looksLikeFlowchart(candidate.text)) {
      final flowTerms = _terms(candidate.text).toSet();
      final overlap = flowTerms.intersection(seedTerms).length;
      if (overlap >= 1) {
        return _GraphLink('flowchart', 'term_overlap:$overlap');
      }
    }
    if (candidate.sourceType == EvidenceSourceType.tableChunk) {
      final tableTerms = _terms(candidate.text).toSet();
      final overlap = tableTerms.intersection(seedTerms).length;
      if (overlap >= 2 || definitionKeys.intersection(seedTerms).isNotEmpty) {
        return _GraphLink('table_join', 'term_overlap:$overlap');
      }
    }
    final sameNote = seed.id.startsWith('note:') &&
        candidate.id.startsWith('note:') &&
        _noteId(seed.id) == _noteId(candidate.id);
    if (sameNote) {
      return const _GraphLink('same_note', 'azonos_jegyzet');
    }
    final candidateTerms = _terms(candidate.text).toSet();
    final overlap = candidateTerms.intersection(seedTerms).length;
    if (overlap >= 3) {
      return _GraphLink('semantic_keyword', 'term_overlap:$overlap');
    }
    return null;
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
      final wholeContextScore = _contextScore(candidateNormalized, branch.contextTerms);
      for (final unit in candidateUnits) {
        final unitContextScore = _contextScore(unit, branch.contextTerms);
        final contextScore = unitContextScore > wholeContextScore ? unitContextScore : wholeContextScore;
        if (branch.contextTerms.isNotEmpty && contextScore == 0) {
          continue;
        }
        if (!_branchValueMatches(branch, unit)) {
          continue;
        }
        final queryScore = _contextScore(unit, seedTerms.toList(growable: false));
        final branchQueryScore = _contextScore(branch.value, seedTerms.toList(growable: false));
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
          : keyTerms.where((term) => !valueTermSet.contains(term)).toList(growable: false);
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
    if (_containsNormalizedPhrase(candidateNormalized, branch.key) &&
        !_containsNegatedPhrase(candidateNormalized, branch.key)) {
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
    return tokens.any((token) => token == term || (term.length >= 4 && token.contains(term)));
  }

  Set<String> _definitionKeys(String text) {
    final keys = <String>{};
    for (final rawLine in text.split(RegExp(r'\n+'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final delimiter = RegExp(r'\s*(:|=|\|| - | – | — )\s*');
      final match = delimiter.firstMatch(line);
      if (match == null || match.start == 0) {
        continue;
      }
      final head = line.substring(0, match.start).trim();
      final headTerms = _terms(head);
      if (headTerms.isEmpty || headTerms.length > 4) {
        continue;
      }
      keys.addAll(headTerms);
      keys.add(_normalize(head));
    }
    return keys.where((key) => key.length > 2).toSet();
  }

  bool _looksLikeFlowchart(String text) => text.contains('->');

  String? _noteId(String sourceId) {
    final parts = sourceId.split(':');
    return parts.length >= 3 ? parts[1] : null;
  }

  List<String> _terms(String value) {
    return _normalize(value)
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2)
        .toSet()
        .toList(growable: false);
  }

  Set<String> _acronyms(String value) {
    return RegExp(r'\b[A-ZÁÉÍÓÖŐÚÜŰ]{2,}[0-9]*\b')
        .allMatches(value)
        .map((match) => match.group(0)!)
        .toSet();
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

class _GraphLink {
  const _GraphLink(this.type, this.reason);

  final String type;
  final String reason;
}
