import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_provider.dart';
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
    'offline fallback returns source excerpts without generated answer text',
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

      expect(result.status, 'offline_search');
      expect(result.text, contains('Offline keresési találatok'));
      expect(result.text, contains('Ez nem AI által generált válasz.'));
      expect(result.text, contains('Thrombectomia indikaciok.'));
      expect(result.citations.single.sourceId, 'chunk-1');
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
