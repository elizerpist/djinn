import '../../ai/ai_client.dart';
import '../../ai/ai_client_resolver.dart';
import '../../ai/ai_error.dart';
import '../../ai/ai_provider.dart';
import '../../debug/debug_console.dart';
import '../../openai/openai_client.dart';
import '../../rag/models/source_evidence.dart';
import '../../rag/retrieval/local_retriever.dart';
import '../../rag/verification/citation_verifier.dart';
import '../../settings/models/app_settings.dart';
import '../models/chat_citation.dart';
import '../models/chat_message.dart';

const insufficientEvidenceText =
    'A helyi tudásbázisban nincs elég forrás ehhez a válaszhoz.';

abstract class AnswerService {
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  });
}

class LocalAnswerResult {
  const LocalAnswerResult({
    required this.text,
    required this.status,
    required this.citations,
    this.refusalReason,
    this.hasValidationWarning = false,
    this.warningText,
  });

  final String text;
  final String status;
  final List<ChatCitation> citations;
  final String? refusalReason;
  final bool hasValidationWarning;
  final String? warningText;
}

typedef LoadSettings = Future<AppSettings> Function();
typedef ReadinessCheck = Future<bool> Function();

class LocalAnswerService implements AnswerService {
  LocalAnswerService({
    AiClient? openAiClient,
    AiClientForProvider? clientForProvider,
    required this.retriever,
    required this.citationVerifier,
    required this.loadSettings,
    ReadinessCheck? hasApiKey,
    HasApiKeyForProvider? hasApiKeyForProvider,
    required this.hasReadyDocuments,
  }) : _openAiClient = openAiClient,
       _clientForProvider = clientForProvider,
       _hasApiKey = hasApiKey,
       _hasApiKeyForProvider = hasApiKeyForProvider;

  final AiClient? _openAiClient;
  final AiClientForProvider? _clientForProvider;
  final LocalRetriever retriever;
  final CitationVerifier citationVerifier;
  final LoadSettings loadSettings;
  final ReadinessCheck? _hasApiKey;
  final HasApiKeyForProvider? _hasApiKeyForProvider;
  final ReadinessCheck hasReadyDocuments;

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    DebugConsole.log('[Chat/RAG] answer start chars=${question.length}');
    final conversationContext = _conversationContext(context);
    final retrievalQuery = _retrievalQuery(
      question: question,
      conversationContext: conversationContext,
    );
    final settings = await loadSettings();
    final provider = settings.activeProvider;
    if (settings.answerMode == AnswerModes.offline) {
      DebugConsole.log('[Offline] mode=forced');
      if (!await hasReadyDocuments()) {
        DebugConsole.log('[Chat/RAG] refused reason=empty_knowledge_base');
        return const LocalAnswerResult(
          text: 'Nincs feldolgozott helyi tudásbázis.',
          status: 'empty_knowledge_base',
          refusalReason: 'empty_knowledge_base',
          citations: [],
        );
      }
      return _offlineAnswer(
        question,
        settings,
        retrievalQuery: retrievalQuery,
      );
    }
    if (!await _hasKey(provider)) {
      if (settings.offlineFallbackEnabled && await hasReadyDocuments()) {
        DebugConsole.log(
          '[Chat/RAG] fallback reason=missing_api_key provider=${provider.wireName}',
        );
        return _offlineAnswer(
          question,
          settings,
          retrievalQuery: retrievalQuery,
        );
      }
      DebugConsole.log(
        '[Chat/RAG] refused reason=missing_api_key provider=${provider.wireName}',
      );
      return LocalAnswerResult(
        text: _missingApiKeyText(provider),
        status: 'missing_api_key',
        refusalReason: 'missing_api_key',
        citations: const [],
      );
    }
    if (!await hasReadyDocuments()) {
      DebugConsole.log('[Chat/RAG] refused reason=empty_knowledge_base');
      return const LocalAnswerResult(
        text: 'Nincs feldolgozott helyi tudásbázis.',
        status: 'empty_knowledge_base',
        refusalReason: 'empty_knowledge_base',
        citations: [],
      );
    }

    final client = _clientFor(provider);
    final List<SourceEvidence> retrieved;
    try {
      DebugConsole.log(
        '[Chat/RAG] query embedding model=${settings.embeddingModel}',
      );
      final queryVector = await client.createEmbedding(
        input: retrievalQuery,
        model: settings.embeddingModel,
      );
      retrieved = await retriever.retrieve(
        queryVector: queryVector,
        limit: settings.retrievalLimit,
        minimumSimilarity: settings.minimumSimilarity,
        query: retrievalQuery,
      );
    } on AiProviderException catch (error) {
      if (settings.offlineFallbackEnabled) {
        DebugConsole.log(
          '[Chat/RAG] fallback reason=${error.failure.code.name} provider=${provider.wireName}',
        );
        return _offlineAnswer(
          question,
          settings,
          retrievalQuery: retrievalQuery,
        );
      }
      rethrow;
    } on OpenAiException catch (error) {
      if (settings.offlineFallbackEnabled) {
        DebugConsole.log(
          '[Chat/RAG] fallback reason=openai_error error=${error.message}',
        );
        return _offlineAnswer(
          question,
          settings,
          retrievalQuery: retrievalQuery,
        );
      }
      rethrow;
    }
    DebugConsole.log('[Chat/RAG] retrieved count=${retrieved.length}');
    if (retrieved.isEmpty) {
      DebugConsole.log('[Chat/RAG] refused reason=insufficient_evidence');
      return const LocalAnswerResult(
        text: insufficientEvidenceText,
        status: 'insufficient_evidence',
        refusalReason: 'insufficient_evidence',
        citations: [],
      );
    }

    DebugConsole.log('[Chat/RAG] answer language=auto default=hu');
    final draft = await client.generateAnswer(
      model: settings.answerModel,
      question: question,
      conversationContext: conversationContext.isEmpty
          ? null
          : conversationContext,
      evidence: retrieved
          .map(
            (item) =>
                OpenAiEvidence(id: item.id, label: item.label, text: item.text),
          )
          .toList(growable: false),
    );
    if (draft.abstain) {
      DebugConsole.log(
        '[Chat/RAG] refused reason=${draft.refusalReason ?? 'model_refused'}',
      );
      return LocalAnswerResult(
        text: draft.answer.isEmpty ? insufficientEvidenceText : draft.answer,
        status: 'model_refused',
        refusalReason: draft.refusalReason ?? 'model_refused',
        citations: const [],
      );
    }

    final verification = citationVerifier.verify(
      citedSourceIds: draft.citedSourceIds,
      retrieved: retrieved,
    );
    if (!verification.accepted) {
      DebugConsole.log(
        '[Chat/RAG] refused reason=${verification.refusalReason ?? 'citation_verification_failed'}',
      );
      return LocalAnswerResult(
        text: insufficientEvidenceText,
        status: 'citation_verification_failed',
        refusalReason:
            verification.refusalReason ?? 'citation_verification_failed',
        citations: const [],
      );
    }

    if (settings.groundednessCheckEnabled) {
      final grounded = await client.verifyGroundedness(
        model: settings.groundednessModel,
        answer: draft.answer,
        evidence: verification.citations
            .map(
              (item) => OpenAiEvidence(
                id: item.id,
                label: item.label,
                text: item.text,
              ),
            )
            .toList(growable: false),
      );
      if (!grounded) {
        DebugConsole.log('[Chat/RAG] refused reason=groundedness_failed');
        return const LocalAnswerResult(
          text: insufficientEvidenceText,
          status: 'groundedness_failed',
          refusalReason: 'groundedness_failed',
          citations: [],
        );
      }
    }

    DebugConsole.log(
      '[Chat/RAG] grounded citations=${verification.citations.length} '
      'warning=${verification.hasValidationWarning}',
    );
    return LocalAnswerResult(
      text: draft.answer,
      status: 'grounded',
      citations: verification.citations.map(_toChatCitation).toList(),
      hasValidationWarning: verification.hasValidationWarning,
      warningText: verification.warningText,
    );
  }

  ChatCitation _toChatCitation(SourceEvidence evidence) {
    return ChatCitation(
      documentId: evidence.documentId ?? '',
      title: evidence.label,
      page: evidence.pageNumber,
      section: null,
      excerpt: evidence.text,
      sourceId: evidence.id,
      sourceType: evidence.sourceType.wireName,
      sourceLabel: evidence.label,
      validationState: evidence.validationState.wireName,
    );
  }

  String _retrievalQuery({
    required String question,
    required String conversationContext,
  }) {
    if (conversationContext.isEmpty) {
      return question;
    }
    return 'Beszelgetesi elozmeny:\n$conversationContext\n\n'
        'Aktualis kerdes: $question';
  }

  String _conversationContext(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return '';
    }
    const maxMessages = 6;
    const maxChars = 1800;
    const maxMessageChars = 420;
    final lines = <String>[];
    for (final message
        in messages.reversed.take(maxMessages).toList().reversed) {
      final text = _truncate(message.text.trim(), maxMessageChars);
      if (text.isEmpty) {
        continue;
      }
      final role = switch (message.sender) {
        ChatSender.user => 'User',
        ChatSender.assistant => 'Assistant',
      };
      lines.add('$role: $text');
    }
    final joined = lines.join('\n');
    return _truncate(joined, maxChars);
  }

  String _truncate(String value, int maxChars) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars - 3)}...';
  }

  Future<LocalAnswerResult> _offlineAnswer(
    String question,
    AppSettings settings, {
    String? retrievalQuery,
  }) async {
    DebugConsole.log('[Offline] index mode=${settings.localIndexingMode}');
    if (LocalIndexingModes.isModelBacked(settings.localIndexingMode)) {
      DebugConsole.log(
        '[Offline] index degraded mode=${settings.localIndexingMode} '
        'fallback=${LocalIndexingModes.keywordBm25}',
      );
    }
    final results = await retriever.retrieveOffline(
      query: retrievalQuery ?? question,
      limit: settings.retrievalLimit,
    );
    if (results.isEmpty) {
      DebugConsole.log('[Chat/RAG] offline fallback matches=0');
      return const LocalAnswerResult(
        text:
            'Offline keresési találatok. Ez nem AI által generált válasz.\n\nNincs offline találat.',
        status: 'offline_search',
        refusalReason: 'insufficient_offline_results',
        citations: [],
      );
    }
    DebugConsole.log('[Chat/RAG] offline fallback matches=${results.length}');
    final graphAnswer = _offlineGraphAnswer(
      question: question,
      evidence: results,
    );
    final excerpts = results
        .map((item) {
          final page = item.pageNumber == null
              ? ''
              : ' ${item.pageNumber}. oldal';
          return '- ${item.label}$page: ${item.text}';
        })
        .join('\n');
    return LocalAnswerResult(
      text: 'Offline keresési találatokból épített graph válasz. '
          'Ez nem AI által generált válasz.\n\n'
          '$graphAnswer\n\nForrások:\n$excerpts',
      status: 'offline_search',
      citations: results.map(_toChatCitation).toList(growable: false),
    );
  }

  String _offlineGraphAnswer({
    required String question,
    required List<SourceEvidence> evidence,
  }) {
    DebugConsole.log(
      '[LocalGraphAnswer] compose questionChars=${question.length} '
      'evidence=${evidence.length}',
    );
    final definitions = <String>[];
    final processes = <String>[];
    final tables = <String>[];
    final facts = <String>[];
    final seen = <String>{};
    for (final item in evidence) {
      final lines = item.text
          .split(RegExp(r'\n+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .take(8);
      for (final line in lines) {
        final normalized = line.toLowerCase();
        if (!seen.add(normalized)) {
          continue;
        }
        if (line.contains('->')) {
          processes.add(line);
        } else if (line.contains('|')) {
          tables.add(line.replaceAll('|', ' -> '));
        } else if (RegExp(r'^[^:]{2,48}:').hasMatch(line) ||
            RegExp(r'^[^=]{2,48}=').hasMatch(line)) {
          definitions.add(line);
        } else {
          facts.add(line);
        }
      }
    }
    DebugConsole.log(
      '[LocalGraphAnswer] buckets definitions=${definitions.length} '
      'tables=${tables.length} processes=${processes.length} facts=${facts.length}',
    );
    final sentences = <String>[];
    if (definitions.isNotEmpty) {
      sentences.add('Definíciók: ${definitions.take(3).join('; ')}.');
    }
    if (processes.isNotEmpty) {
      sentences.add('Folyamatkapcsolatok: ${processes.take(4).join('; ')}.');
    }
    if (tables.isNotEmpty) {
      sentences.add('Táblázatos szabályok: ${tables.take(4).join('; ')}.');
    }
    if (facts.isNotEmpty) {
      sentences.add('Kapcsolt tények: ${facts.take(4).join('; ')}.');
    }
    if (sentences.isEmpty) {
      return 'A lokális graph talált forrásokat, de nem tudott belőlük '
          'összefoglaló szabályt képezni.';
    }
    return sentences.join('\n');
  }

  Future<bool> _hasKey(AiProvider provider) {
    final providerAware = _hasApiKeyForProvider;
    if (providerAware != null) {
      return providerAware(provider);
    }
    final legacy = _hasApiKey;
    if (legacy != null) {
      return legacy();
    }
    throw StateError('No API key checker configured');
  }

  AiClient _clientFor(AiProvider provider) {
    final providerAware = _clientForProvider;
    if (providerAware != null) {
      return providerAware(provider);
    }
    final legacy = _openAiClient;
    if (legacy != null) {
      return legacy;
    }
    throw StateError('No AI client configured');
  }

  String _missingApiKeyText(AiProvider provider) {
    return '${provider.label} API kulcs nincs beállítva.';
  }
}
