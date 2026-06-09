import '../../debug/debug_console.dart';
import '../../openai/openai_client.dart';
import '../../rag/models/source_evidence.dart';
import '../../rag/retrieval/local_retriever.dart';
import '../../rag/verification/citation_verifier.dart';
import '../../settings/models/app_settings.dart';
import '../models/chat_citation.dart';

const insufficientEvidenceText =
    'A helyi tudásbázisban nincs elég forrás ehhez a válaszhoz.';

abstract class AnswerService {
  Future<LocalAnswerResult> answer(String question);
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
    required this.openAiClient,
    required this.retriever,
    required this.citationVerifier,
    required this.loadSettings,
    required this.hasApiKey,
    required this.hasReadyDocuments,
  });

  final OpenAiClient openAiClient;
  final LocalRetriever retriever;
  final CitationVerifier citationVerifier;
  final LoadSettings loadSettings;
  final ReadinessCheck hasApiKey;
  final ReadinessCheck hasReadyDocuments;

  @override
  Future<LocalAnswerResult> answer(String question) async {
    DebugConsole.log('[Chat/RAG] answer start chars=${question.length}');
    if (!await hasApiKey()) {
      DebugConsole.log('[Chat/RAG] refused reason=missing_api_key');
      return const LocalAnswerResult(
        text: 'OpenAI API kulcs nincs beállítva.',
        status: 'missing_api_key',
        refusalReason: 'missing_api_key',
        citations: [],
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

    final settings = await loadSettings();
    DebugConsole.log(
      '[Chat/RAG] query embedding model=${settings.embeddingModel}',
    );
    final queryVector = await openAiClient.createEmbedding(
      input: question,
      model: settings.embeddingModel,
    );
    final retrieved = await retriever.retrieve(
      queryVector: queryVector,
      limit: settings.retrievalLimit,
      minimumSimilarity: settings.minimumSimilarity,
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

    final draft = await openAiClient.generateAnswer(
      model: settings.answerModel,
      question: question,
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
      final grounded = await openAiClient.verifyGroundedness(
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
      sourceLabel: evidence.label,
      validationState: evidence.validationState.wireName,
    );
  }
}
