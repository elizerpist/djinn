import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/openai/openai_client.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';
import 'package:djinn/src/rag/verification/citation_verifier.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  setUp(DebugConsole.clear);

  test(
    'returns insufficient evidence before generation when retrieval is empty',
    () async {
      final service = LocalAnswerService(
        openAiClient: FakeOpenAiClient(),
        retriever: MemoryLocalRetriever(const []),
        citationVerifier: CitationVerifier(),
        loadSettings: () async => AppSettings.defaults(),
        hasApiKey: () async => true,
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer('Mi a teendo?');

      expect(result.status, 'insufficient_evidence');
      expect(result.refusalReason, 'insufficient_evidence');
      expect(DebugConsole.allText, contains('[Chat/RAG] answer start'));
      expect(
        DebugConsole.allText,
        contains('[Chat/RAG] refused reason=insufficient_evidence'),
      );
    },
  );

  test('returns grounded answer with validation warning', () async {
    final service = LocalAnswerService(
      openAiClient: FakeOpenAiClient(answerText: 'Kovesd az algoritmust.'),
      retriever: MemoryLocalRetriever(const [
        SourceEvidence(
          id: 'node-1',
          sourceType: EvidenceSourceType.flowchartNode,
          text: 'Algoritmus node',
          label: 'Nem validált flowchart',
          validationState: ValidationState.unreviewed,
          score: 0.95,
          atomType: NoteEvidenceAtomType.flowchartNode,
          fullChunkText: 'Algoritmus node\nKapcsolt teljes chunk',
          reasons: [
            NoteEvidenceReason.directQuery,
            NoteEvidenceReason.flowchartBranch,
          ],
        ),
      ]),
      citationVerifier: CitationVerifier(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('Mi a teendo?');

    expect(result.status, 'grounded');
    expect(result.hasValidationWarning, isTrue);
    expect(result.citations.single.sourceId, 'node-1');
    expect(result.citations.single.sourceType, 'flowchart_node');
    expect(result.citations.single.atomType, 'flowchart_node');
    expect(result.citations.single.reasons, [
      'direct_query',
      'flowchart_branch',
    ]);
    expect(
      result.citations.single.fullChunkText,
      'Algoritmus node\nKapcsolt teljes chunk',
    );
    expect(DebugConsole.allText, contains('[Chat/RAG] retrieved count=1'));
    expect(
      DebugConsole.allText,
      contains('[Chat/RAG] answer language=auto default=hu'),
    );
    expect(DebugConsole.allText, contains('[Chat/RAG] grounded citations=1'));
  });

  test(
    'removes unsupported acronym explanations from grounded answers',
    () async {
      final service = LocalAnswerService(
        openAiClient: FakeOpenAiClient(
          answerText:
              'Légzési elégtelenségről akkor beszélünk, amikor a DO2 '
              '(oxigénszállítás) kisebb, mint a VO2 (oxigénfogyasztás).',
        ),
        retriever: MemoryLocalRetriever(const [
          SourceEvidence(
            id: 'chunk-1',
            sourceType: EvidenceSourceType.textChunk,
            text: 'Légzési elégtelenség, amikor DO2 < VO2.',
            label: 'Jegyzet · Légzési elégtelenség · Szöveg',
            validationState: ValidationState.validated,
            score: 0.95,
          ),
        ]),
        citationVerifier: CitationVerifier(),
        loadSettings: () async => AppSettings.defaults(),
        hasApiKey: () async => true,
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer(
        'Mikor beszélünk légzési elégtelenségről?',
      );

      expect(result.status, 'grounded');
      expect(result.text, contains('DO2 kisebb'));
      expect(result.text, contains('VO2'));
      expect(result.text, isNot(contains('oxigénszállítás')));
      expect(result.text, isNot(contains('oxigénfogyasztás')));
      expect(
        DebugConsole.allText,
        contains(
          '[GroundingGuard] stripped unsupported acronym explanation symbol=DO2',
        ),
      );
      expect(
        DebugConsole.allText,
        contains(
          '[GroundingGuard] stripped unsupported acronym explanation symbol=VO2',
        ),
      );
    },
  );

  test(
    'removes unsupported symbol definitions from grounded answers',
    () async {
      final service = LocalAnswerService(
        openAiClient: FakeOpenAiClient(
          answerText:
              'Légzési elégtelenség: DO2 az oxigénkínálat, '
              'VO2 az oxigénigény, és DO2 kisebb mint VO2.',
        ),
        retriever: MemoryLocalRetriever(const [
          SourceEvidence(
            id: 'chunk-1',
            sourceType: EvidenceSourceType.textChunk,
            text: 'Légzési elégtelenség, amikor DO2 < VO2.',
            label: 'Jegyzet · Légzési elégtelenség · Szöveg',
            validationState: ValidationState.validated,
            score: 0.95,
          ),
        ]),
        citationVerifier: CitationVerifier(),
        loadSettings: () async => AppSettings.defaults(),
        hasApiKey: () async => true,
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer(
        'Mikor beszélünk légzési elégtelenségről?',
      );

      expect(result.status, 'grounded');
      expect(result.text, contains('DO2 kisebb'));
      expect(result.text, contains('VO2'));
      expect(result.text, isNot(contains('oxigénkínálat')));
      expect(result.text, isNot(contains('oxigénigény')));
      expect(
        DebugConsole.allText,
        contains(
          '[GroundingGuard] stripped unsupported symbol definition symbol=DO2',
        ),
      );
      expect(
        DebugConsole.allText,
        contains(
          '[GroundingGuard] stripped unsupported symbol definition symbol=VO2',
        ),
      );
    },
  );

  test('uses Gemini key and client when Gemini is active', () async {
    final usedProviders = <AiProvider>[];
    final service = LocalAnswerService(
      clientForProvider: (AiProvider provider) {
        usedProviders.add(provider);
        return FakeOpenAiClient(answerText: 'Gemini valasz.');
      },
      retriever: MemoryLocalRetriever(const [
        SourceEvidence(
          id: 'chunk-1',
          sourceType: EvidenceSourceType.textChunk,
          text: 'Validalt PDF reszlet',
          label: 'PDF reszlet',
          validationState: ValidationState.validated,
          score: 0.95,
        ),
      ]),
      citationVerifier: CitationVerifier(),
      loadSettings: () async =>
          AppSettings.defaults().copyWith(activeProvider: AiProvider.gemini),
      hasApiKeyForProvider: (provider) async => provider == AiProvider.gemini,
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('Mi a teendo?');

    expect(result.status, 'grounded');
    expect(result.text, 'Gemini valasz.');
    expect(usedProviders, [AiProvider.gemini]);
    expect(
      DebugConsole.allText,
      contains('[Chat/RAG] query embedding model=gemini-embedding-001'),
    );
  });

  test(
    'uses recent chat context for follow-up retrieval and generation',
    () async {
      final client = _RecordingAiClient(
        answerText: 'Azert, mert idofuggo beavatkozas.',
      );
      final service = LocalAnswerService(
        openAiClient: client,
        retriever: MemoryLocalRetriever(const [
          SourceEvidence(
            id: 'chunk-1',
            sourceType: EvidenceSourceType.textChunk,
            text: 'A trombolizis idofuggo beavatkozas.',
            label: 'Stroke protokoll',
            validationState: ValidationState.validated,
            score: 0.95,
          ),
        ]),
        citationVerifier: CitationVerifier(),
        loadSettings: () async => AppSettings.defaults(),
        hasApiKey: () async => true,
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer(
        'Miért?',
        context: [
          ChatMessage(
            id: 'message-1',
            conversationId: 'conversation-1',
            sender: ChatSender.user,
            text: 'Mikor kell trombolizis?',
            createdAt: DateTime.utc(2026, 1, 1, 12),
          ),
          ChatMessage(
            id: 'message-2',
            conversationId: 'conversation-1',
            sender: ChatSender.assistant,
            text: 'A dokumentum szerint 4,5 oran belul merul fel.',
            createdAt: DateTime.utc(2026, 1, 1, 12, 1),
            status: 'grounded',
          ),
        ],
      );

      expect(result.status, 'grounded');
      expect(
        client.embeddingInputs.single,
        contains('Mikor kell trombolizis?'),
      );
      expect(
        client.embeddingInputs.single,
        contains('Aktualis kerdes: Miért?'),
      );
      expect(
        client.conversationContexts.single,
        contains('A dokumentum szerint 4,5 oran belul merul fel.'),
      );
    },
  );

  test('missing provider key log includes provider name in chat', () async {
    final service = LocalAnswerService(
      clientForProvider: (AiProvider provider) => FakeOpenAiClient(),
      retriever: MemoryLocalRetriever(const []),
      citationVerifier: CitationVerifier(),
      loadSettings: () async =>
          AppSettings.defaults().copyWith(activeProvider: AiProvider.gemini),
      hasApiKeyForProvider: (provider) async => false,
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('Mi a teendo?');

    expect(result.status, 'missing_api_key');
    expect(result.text, 'Gemini API kulcs nincs beállítva.');
    expect(
      DebugConsole.allText,
      contains('[Chat/RAG] refused reason=missing_api_key provider=gemini'),
    );
  });

  test(
    'missing API key does not fall back to offline keyword search',
    () async {
      final service = LocalAnswerService(
        openAiClient: FakeOpenAiClient(),
        retriever: MemoryLocalRetriever(const [
          SourceEvidence(
            id: 'chunk-1',
            sourceType: EvidenceSourceType.textChunk,
            text: 'Thrombectomia indikaciok.',
            label: '1. oldal',
            validationState: ValidationState.validated,
            score: 0.9,
          ),
        ]),
        citationVerifier: CitationVerifier(),
        loadSettings: () async =>
            AppSettings.defaults().copyWith(offlineFallbackEnabled: true),
        hasApiKey: () async => false,
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer('thrombectomia');

      expect(result.status, 'missing_api_key');
      expect(result.citations, isEmpty);
      expect(DebugConsole.allText, isNot(contains('[Offline] search start')));
      expect(DebugConsole.allText, isNot(contains('[Chat/RAG] fallback')));
    },
  );

  test('forced offline mode bypasses API key and AI client calls', () async {
    final service = LocalAnswerService(
      openAiClient: _ThrowingAiClient(),
      retriever: MemoryLocalRetriever(const [
        SourceEvidence(
          id: 'chunk-1',
          sourceType: EvidenceSourceType.textChunk,
          text: 'Thrombectomia indikaciok.',
          label: '1. oldal',
          validationState: ValidationState.validated,
          score: 0.9,
        ),
      ]),
      citationVerifier: CitationVerifier(),
      loadSettings: () async =>
          AppSettings.defaults().copyWith(answerMode: AnswerModes.offline),
      hasApiKey: () async => throw StateError('api key should not be checked'),
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('thrombectomia');

    expect(result.status, 'offline_search');
    expect(result.text, contains('Ez nem AI által generált válasz.'));
    expect(result.citations.single.sourceId, 'chunk-1');
    expect(DebugConsole.allText, contains('[Offline] mode=forced'));
  });

  test(
    'forced offline mode composes graph answer sections from evidence',
    () async {
      final service = LocalAnswerService(
        openAiClient: _ThrowingAiClient(),
        retriever: MemoryLocalRetriever(const [
          SourceEvidence(
            id: 'definition-1',
            sourceType: EvidenceSourceType.textChunk,
            text: 'energia: munkavégző képesség',
            label: 'Fizika definíció',
            validationState: ValidationState.validated,
            score: 0.9,
          ),
          SourceEvidence(
            id: 'table-1',
            sourceType: EvidenceSourceType.tableChunk,
            text: 'Forma | Példa\nmozgási energia | mozgó test',
            label: 'Fizika táblázat',
            validationState: ValidationState.validated,
            score: 0.85,
          ),
        ]),
        citationVerifier: CitationVerifier(),
        loadSettings: () async =>
            AppSettings.defaults().copyWith(answerMode: AnswerModes.offline),
        hasApiKey: () async =>
            throw StateError('api key should not be checked'),
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer('mi az energia?');

      expect(result.status, 'offline_search');
      expect(result.text, contains('graph válasz'));
      expect(result.text, contains('Definíciók\n- energia'));
      expect(result.text, contains('Táblázatos szabályok'));
      expect(DebugConsole.allText, contains('[LocalGraphAnswer] compose'));
    },
  );

  test(
    'model-backed offline embedding mode uses local vector graph without keyword fallback',
    () async {
      final service = LocalAnswerService(
        openAiClient: _ThrowingAiClient(),
        retriever: MemoryLocalRetriever(const [
          SourceEvidence(
            id: 'chunk-1',
            sourceType: EvidenceSourceType.textChunk,
            text: 'Thrombectomia indikaciok.',
            label: '1. oldal',
            validationState: ValidationState.validated,
            score: 0.9,
          ),
        ]),
        citationVerifier: CitationVerifier(),
        loadSettings: () async => AppSettings.defaults().copyWith(
          answerMode: AnswerModes.offline,
          localIndexingMode: LocalIndexingModes.embeddingGemma,
        ),
        hasApiKey: () async =>
            throw StateError('api key should not be checked'),
        hasReadyDocuments: () async => true,
      );

      final result = await service.answer('thrombectomia');

      expect(result.status, 'offline_search');
      expect(result.citations.single.sourceId, 'chunk-1');
      expect(result.text, contains('Offline vektoros graph'));
      expect(DebugConsole.allText, contains('[LocalVector] memory search'));
      expect(
        DebugConsole.allText,
        contains('[Chat/RAG] offline vector matches=1'),
      );
      expect(
        DebugConsole.allText,
        isNot(contains('[Offline] index unavailable')),
      );
      expect(DebugConsole.allText, isNot(contains('[Offline] index degraded')));
      expect(DebugConsole.allText, isNot(contains('[Offline] search start')));
    },
  );

  test(
    'forced offline vector search uses current question without assistant history',
    () async {
      final retriever = _RecordingRetriever();
      final service = LocalAnswerService(
        openAiClient: _ThrowingAiClient(),
        retriever: retriever,
        citationVerifier: CitationVerifier(),
        loadSettings: () async => AppSettings.defaults().copyWith(
          answerMode: AnswerModes.offline,
          localIndexingMode: LocalIndexingModes.embeddingGemma,
        ),
        hasApiKey: () async =>
            throw StateError('api key should not be checked'),
        hasReadyDocuments: () async => true,
      );

      await service.answer(
        'mi a rejtett adat?',
        context: [
          ChatMessage(
            id: 'assistant-1',
            conversationId: 'conversation-1',
            sender: ChatSender.assistant,
            text:
                'Offline vektoros graph találatokból épített válasz. Folyamatkapcsolatok: Légzési elégtelen? -> Oxygén. Források: Jegyzet · Légzési elégtelenség.',
            createdAt: DateTime(2026),
          ),
        ],
      );

      expect(retriever.localVectorQueries, ['mi a rejtett adat?']);
    },
  );

  test('offline graph answer is sectioned and groups citations by chunk', () async {
    final service = LocalAnswerService(
      openAiClient: _ThrowingAiClient(),
      retriever: const _StaticRetriever([
        SourceEvidence(
          id: 'note:n1:block-flow:edge-8',
          sourceType: EvidenceSourceType.flowchartEdge,
          text: 'Súlyos? -> Oxygén [Igen]',
          label:
              'Jegyzet · Légzési elégtelenség · Flowchart · kapcsolat: Súlyos? -> Oxygén [Igen]',
          validationState: ValidationState.validated,
        ),
        SourceEvidence(
          id: 'note:n1:block-flow:node-6',
          sourceType: EvidenceSourceType.flowchartNode,
          text: 'Súlyos?',
          label: 'Jegyzet · Légzési elégtelenség · Flowchart · node: Súlyos?',
          validationState: ValidationState.validated,
        ),
        SourceEvidence(
          id: 'note:n1:block-table:row-1',
          sourceType: EvidenceSourceType.tableChunk,
          text:
              'súlyos légzési elégtelenség: magas áramlású oxygén | enyhe légzési elégtelenség: célzott oxygénterápia',
          label: 'Jegyzet · Légzési elégtelenség · Táblázat · sor 1',
          validationState: ValidationState.validated,
        ),
      ]),
      citationVerifier: CitationVerifier(),
      loadSettings: () async => AppSettings.defaults().copyWith(
        answerMode: AnswerModes.offline,
        localIndexingMode: LocalIndexingModes.keywordBm25,
      ),
      hasApiKey: () async => throw StateError('api key should not be checked'),
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('súlyos?');

    expect(
      result.text,
      contains('Folyamatkapcsolatok\n- Ha súlyos, akkor Oxygén.'),
    );
    expect(
      result.text,
      contains('Táblázatos szabályok\n- súlyos légzési elégtelenség'),
    );
    expect(result.text, isNot(contains('Források:')));
    expect(result.text, isNot(contains('Súlyos? -> Oxygén')));
    expect(result.citations.map((citation) => citation.sourceId), [
      'note:n1:block-flow',
      'note:n1:block-table',
    ]);
  });

  test('forced offline mixed search uses hybrid retriever path', () async {
    final retriever = _RecordingRetriever();
    final service = LocalAnswerService(
      openAiClient: _ThrowingAiClient(),
      retriever: retriever,
      citationVerifier: CitationVerifier(),
      loadSettings: () async => AppSettings.defaults().copyWith(
        answerMode: AnswerModes.offline,
        localIndexingMode: LocalIndexingModes.mixedMediapipeTextEmbedder,
      ),
      hasApiKey: () async => throw StateError('api key should not be checked'),
      hasReadyDocuments: () async => true,
    );

    await service.answer('mi a DO2?');

    expect(retriever.hybridQueries, ['mi a DO2?']);
    expect(retriever.hybridVectorModes, [
      LocalIndexingModes.mediapipeTextEmbedder,
    ]);
    expect(retriever.localVectorQueries, isEmpty);
  });
}

class _RecordingRetriever implements LocalRetriever {
  final localVectorQueries = <String>[];
  final hybridQueries = <String>[];
  final hybridVectorModes = <String>[];

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? query,
    bool allowKeywordExpansion = false,
  }) async {
    return const [];
  }

  @override
  Future<List<SourceEvidence>> retrieveLocalVector({
    required String query,
    required int limit,
    required String mode,
  }) async {
    localVectorQueries.add(query);
    return const [
      SourceEvidence(
        id: 'recipe',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Bolognai recept rejtett adat: bazsalikom.',
        label: 'Jegyzet · Recept',
        validationState: ValidationState.validated,
      ),
    ];
  }

  @override
  Future<List<SourceEvidence>> retrieveHybrid({
    required String query,
    required int limit,
    required String vectorMode,
  }) async {
    hybridQueries.add(query);
    hybridVectorModes.add(vectorMode);
    return const [
      SourceEvidence(
        id: 'do2',
        sourceType: EvidenceSourceType.textChunk,
        text: 'DO2 = oxygénkínálat.',
        label: 'Jegyzet · Definíció',
        validationState: ValidationState.validated,
      ),
    ];
  }

  @override
  Future<List<SourceEvidence>> retrieveOffline({
    required String query,
    required int limit,
  }) async {
    return const [];
  }
}

class _StaticRetriever implements LocalRetriever {
  const _StaticRetriever(this.items);

  final List<SourceEvidence> items;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? query,
    bool allowKeywordExpansion = false,
  }) async {
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<List<SourceEvidence>> retrieveLocalVector({
    required String query,
    required int limit,
    required String mode,
  }) async {
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<List<SourceEvidence>> retrieveHybrid({
    required String query,
    required int limit,
    required String vectorMode,
  }) async {
    return items.take(limit).toList(growable: false);
  }

  @override
  Future<List<SourceEvidence>> retrieveOffline({
    required String query,
    required int limit,
  }) async {
    return items.take(limit).toList(growable: false);
  }
}

class _ThrowingAiClient extends FakeOpenAiClient {
  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) {
    throw StateError('AI client should not be called');
  }
}

class _RecordingAiClient extends FakeOpenAiClient {
  _RecordingAiClient({required super.answerText});

  final embeddingInputs = <String>[];
  final conversationContexts = <String?>[];

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) async {
    embeddingInputs.add(input);
    return super.createEmbedding(input: input, model: model);
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
    String? conversationContext,
  }) async {
    conversationContexts.add(conversationContext);
    return super.generateAnswer(
      model: model,
      question: question,
      evidence: evidence,
      conversationContext: conversationContext,
    );
  }
}
