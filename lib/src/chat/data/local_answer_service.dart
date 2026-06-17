import '../../ai/ai_client.dart';
import '../../ai/ai_client_resolver.dart';
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
      return _offlineAnswer(question, settings, retrievalQuery: retrievalQuery);
    }
    if (!await _hasKey(provider)) {
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
    DebugConsole.log(
      '[Chat/RAG] query embedding model=${settings.embeddingModel}',
    );
    final queryVector = await client.createEmbedding(
      input: retrievalQuery,
      model: settings.embeddingModel,
    );
    final retrieved = await retriever.retrieve(
      queryVector: queryVector,
      limit: settings.retrievalLimit,
      minimumSimilarity: settings.minimumSimilarity,
      query: retrievalQuery,
      allowKeywordExpansion:
          settings.localIndexingMode == LocalIndexingModes.keywordBm25,
    );
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

    final guardedAnswer = _applyGroundingGuards(
      answer: draft.answer,
      evidence: verification.citations,
    );

    if (settings.groundednessCheckEnabled) {
      final grounded = await client.verifyGroundedness(
        model: settings.groundednessModel,
        answer: guardedAnswer,
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
      text: guardedAnswer,
      status: 'grounded',
      citations: verification.citations.map(_toChatCitation).toList(),
      hasValidationWarning: verification.hasValidationWarning,
      warningText: verification.warningText,
    );
  }

  String _applyGroundingGuards({
    required String answer,
    required List<SourceEvidence> evidence,
  }) {
    if (answer.trim().isEmpty || evidence.isEmpty) {
      return answer;
    }
    final evidenceText = _normalizeEvidenceText(
      evidence.map((item) => item.text).join('\n'),
    );
    final acronymExpansion = RegExp(
      r'\b([A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]{1,10}\d{0,4})\s*\(([^()\n]{3,120})\)',
    );
    final withoutParentheticals = answer.replaceAllMapped(acronymExpansion, (
      match,
    ) {
      final symbol = match.group(1)!;
      final explanation = match.group(2)!.trim();
      if (!_looksLikeSymbol(symbol)) {
        return match.group(0)!;
      }
      if (_isExplanationSupported(
        symbol: symbol,
        explanation: explanation,
        normalizedEvidence: evidenceText,
      )) {
        return match.group(0)!;
      }
      DebugConsole.log(
        '[GroundingGuard] stripped unsupported acronym explanation '
        'symbol=$symbol chars=${explanation.length}',
      );
      return symbol;
    });
    return _stripUnsupportedSymbolDefinitions(
      withoutParentheticals,
      normalizedEvidence: evidenceText,
    );
  }

  String _stripUnsupportedSymbolDefinitions(
    String answer, {
    required String normalizedEvidence,
  }) {
    final definitionPattern = RegExp(
      r'\b([A-ZÁÉÍÓÖŐÚÜŰ][A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]{0,7}\d+'
      r'[A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]{0,4}|[A-ZÁÉÍÓÖŐÚÜŰ]{2,}\d{0,4})'
      r'\s*(?:=|:|\baz\b|\bjelenti\b|\bjelentése\b)\s*([^,.;\n]{3,96})',
    );
    return answer.replaceAllMapped(definitionPattern, (match) {
      final symbol = match.group(1)!;
      final explanation = match.group(2)!.trim();
      if (!_looksLikeSymbol(symbol)) {
        return match.group(0)!;
      }
      if (_isExplanationSupported(
        symbol: symbol,
        explanation: explanation,
        normalizedEvidence: normalizedEvidence,
      )) {
        return match.group(0)!;
      }
      DebugConsole.log(
        '[GroundingGuard] stripped unsupported symbol definition '
        'symbol=$symbol chars=${explanation.length}',
      );
      return symbol;
    });
  }

  bool _looksLikeSymbol(String value) {
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final uppercaseLetters = RegExp(r'[A-ZÁÉÍÓÖŐÚÜŰ]').allMatches(value).length;
    return hasDigit || uppercaseLetters >= 2;
  }

  bool _isExplanationSupported({
    required String symbol,
    required String explanation,
    required String normalizedEvidence,
  }) {
    final normalizedSymbol = _normalizeEvidenceText(symbol);
    final normalizedExplanation = _normalizeEvidenceText(explanation);
    if (normalizedExplanation.isEmpty) {
      return true;
    }
    final exactParenthetical = '$normalizedSymbol ($normalizedExplanation)';
    return normalizedEvidence.contains(exactParenthetical) ||
        normalizedEvidence.contains(normalizedExplanation);
  }

  String _normalizeEvidenceText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
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
    final query = question;
    if (retrievalQuery != null && retrievalQuery != question) {
      DebugConsole.log('[Offline] conversation context ignored for retrieval');
    }
    final bool modelBacked = LocalIndexingModes.isModelBacked(
      settings.localIndexingMode,
    );
    final bool hybrid = LocalIndexingModes.isHybrid(settings.localIndexingMode);
    final results = hybrid
        ? await retriever.retrieveHybrid(
            query: query,
            limit: settings.retrievalLimit,
            vectorMode: LocalIndexingModes.vectorModeFor(
              settings.localIndexingMode,
            ),
          )
        : modelBacked
        ? await retriever.retrieveLocalVector(
            query: query,
            limit: settings.retrievalLimit,
            mode: settings.localIndexingMode,
          )
        : await retriever.retrieveOffline(
            query: query,
            limit: settings.retrievalLimit,
          );
    if (results.isEmpty) {
      if (hybrid) {
        DebugConsole.log('[Chat/RAG] offline hybrid matches=0');
        return const LocalAnswerResult(
          text:
              'Offline hybrid graph keresési találatok. Ez nem AI által generált válasz.\n\nNincs offline hybrid találat.',
          status: 'offline_search',
          refusalReason: 'insufficient_offline_results',
          citations: [],
        );
      }
      if (modelBacked) {
        DebugConsole.log('[Chat/RAG] offline vector matches=0');
        return const LocalAnswerResult(
          text:
              'Offline vektoros graph keresési találatok. Ez nem AI által generált válasz.\n\nNincs offline vektoros találat.',
          status: 'offline_search',
          refusalReason: 'insufficient_offline_results',
          citations: [],
        );
      }
      DebugConsole.log('[Chat/RAG] offline keyword matches=0');
      return const LocalAnswerResult(
        text:
            'Offline keresési találatok. Ez nem AI által generált válasz.\n\nNincs offline találat.',
        status: 'offline_search',
        refusalReason: 'insufficient_offline_results',
        citations: [],
      );
    }
    if (hybrid) {
      DebugConsole.log('[Chat/RAG] offline hybrid matches=${results.length}');
    } else if (modelBacked) {
      DebugConsole.log('[Chat/RAG] offline vector matches=${results.length}');
    } else {
      DebugConsole.log('[Offline] keyword search selected');
      DebugConsole.log('[Chat/RAG] offline keyword matches=${results.length}');
    }
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
    final intro = hybrid
        ? 'Offline hybrid graph találatokból épített válasz. '
        : modelBacked
        ? 'Offline vektoros graph találatokból épített válasz. '
        : 'Offline keresési találatokból épített graph válasz. ';
    return LocalAnswerResult(
      text:
          intro
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
