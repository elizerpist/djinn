import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/local_answer_service.dart';
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
    expect(DebugConsole.allText, contains('[Chat/RAG] retrieved count=1'));
    expect(DebugConsole.allText, contains('[Chat/RAG] grounded citations=1'));
  });

  test('passes selected collection to retriever', () async {
    final retriever = _RecordingRetriever();
    final service = LocalAnswerService(
      openAiClient: FakeOpenAiClient(answerText: 'Stroke protokoll.'),
      retriever: retriever,
      citationVerifier: CitationVerifier(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer(
      'Mi a teendo?',
      collectionName: 'Stroke',
    );

    expect(result.status, 'grounded');
    expect(retriever.collectionNames, ['Stroke']);
  });
}

class _RecordingRetriever implements LocalRetriever {
  final collectionNames = <String?>[];

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? collectionName,
  }) async {
    collectionNames.add(collectionName);
    return const [
      SourceEvidence(
        id: 'stroke-chunk',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Stroke protocol',
        label: 'Szöveges PDF-részlet',
        validationState: ValidationState.validated,
        score: 0.9,
      ),
    ];
  }
}
