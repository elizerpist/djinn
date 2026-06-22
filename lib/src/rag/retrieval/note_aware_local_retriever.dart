import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../../notes/data/note_chunk_builder.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/models/note_document.dart';
import '../../offline/local_vector_search_service.dart';
import '../../offline/offline_search_service.dart';
import '../models/source_evidence.dart';
import 'local_retriever.dart';
import 'note_atom_indexer.dart';

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
      granular: true,
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
              label: _searchLabelFor(item),
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
                atomType: noteById[match.id]!.atomType,
                reasons: noteById[match.id]!.reasons,
                noteTitle: noteById[match.id]!.noteTitle,
                chunkId: noteById[match.id]!.chunkId,
                chunkTitle: noteById[match.id]!.chunkTitle,
                sourceStart: noteById[match.id]!.sourceStart,
                sourceEnd: noteById[match.id]!.sourceEnd,
                fullChunkText: noteById[match.id]!.fullChunkText,
              ),
        ],
      );
      DebugConsole.log(
        '[VectorGraph] note local vector expansion mode=note_vector '
        'candidates=${noteEvidence.length} matches=${noteMatches.length}',
      );
    }
    final primaryNoteScope = _primaryNoteScopeForQuery(trimmed, noteMatches);
    final reasonedNoteMatches = _withDirectReasons(
      query: trimmed,
      evidence: noteMatches,
      primaryNoteScope: primaryNoteScope,
    );
    final combined = _dedupe([...baseResults, ...reasonedNoteMatches]);
    final expanded = _graphExpander.expand(
      query: trimmed,
      seeds: _primaryScopeEvidence(combined, primaryNoteScope),
      candidates: _primaryScopeEvidence(noteEvidence, primaryNoteScope),
      existing: combined,
      limit: _shouldExpandQuery(trimmed)
          ? _graphExpansionLimit(limit, noteEvidence.length)
          : combined.length,
    );
    final reasonedExpanded = _withExpandedReasons(
      expanded,
      primaryNoteScope: primaryNoteScope,
    );
    final result = _pruneCompetingEvidence(
      query: trimmed,
      seeds: _dedupe([...combined, ...reasonedExpanded]),
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
            label: _searchLabelFor(item),
            text: item.searchableText,
          ),
      ],
    );
    final noteSeeds = _pruneCompetingEvidence(
      query: query,
      seeds: [
        for (final match in noteMatches)
          if (noteById[match.id] != null)
            noteById[match.id]!.copyWith(score: match.score),
      ],
    );
    final primaryNoteScope = _primaryNoteScopeForQuery(query, noteSeeds);
    final reasonedNoteSeeds = _withDirectReasons(
      query: query,
      evidence: noteSeeds,
      primaryNoteScope: primaryNoteScope,
    );
    final combined = _dedupe([...baseResults, ...reasonedNoteSeeds]);
    final expanded = _graphExpander.expand(
      query: query,
      seeds: _primaryScopeEvidence(combined, primaryNoteScope),
      candidates: _primaryScopeEvidence(noteEvidence, primaryNoteScope),
      existing: combined,
      limit: _shouldExpandQuery(query)
          ? _graphExpansionLimit(limit, noteEvidence.length)
          : combined.length,
    );
    final reasonedExpanded = _withExpandedReasons(
      expanded,
      primaryNoteScope: primaryNoteScope,
    );
    final result = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([...combined, ...reasonedExpanded]),
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
            label: _searchLabelFor(item),
            text: item.searchableText,
          ),
      ],
    );
    final vectorSeeds = [
      for (final match in vectorMatches)
        if (noteById[match.id] != null)
          noteById[match.id]!.copyWith(score: match.score),
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
    final directSeeds = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([
        ...baseResults,
        ...vectorSeeds,
        ...keywordSeeds,
        ...symbolSeeds,
      ]),
    );
    final primaryNoteScope = _primaryNoteScopeForQuery(query, directSeeds);
    final combined = _dedupe([
      ...baseResults,
      ..._withDirectReasons(
        query: query,
        evidence: directSeeds.where((item) => item.id.startsWith('note:')),
        primaryNoteScope: primaryNoteScope,
      ),
    ]);
    final expanded = _graphExpander.expand(
      query: query,
      seeds: _primaryScopeEvidence(combined, primaryNoteScope),
      candidates: _primaryScopeEvidence(noteEvidence, primaryNoteScope),
      existing: combined,
      limit: _shouldExpandQuery(query)
          ? _graphExpansionLimit(limit, noteEvidence.length)
          : combined.length,
    );
    final reasonedExpanded = _withExpandedReasons(
      expanded,
      primaryNoteScope: primaryNoteScope,
    );
    final result = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([...combined, ...reasonedExpanded]),
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
    final metadataSeeds = _preferDirectMetadataMatches(query, seeds);
    if (metadataSeeds.any((seed) => seed.atomType != null)) {
      return metadataSeeds;
    }
    final scope = _QueryScope.from(query).forEvidence(metadataSeeds);
    final scopedSeeds = _filterByQueryScope(scope, metadataSeeds);
    if (scopedSeeds.length < 2) {
      return scopedSeeds;
    }
    final queryTerms = _simpleTerms(query);
    if (queryTerms.isEmpty) {
      return scopedSeeds;
    }
    final groups = <String, List<SourceEvidence>>{};
    for (final seed in scopedSeeds) {
      final group = _competingGroupId(seed);
      if (group != null) {
        groups.putIfAbsent(group, () => []).add(seed);
      }
    }
    if (groups.isEmpty) {
      return scopedSeeds;
    }
    final removedIds = <String>{};
    for (final entry in groups.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      if (scope.keepTableCompanions &&
          entry.value.any(
            (seed) => seed.sourceType == EvidenceSourceType.tableChunk,
          )) {
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
      return scopedSeeds;
    }
    return scopedSeeds
        .where((seed) => !removedIds.contains(seed.id))
        .toList(growable: false);
  }

  String? _primaryNoteScopeForQuery(
    String query,
    Iterable<SourceEvidence> evidence,
  ) {
    final items = evidence
        .where((item) => _evidenceNoteScopeId(item.id) != null)
        .toList(growable: false);
    if (items.isEmpty) {
      return null;
    }
    final queryTerms = _simpleTerms(query);
    final scores =
        <String, ({int titleCoverage, int matches, int firstIndex})>{};
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      final scope = _evidenceNoteScopeId(item.id);
      if (scope == null) {
        continue;
      }
      final titleTerms = _simpleTerms(item.noteTitle ?? '');
      final titleCoverage = titleTerms.intersection(queryTerms).length;
      final previous = scores[scope];
      if (previous == null) {
        scores[scope] = (
          titleCoverage: titleCoverage,
          matches: 1,
          firstIndex: index,
        );
      } else {
        scores[scope] = (
          titleCoverage: previous.titleCoverage > titleCoverage
              ? previous.titleCoverage
              : titleCoverage,
          matches: previous.matches + 1,
          firstIndex: previous.firstIndex,
        );
      }
    }
    if (scores.isEmpty) {
      return null;
    }
    final ranked = scores.entries.toList(growable: false)
      ..sort((a, b) {
        final title = b.value.titleCoverage.compareTo(a.value.titleCoverage);
        if (title != 0) {
          return title;
        }
        final matches = b.value.matches.compareTo(a.value.matches);
        if (matches != 0) {
          return matches;
        }
        return a.value.firstIndex.compareTo(b.value.firstIndex);
      });
    return ranked.first.key;
  }

  List<SourceEvidence> _primaryScopeEvidence(
    Iterable<SourceEvidence> evidence,
    String? primaryNoteScope,
  ) {
    if (primaryNoteScope == null) {
      return const [];
    }
    return evidence
        .where((item) => _evidenceNoteScopeId(item.id) == primaryNoteScope)
        .toList(growable: false);
  }

  bool _shouldExpandQuery(String query) {
    return _simpleTerms(query).length >= 2;
  }

  List<SourceEvidence> _withDirectReasons({
    required String query,
    required Iterable<SourceEvidence> evidence,
    required String? primaryNoteScope,
  }) {
    return [
      for (final item in evidence) _withReasons(query, item, primaryNoteScope),
    ];
  }

  List<SourceEvidence> _withExpandedReasons(
    Iterable<SourceEvidence> evidence, {
    required String? primaryNoteScope,
  }) {
    return [
      for (final item in evidence)
        _mergeReasons(item, [
          if (_evidenceNoteScopeId(item.id) == primaryNoteScope)
            NoteEvidenceReason.noteScope,
          if (item.sourceType == EvidenceSourceType.flowchartEdge)
            NoteEvidenceReason.flowchartBranch,
          NoteEvidenceReason.processLink,
        ]),
    ];
  }

  SourceEvidence _withReasons(
    String query,
    SourceEvidence item,
    String? primaryNoteScope,
  ) {
    if (!item.id.startsWith('note:')) {
      return item;
    }
    final scope = _evidenceNoteScopeId(item.id);
    final reasons = <NoteEvidenceReason>[
      NoteEvidenceReason.directQuery,
      if (scope != null && scope == primaryNoteScope)
        NoteEvidenceReason.noteScope,
      if (scope != null &&
          primaryNoteScope != null &&
          scope != primaryNoteScope)
        NoteEvidenceReason.externalDirect,
      if (_titleMatchesQuery(query, item)) NoteEvidenceReason.chunkTitle,
      ..._structuralReasons(item),
    ];
    if (reasons.isEmpty) {
      reasons.add(NoteEvidenceReason.directQuery);
    }
    return _mergeReasons(item, reasons);
  }

  bool _titleMatchesQuery(String query, SourceEvidence item) {
    final title = item.chunkTitle?.trim();
    if (title == null || title.isEmpty) {
      return false;
    }
    final titleTerms = _simpleTerms(title);
    if (titleTerms.isEmpty) {
      return false;
    }
    final queryTerms = _simpleTerms(query);
    return titleTerms.any(queryTerms.contains);
  }

  List<NoteEvidenceReason> _structuralReasons(SourceEvidence item) {
    return switch (item.atomType) {
      NoteEvidenceAtomType.listItem => const [NoteEvidenceReason.listItemMatch],
      NoteEvidenceAtomType.tableCell => const [
        NoteEvidenceReason.tableColumn,
        NoteEvidenceReason.tableCell,
      ],
      NoteEvidenceAtomType.tableRow => const [NoteEvidenceReason.tableCell],
      NoteEvidenceAtomType.flowchartEdge => const [
        NoteEvidenceReason.flowchartBranch,
      ],
      NoteEvidenceAtomType.flowchartNode => const [
        NoteEvidenceReason.flowchartBranch,
      ],
      NoteEvidenceAtomType.textSentence || null => const [],
    };
  }

  SourceEvidence _mergeReasons(
    SourceEvidence item,
    Iterable<NoteEvidenceReason> reasons,
  ) {
    final merged = <NoteEvidenceReason>{...item.reasons, ...reasons};
    return item.copyWith(reasons: merged.toList(growable: false));
  }

  List<SourceEvidence> _preferDirectMetadataMatches(
    String query,
    List<SourceEvidence> seeds,
  ) {
    final queryTerms = _simpleTerms(query);
    if (queryTerms.isEmpty || seeds.length < 2) {
      return seeds;
    }
    final matched = seeds
        .where((seed) => _coversSimpleTerms(seed.searchText ?? '', queryTerms))
        .toList(growable: false);
    if (matched.isEmpty) {
      return seeds;
    }
    final matchedIds = matched.map((seed) => seed.id).toSet();
    var prunedNoteEvidence = false;
    final filtered = <SourceEvidence>[];
    for (final seed in seeds) {
      if (!seed.id.startsWith('note:') || matchedIds.contains(seed.id)) {
        filtered.add(seed);
        continue;
      }
      prunedNoteEvidence = true;
      DebugConsole.log(
        '[LocalIndex] evidence pruned id=${seed.id} '
        'reason=direct_metadata_match_preferred',
      );
    }
    return prunedNoteEvidence ? filtered : seeds;
  }

  bool _coversSimpleTerms(String value, Set<String> terms) {
    if (terms.isEmpty) {
      return true;
    }
    final normalized = _simpleNormalize(value);
    if (normalized.isEmpty) {
      return false;
    }
    return terms.every((term) => _simpleContainsTerm(normalized, term));
  }

  List<SourceEvidence> _filterByQueryScope(
    _QueryScope scope,
    List<SourceEvidence> seeds,
  ) {
    final noteScopes = seeds
        .map((seed) => _evidenceNoteScopeId(seed.id))
        .whereType<String>()
        .toSet();
    final hasMultipleNoteScopes = noteScopes.length > 1;
    final needsMultiNoteTopicGate =
        !scope.hasDefinitionIntent &&
        !scope.hasFacetIntent &&
        hasMultipleNoteScopes &&
        scope.topicTerms.length >= 3;
    if (!scope.hasFacetIntent &&
        scope.allowDefinitionExpansion &&
        !needsMultiNoteTopicGate) {
      return seeds;
    }
    return seeds
        .where((seed) {
          if (scope.hasFacetIntent) {
            if (!_isFacetEvidence(scope, seed)) {
              DebugConsole.log(
                '[LocalIndex] evidence pruned id=${seed.id} '
                'reason=query_facet_scope',
              );
              return false;
            }
            if (scope.topicTerms.isNotEmpty &&
                !_coversScopeTerms(seed.searchableText, scope.topicTerms)) {
              DebugConsole.log(
                '[LocalIndex] evidence pruned id=${seed.id} '
                'reason=query_topic_facet_mismatch',
              );
              return false;
            }
          }
          if (!scope.allowDefinitionExpansion && _isDefinitionEvidence(seed)) {
            DebugConsole.log(
              '[LocalIndex] evidence pruned id=${seed.id} '
              'reason=query_scope_definition_suppressed',
            );
            return false;
          }
          if (!scope.hasDefinitionIntent &&
              !scope.hasFacetIntent &&
              needsMultiNoteTopicGate &&
              _queryTopicCoverage(seed.searchableText, scope.topicTerms) < 2) {
            DebugConsole.log(
              '[LocalIndex] evidence pruned id=${seed.id} '
              'reason=query_topic_undercovered',
            );
            return false;
          }
          final narrowTerm = scope.primaryNarrowTerm;
          if (scope.isNarrowState &&
              narrowTerm != null &&
              (seed.sourceType == EvidenceSourceType.flowchartNode ||
                  seed.sourceType == EvidenceSourceType.flowchartEdge) &&
              !_coversScopeTerms(seed.searchableText, {narrowTerm})) {
            DebugConsole.log(
              '[LocalIndex] evidence pruned id=${seed.id} '
              'reason=query_primary_state_mismatch term=$narrowTerm',
            );
            return false;
          }
          if (_flowchartBranchConflictsWithQuery(seed, scope)) {
            DebugConsole.log(
              '[LocalIndex] evidence pruned id=${seed.id} '
              'reason=query_branch_polarity_mismatch',
            );
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  String? _evidenceNoteScopeId(String id) {
    if (!id.startsWith('note:')) {
      return null;
    }
    final noteEnd = id.indexOf(':', 'note:'.length);
    if (noteEnd <= 'note:'.length) {
      return null;
    }
    return id.substring(0, noteEnd);
  }

  bool _isFacetEvidence(_QueryScope scope, SourceEvidence evidence) {
    if (evidence.sourceType == EvidenceSourceType.tableChunk) {
      return true;
    }
    final normalized = _scopeNormalize(evidence.searchableText);
    if (normalized.contains('table rule')) {
      return true;
    }
    return scope.facetTerms.any((term) => _scopeContainsTerm(normalized, term));
  }

  bool _isDefinitionEvidence(SourceEvidence evidence) {
    if (evidence.sourceType == EvidenceSourceType.tableChunk ||
        evidence.sourceType == EvidenceSourceType.flowchartNode ||
        evidence.sourceType == EvidenceSourceType.flowchartEdge) {
      return false;
    }
    final metadata = _scopeNormalize(evidence.searchText ?? '');
    if (metadata.contains('definition')) {
      return true;
    }
    final normalized = _scopeNormalize(evidence.text);
    return evidence.text.contains('<') ||
        evidence.text.contains('=') ||
        normalized.contains('akkor all fenn') ||
        normalized.contains('definicio') ||
        normalized.contains('jelentese');
  }

  bool _flowchartBranchConflictsWithQuery(
    SourceEvidence evidence,
    _QueryScope scope,
  ) {
    if (!scope.isNarrowState ||
        evidence.sourceType != EvidenceSourceType.flowchartEdge) {
      return false;
    }
    final branches = _branchSignalsFromText(evidence.text);
    if (branches.isEmpty) {
      return false;
    }
    final hasNegativeRequest = scope.terms.any(
      (term) => term == 'nem' || term == 'no',
    );
    final hasPositiveRequest = scope.terms.any(
      (term) => term == 'igen' || term == 'yes',
    );
    for (final branch in branches) {
      if (branch.polarity == null ||
          !_queryTargetsBranchCondition(branch, scope)) {
        continue;
      }
      if (hasNegativeRequest) {
        return branch.polarity == 'positive';
      }
      if (hasPositiveRequest) {
        return branch.polarity == 'negative';
      }
    }
    return false;
  }

  bool _queryTargetsBranchCondition(_BranchSignal branch, _QueryScope scope) {
    final conditionTerms = {
      ..._scopeTerms(branch.key),
      ...branch.valueTerms,
      ...branch.contextTerms,
    };
    if (conditionTerms.isEmpty) {
      return false;
    }
    final queryConditionTerms = scope.terms
        .where((term) => !_isQuestionTerm(term))
        .where((term) => !_isBranchValueTerm(term))
        .where((term) => !scope.facetTerms.contains(term));
    return queryConditionTerms.any(
      (term) => conditionTerms.any((condition) => _termsClose(term, condition)),
    );
  }

  bool _coversScopeTerms(String value, Set<String> terms) {
    final normalized = _scopeNormalize(value);
    return terms.every((term) => _scopeContainsTerm(normalized, term));
  }

  int _queryTopicCoverage(String value, Set<String> terms) {
    final normalized = _scopeNormalize(value);
    return terms
        .where((term) => !_isQuestionTerm(term))
        .where((term) => _scopeContainsTerm(normalized, term))
        .length;
  }

  String? _competingGroupId(SourceEvidence evidence) {
    final flowchartGroup = _flowchartBranchGroupId(evidence);
    if (flowchartGroup != null) {
      return flowchartGroup;
    }
    final id = evidence.id;
    for (final marker in const [':row-', ':part-']) {
      final index = id.lastIndexOf(marker);
      if (index > 0) {
        return id.substring(0, index);
      }
    }
    return null;
  }

  String? _flowchartBranchGroupId(SourceEvidence evidence) {
    if (evidence.sourceType != EvidenceSourceType.flowchartEdge) {
      return null;
    }
    final blockGroup = _flowchartBlockGroupId(evidence.id);
    if (blockGroup == null) {
      return null;
    }
    final branches = _branchSignalsFromText(evidence.text);
    if (branches.length != 1 || branches.single.polarity == null) {
      return null;
    }
    return '$blockGroup:branch-${branches.single.key}';
  }

  String? _flowchartBlockGroupId(String id) {
    final edgeIndex = id.lastIndexOf(':edge-');
    if (edgeIndex > 0) {
      return id.substring(0, edgeIndex);
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
    final primaryNoteScope = _primaryNoteScopeForQuery(query, noteMatches);
    final reasonedNoteMatches = _withDirectReasons(
      query: query,
      evidence: noteMatches,
      primaryNoteScope: primaryNoteScope,
    );
    final combined = _dedupe([...baseResults, ...reasonedNoteMatches]);
    final expanded = _graphExpander.expand(
      query: query,
      seeds: _primaryScopeEvidence(combined, primaryNoteScope),
      candidates: _primaryScopeEvidence(noteEvidence, primaryNoteScope),
      existing: combined,
      limit: _shouldExpandQuery(query) ? limit : combined.length,
    );
    final reasonedExpanded = _withExpandedReasons(
      expanded,
      primaryNoteScope: primaryNoteScope,
    );
    final result = _pruneCompetingEvidence(
      query: query,
      seeds: _dedupe([...combined, ...reasonedExpanded]),
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
    bool granular = true,
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
      }
      if (granular) {
        evidence.addAll(
          const NoteAtomIndexer().buildEvidence(
            noteId: note.id,
            noteTitle: note.title,
            document: note.document,
          ),
        );
      } else {
        for (final chunk in chunks) {
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
              noteTitle: chunk.noteTitle,
              chunkId: chunk.blockId,
              fullChunkText: chunk.text,
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

  // Kept as a legacy fallback shape while the active note path uses
  // NoteAtomIndexer for spec-compliant atom evidence.
  // ignore: unused_element
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
              ? units[i].text
              : '$title: ${units[i].text}',
          label: units.length == 1
              ? baseLabel
              : '$baseLabel · részlet ${i + 1}',
          validationState: state,
          documentId: chunk.noteId,
          searchText: _joinSearchText([
            chunk.searchText,
            _textRangeSearchText(block, units[i]),
          ]),
        ),
    ];
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
    final unitStart = start + leading;
    final unitEnd = end - trailing;
    units.add(_TextUnit(text: trimmed, start: unitStart, end: unitEnd));
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

  List<SourceEvidence> _tableRowEvidence(
    NoteBlock block,
    NoteChunkViewModel chunk,
    String baseLabel,
    ValidationState state,
  ) {
    final rows = [
      for (var index = 0; index < block.rows.length; index += 1)
        if (block.rows[index].any((cell) => cell.trim().isNotEmpty))
          _IndexedTableRow(index: index, row: block.rows[index]),
    ];
    if (rows.isEmpty) {
      return const [];
    }
    final firstRow = rows.first.row;
    final hasHeader =
        rows.length > 1 &&
        firstRow.every((cell) => cell.trim().isNotEmpty) &&
        firstRow.join(' ').length < 80;
    final headers = hasHeader ? firstRow : const <String>[];
    final start = hasHeader ? 1 : 0;
    final title = block.title?.trim();
    final results = <SourceEvidence>[];
    for (var i = start; i < rows.length; i += 1) {
      final indexedRow = rows[i];
      final row = indexedRow.row;
      final rowIndex = indexedRow.index;
      final definitionCells = _independentDefinitionCells(row);
      if (definitionCells.isNotEmpty) {
        for (
          var logicalIndex = 0;
          logicalIndex < definitionCells.length;
          logicalIndex += 1
        ) {
          final definitionCell = definitionCells[logicalIndex];
          final cell = definitionCell.text.trim();
          if (cell.isEmpty) {
            continue;
          }
          final header = _headerForDefinitionCell(
            headers,
            definitionCell.columnIndex,
          );
          results.add(
            SourceEvidence(
              id: 'note:${chunk.noteId}:${chunk.blockId}:row-$rowIndex-cell-$logicalIndex',
              sourceType: EvidenceSourceType.tableChunk,
              text: _tableCellText(cell: cell, header: header, title: title),
              label:
                  '$baseLabel · sor ${rowIndex + 1} · cella ${definitionCell.columnIndex + 1}',
              validationState: state,
              documentId: chunk.noteId,
              searchText: _joinSearchText([
                chunk.searchText,
                _tableScopedSearchText(
                  block,
                  rowIndex: rowIndex,
                  columnIndex: definitionCell.columnIndex,
                ),
              ]),
            ),
          );
        }
      } else {
        results.add(
          SourceEvidence(
            id: 'note:${chunk.noteId}:${chunk.blockId}:row-$rowIndex',
            sourceType: EvidenceSourceType.tableChunk,
            text: _tableRowText(row: row, headers: headers, title: title),
            label: '$baseLabel · sor ${rowIndex + 1}',
            validationState: state,
            documentId: chunk.noteId,
            searchText: _joinSearchText([
              chunk.searchText,
              _tableScopedSearchText(block, rowIndex: rowIndex),
            ]),
          ),
        );
      }
    }
    return results;
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

  List<_DefinitionCell> _independentDefinitionCells(List<String> row) {
    final logicalCells = <String>[];
    final definitionCells = <_DefinitionCell>[];
    for (var columnIndex = 0; columnIndex < row.length; columnIndex += 1) {
      final cell = row[columnIndex].trim();
      if (cell.isEmpty) {
        continue;
      }
      final split = _splitPipePackedDefinitions(cell);
      final parts = split.length > 1 ? split : [cell];
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        logicalCells.add(trimmed);
        definitionCells.add(
          _DefinitionCell(text: trimmed, columnIndex: columnIndex),
        );
      }
    }
    if (logicalCells.length > 1 &&
        logicalCells.every(_looksLikeInlineDefinition)) {
      return definitionCells;
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
            searchText: _joinSearchText([
              chunk.searchText,
              block.listItems[i].searchMetadataText,
            ]),
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
          searchText: _joinSearchText([
            chunk.searchText,
            _flowchartScopedSearchText(
              block,
              kind: NoteTagTargetKind.flowchartNode,
              elementId: node.id,
            ),
          ]),
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
          searchText: _joinSearchText([
            chunk.searchText,
            _flowchartScopedSearchText(
              block,
              kind: NoteTagTargetKind.flowchartEdge,
              elementId: edge.id,
            ),
          ]),
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
            label: _searchLabelFor(item),
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

  String _searchLabelFor(SourceEvidence item) {
    if (item.atomType == null) {
      return item.label;
    }
    return item.chunkTitle?.trim() ?? '';
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

  String _tagSearchText(Iterable<NoteKnowledgeTag> tags) {
    final values = <String>{};
    for (final tag in tags) {
      final metadata = tag.metadataText.trim();
      if (metadata.isNotEmpty) {
        values.add(metadata);
      }
    }
    return values.join('\n').trim();
  }

  String _joinSearchText(List<String?> values) {
    return values
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join('\n')
        .trim();
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

class _DefinitionCell {
  const _DefinitionCell({required this.text, required this.columnIndex});

  final String text;
  final int columnIndex;
}

List<_BranchSignal> _branchSignalsFromText(String text) {
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
    final key = _scopeNormalize(keyText);
    final value = _scopeNormalize(label);
    if (key.isEmpty || value.isEmpty) {
      continue;
    }
    final polarity = _branchPolarityFor(value);
    final keyTerms = _scopeTermList(keyText);
    final valueTerms = polarity == null
        ? _scopeTermList(label)
        : _branchConditionValueTerms(keyTerms);
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

String? _branchPolarityFor(String normalizedValue) {
  if (normalizedValue == 'igen' || normalizedValue == 'yes') {
    return 'positive';
  }
  if (normalizedValue == 'nem' || normalizedValue == 'no') {
    return 'negative';
  }
  return null;
}

List<String> _branchConditionValueTerms(List<String> keyTerms) {
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

class _QueryScope {
  _QueryScope({
    required this.terms,
    required this.orderedTerms,
    required this.facetTerms,
    required this.topicTerms,
    required this.primaryNarrowTerm,
    required this.hasSymbol,
    required this.hasDefinitionIntent,
    required this.isNarrowState,
  });

  factory _QueryScope.from(String query) {
    final orderedTerms = _scopeTermList(query);
    final terms = orderedTerms.toSet();
    final facetTerms = terms.where(_isFacetTerm).toSet();
    final definitionIntent = _hasDefinitionIntent(query, terms);
    final hasSymbol = RegExp(r'\b[A-Z]{2,}[0-9]*\b').hasMatch(query);
    final isNarrowState = terms.any(
      (term) => const {'igen', 'nem', 'yes', 'no'}.contains(term),
    );
    final topicTerms = terms
        .where((term) => !facetTerms.contains(term))
        .where((term) => !_isQuestionTerm(term))
        .toSet();
    return _QueryScope(
      terms: terms,
      orderedTerms: orderedTerms,
      facetTerms: facetTerms,
      topicTerms: topicTerms,
      primaryNarrowTerm: _standaloneNarrowTerm(orderedTerms, facetTerms),
      hasSymbol: hasSymbol,
      hasDefinitionIntent: definitionIntent,
      isNarrowState: isNarrowState,
    );
  }

  _QueryScope forEvidence(List<SourceEvidence> evidence) {
    if (hasFacetIntent || hasDefinitionIntent || hasSymbol || terms.isEmpty) {
      return this;
    }
    final narrowTerm =
        primaryNarrowTerm ??
        _evidenceSpecificNarrowTerm(evidence, orderedTerms, facetTerms);
    final hasStateLikeSeed = evidence.any((item) {
      if (item.sourceType != EvidenceSourceType.tableChunk &&
          item.sourceType != EvidenceSourceType.flowchartNode &&
          item.sourceType != EvidenceSourceType.flowchartEdge) {
        return false;
      }
      return narrowTerm != null &&
          _coversScopeTerm(item.searchableText, narrowTerm);
    });
    if (!hasStateLikeSeed ||
        (isNarrowState && primaryNarrowTerm == narrowTerm)) {
      return this;
    }
    return _QueryScope(
      terms: terms,
      orderedTerms: orderedTerms,
      facetTerms: facetTerms,
      topicTerms: topicTerms,
      primaryNarrowTerm: narrowTerm,
      hasSymbol: hasSymbol,
      hasDefinitionIntent: hasDefinitionIntent,
      isNarrowState: true,
    );
  }

  final Set<String> terms;
  final List<String> orderedTerms;
  final Set<String> facetTerms;
  final Set<String> topicTerms;
  final String? primaryNarrowTerm;
  final bool hasSymbol;
  final bool hasDefinitionIntent;
  final bool isNarrowState;

  bool get hasFacetIntent => facetTerms.isNotEmpty;

  bool get allowDefinitionExpansion =>
      !hasFacetIntent && (!isNarrowState || hasDefinitionIntent || hasSymbol);

  bool get allowSymbolExpansion => hasSymbol || allowDefinitionExpansion;

  bool get keepTableCompanions =>
      hasFacetIntent || (isNarrowState && terms.length <= 3);

  bool branchSignalAllowed(_BranchSignal branch) {
    if (!isNarrowState || terms.isEmpty) {
      return true;
    }
    final branchTerms = {
      ..._scopeTerms(branch.key),
      ..._scopeTerms(branch.value),
      ...branch.valueTerms,
      ...branch.contextTerms,
    };
    return terms.any(
      (term) => branchTerms.any((branchTerm) => _termsClose(term, branchTerm)),
    );
  }
}

Set<String> _scopeTerms(String value) {
  return _scopeTermList(value).toSet();
}

List<String> _scopeTermList(String value) {
  return _scopeNormalize(value)
      .split(RegExp(r'\s+'))
      .where((term) => term.length > 2)
      .toList(growable: false);
}

String _scopeNormalize(String value) {
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

bool _isFacetTerm(String term) {
  return term.startsWith('terap') ||
      term.startsWith('kezeles') ||
      term.startsWith('teendo') ||
      term.startsWith('szabaly') ||
      term == 'rule';
}

bool _isQuestionTerm(String term) {
  return const {
    'milyen',
    'mikor',
    'hogyan',
    'mennyi',
    'miert',
    'azert',
    'eseten',
    'soran',
  }.contains(term);
}

bool _hasDefinitionIntent(String query, Set<String> terms) {
  final normalized = _scopeNormalize(query);
  return terms.contains('definicio') ||
      terms.contains('jelentes') ||
      terms.contains('jelentese') ||
      normalized.startsWith('mi ') ||
      normalized.startsWith('mi az ') ||
      normalized.startsWith('mit jelent');
}

bool _scopeContainsTerm(String normalized, String term) {
  final tokens = normalized.split(RegExp(r'\s+'));
  return tokens.any((token) => _termsClose(token, term));
}

bool _coversScopeTerm(String value, String term) {
  return _scopeContainsTerm(_scopeNormalize(value), term);
}

bool _coversAnyScopeTerm(String value, Set<String> terms) {
  if (terms.isEmpty) {
    return false;
  }
  final normalized = _scopeNormalize(value);
  return terms.any((term) => _scopeContainsTerm(normalized, term));
}

bool _coversAllScopeTerms(String value, Set<String> terms) {
  if (terms.isEmpty) {
    return false;
  }
  final normalized = _scopeNormalize(value);
  return terms.every((term) => _scopeContainsTerm(normalized, term));
}

String? _standaloneNarrowTerm(List<String> terms, Set<String> facetTerms) {
  final candidates = terms
      .where((term) => !facetTerms.contains(term))
      .where((term) => !_isQuestionTerm(term))
      .where((term) => !_isBranchValueTerm(term))
      .toList(growable: false);
  if (candidates.length == 1) {
    return candidates.single;
  }
  return null;
}

String? _evidenceSpecificNarrowTerm(
  List<SourceEvidence> evidence,
  List<String> terms,
  Set<String> facetTerms,
) {
  final candidates = terms
      .where((term) => !facetTerms.contains(term))
      .where((term) => !_isQuestionTerm(term))
      .where((term) => !_isBranchValueTerm(term))
      .toList(growable: false);
  if (candidates.length <= 1) {
    return candidates.isEmpty ? null : candidates.single;
  }
  final stateLikeEvidence = evidence
      .where(
        (item) =>
            item.sourceType == EvidenceSourceType.tableChunk ||
            item.sourceType == EvidenceSourceType.flowchartNode ||
            item.sourceType == EvidenceSourceType.flowchartEdge,
      )
      .toList(growable: false);
  if (stateLikeEvidence.isEmpty) {
    return null;
  }
  final explicitStateTerm = _shortFlowchartStateTerm(
    stateLikeEvidence,
    candidates,
  );
  if (explicitStateTerm != null) {
    return explicitStateTerm;
  }
  final counts = <String, int>{};
  for (final term in candidates) {
    counts[term] = stateLikeEvidence
        .where((item) => _coversScopeTerm(item.searchableText, term))
        .length;
  }
  final presentCounts = counts.entries.where((entry) => entry.value > 0);
  if (presentCounts.length < 2) {
    return null;
  }
  final maxCount = presentCounts
      .map((entry) => entry.value)
      .reduce((first, second) => first > second ? first : second);
  final minCount = presentCounts
      .map((entry) => entry.value)
      .reduce((first, second) => first < second ? first : second);
  if (minCount >= maxCount) {
    return null;
  }
  for (final term in candidates) {
    if (counts[term] == minCount) {
      return term;
    }
  }
  return null;
}

String? _shortFlowchartStateTerm(
  List<SourceEvidence> evidence,
  List<String> candidates,
) {
  final candidateSet = candidates.toSet();
  for (final item in evidence) {
    if (item.sourceType != EvidenceSourceType.flowchartNode) {
      continue;
    }
    final nodeTerms = _scopeTermList(item.text)
        .where((term) => !_isQuestionTerm(term))
        .where((term) => !_isBranchValueTerm(term))
        .toSet();
    if (nodeTerms.length != 1) {
      continue;
    }
    final nodeTerm = nodeTerms.single;
    for (final candidate in candidateSet) {
      if (_termsClose(candidate, nodeTerm)) {
        return candidate;
      }
    }
  }
  return null;
}

bool _isBranchValueTerm(String term) {
  return const {'igen', 'nem', 'yes', 'no'}.contains(term);
}

bool _termsClose(String first, String second) {
  if (first == second) {
    return true;
  }
  if (first.length < 4 || second.length < 4) {
    return false;
  }
  return first.contains(second) || second.contains(first);
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
    final scope = _QueryScope.from(query).forEvidence(seeds);
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
      final seedTerms = _terms(seed.searchableText).toSet();
      final seedAcronyms = _acronyms(
        scope.hasSymbol
            ? '${seed.searchableText}\n$query'
            : seed.searchableText,
      );
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
          scope: scope,
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
    required _QueryScope scope,
  }) {
    if (scope.keepTableCompanions &&
        seed.sourceType == EvidenceSourceType.tableChunk &&
        candidate.sourceType == EvidenceSourceType.tableChunk &&
        _sameTableRowGroup(seed.id, candidate.id)) {
      return _GraphLink('table_companion', 'same_table_scope');
    }
    final branchLink = _branchValueLink(
      seed: seed,
      candidate: candidate,
      seedTerms: seedTerms,
      scope: scope,
    );
    if (branchLink != null) {
      return branchLink;
    }
    final reverseBranchLink = _branchValueLink(
      seed: candidate,
      candidate: seed,
      seedTerms: seedTerms,
      scope: scope,
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
      if (scope.allowSymbolExpansion &&
          definitionPattern.hasMatch(candidateText)) {
        return _GraphLink('definition', 'symbol:$acronym');
      }
    }
    final candidateTerms = _terms(candidate.text).toSet();
    final queryOverlap = candidateTerms.intersection(queryTerms);
    if (scope.allowDefinitionExpansion &&
        queryOverlap.length >= 2 &&
        _looksLikeDefinitionStatement(candidate.text)) {
      return _GraphLink(
        'definition',
        'query_terms:${queryOverlap.take(4).join(',')}',
      );
    }
    final definitionKeys = _definitionKeys(candidate.text);
    final definitionOverlap = definitionKeys.intersection(seedTerms);
    if (scope.allowDefinitionExpansion && definitionOverlap.isNotEmpty) {
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
    if (_sameNoteScope(seed.id, candidate.id) &&
        queryTerms.isNotEmpty &&
        _coversAnyScopeTerm(seed.text, queryTerms) &&
        _coversAnyScopeTerm(candidate.text, queryTerms) &&
        !scope.isNarrowState) {
      return _GraphLink('local_context', 'query_local_scope');
    }
    if (_looksLikeFlowchart(candidate.text)) {
      if (scope.isNarrowState &&
          scope.terms.isNotEmpty &&
          !_coversAllScopeTerms(candidate.text, scope.terms)) {
        DebugConsole.log(
          '[LocalGraph] link skipped source=${seed.id} target=${candidate.id} '
          'reason=narrow_flowchart_scope',
        );
        return null;
      }
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
      if (scope.isNarrowState &&
          scope.terms.isNotEmpty &&
          !_coversAllScopeTerms(candidate.text, scope.terms)) {
        DebugConsole.log(
          '[LocalGraph] link skipped source=${seed.id} target=${candidate.id} '
          'reason=narrow_table_scope',
        );
        return null;
      }
      if (overlap >= 2 || definitionKeys.intersection(seedTerms).isNotEmpty) {
        return _GraphLink('table_join', 'term_overlap:$overlap');
      }
    }
    final overlap = candidateTerms.intersection(seedTerms).length;
    if (scope.isNarrowState &&
        scope.terms.isNotEmpty &&
        !_coversAllScopeTerms(candidate.text, scope.terms)) {
      return null;
    }
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

  bool _sameNoteScope(String a, String b) {
    final first = _noteScopeId(a);
    final second = _noteScopeId(b);
    return first != null && first == second;
  }

  String? _noteScopeId(String id) {
    if (!id.startsWith('note:')) {
      return null;
    }
    final noteEnd = id.indexOf(':', 'note:'.length);
    if (noteEnd <= 'note:'.length) {
      return null;
    }
    return id.substring(0, noteEnd);
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
    required _QueryScope scope,
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
      if (!scope.branchSignalAllowed(branch)) {
        continue;
      }
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
    if (_containsBranchNegativeMarker(candidateNormalized)) {
      return false;
    }
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

  bool _containsBranchNegativeMarker(String candidateNormalized) {
    final tokens = candidateNormalized.split(RegExp(r'\s+'));
    return tokens.any((token) => token == 'nem' || token == 'no');
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
    if (type == 'table_companion') {
      return 0;
    }
    if (type == 'definition' && reason.startsWith('symbol:')) {
      return 1;
    }
    if (type == 'definition' && reason.startsWith('query_terms:')) {
      return 2;
    }
    return switch (type) {
      'definition' => 3,
      'branch_value' => 4,
      'table_join' => 5,
      'semantic_keyword' => 6,
      'flowchart' => 7,
      _ => 8,
    };
  }
}
