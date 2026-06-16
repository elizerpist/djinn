import '../../ai/ai_provider.dart';
import '../../voice/voice_mode.dart';

class AnswerModes {
  static const ai = 'ai';
  static const offline = 'offline_search';
  static const autoFallback = 'auto_fallback';
}

enum AppNavigationMode {
  drawer('drawer'),
  bottomNav('bottom_nav');

  const AppNavigationMode(this.wireName);

  final String wireName;

  static AppNavigationMode fromWireName(String value) {
    return AppNavigationMode.values.firstWhere(
      (mode) => mode.wireName == value,
      orElse: () => AppNavigationMode.bottomNav,
    );
  }
}

class ChunkingModes {
  static const compact = 'compact';
  static const normal = 'normal';
  static const detailed = 'detailed';

  static String normalize(String value) {
    return switch (value) {
      compact => compact,
      detailed => detailed,
      _ => normal,
    };
  }
}

class LocalIndexingModes {
  static const mediapipeTextEmbedder = 'mediapipe_text_embedder';
  static const onnxMultilingualE5 = 'onnx_multilingual_e5';
  static const embeddingGemma = 'embedding_gemma';
  static const keywordBm25 = 'keyword_bm25';

  static const values = [
    mediapipeTextEmbedder,
    onnxMultilingualE5,
    embeddingGemma,
    keywordBm25,
  ];

  static String normalize(String value) {
    return values.contains(value) ? value : keywordBm25;
  }

  static String label(String value) {
    return switch (normalize(value)) {
      mediapipeTextEmbedder => 'MediaPipe/LiteRT Text Embedder',
      onnxMultilingualE5 => 'ONNX multilingual E5',
      embeddingGemma => 'LiteRT EmbeddingGemma',
      keywordBm25 => 'Kulcsszó/BM25/regex',
      _ => 'Kulcsszó/BM25/regex',
    };
  }

  static String description(String value) {
    return switch (normalize(value)) {
      mediapipeTextEmbedder =>
        'Lokális szemantikus embedding, ha a Text Embedder modell asset telepítve van. Ha nem elérhető, nincs automatikus kulcsszó/regex fallback.',
      onnxMultilingualE5 =>
        'Multilingual lokális embedding ONNX Runtime-mal, külön modell assettel. Ha nem elérhető, nincs automatikus kulcsszó/regex fallback.',
      embeddingGemma =>
        'Google EmbeddingGemma alapú lokális embedding LiteRT futtatóval. Ha nem elérhető, nincs automatikus kulcsszó/regex fallback.',
      keywordBm25 =>
        'Azonnal működő offline kulcsszó, BM25-szerű és regex keresés, vektor nélkül.',
      _ => 'Azonnal működő offline kulcsszó/BM25 keresés.',
    };
  }

  static bool isModelBacked(String value) {
    return normalize(value) != keywordBm25;
  }
}

class AppSettings {
  const AppSettings({
    required this.runtimeMode,
    required this.activeProvider,
    required this.openAiAnswerModel,
    required this.openAiExtractionModel,
    required this.openAiGroundednessModel,
    required this.openAiEmbeddingModel,
    required this.geminiAnswerModel,
    required this.geminiExtractionModel,
    required this.geminiGroundednessModel,
    required this.geminiEmbeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.offlineFallbackEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
    required this.voiceMode,
    required this.voiceLocale,
    required this.chunkingMode,
    required this.localIndexingMode,
    required this.navigationMode,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      runtimeMode: 'local_objectbox',
      activeProvider: AiProvider.openAi,
      openAiAnswerModel: 'gpt-5.5',
      openAiExtractionModel: 'gpt-5.5',
      openAiGroundednessModel: 'gpt-5.5',
      openAiEmbeddingModel: 'text-embedding-3-large',
      geminiAnswerModel: 'gemini-2.5-flash-lite',
      geminiExtractionModel: 'gemini-2.5-flash-lite',
      geminiGroundednessModel: 'gemini-2.5-flash-lite',
      geminiEmbeddingModel: 'gemini-embedding-001',
      deleteOpenAiFilesAfterProcessing: true,
      groundednessCheckEnabled: false,
      offlineFallbackEnabled: false,
      retrievalLimit: 8,
      minimumSimilarity: 0.72,
      voiceMode: VoiceMode.whisperConversation,
      voiceLocale: 'hu-HU',
      chunkingMode: ChunkingModes.normal,
      localIndexingMode: LocalIndexingModes.keywordBm25,
      navigationMode: AppNavigationMode.bottomNav,
    );
  }

  final String runtimeMode;
  final AiProvider activeProvider;
  final String openAiAnswerModel;
  final String openAiExtractionModel;
  final String openAiGroundednessModel;
  final String openAiEmbeddingModel;
  final String geminiAnswerModel;
  final String geminiExtractionModel;
  final String geminiGroundednessModel;
  final String geminiEmbeddingModel;
  final bool deleteOpenAiFilesAfterProcessing;
  final bool groundednessCheckEnabled;
  final bool offlineFallbackEnabled;
  final int retrievalLimit;
  final double minimumSimilarity;
  final VoiceMode voiceMode;
  final String voiceLocale;
  final String chunkingMode;
  final String localIndexingMode;
  final AppNavigationMode navigationMode;

  String get answerMode {
    return switch (runtimeMode) {
      AnswerModes.offline => AnswerModes.offline,
      _ => AnswerModes.ai,
    };
  }

  String get answerModel => modelFor(activeProvider, AiModelSlot.answer);
  String get extractionModel =>
      modelFor(activeProvider, AiModelSlot.extraction);
  String get groundednessModel =>
      modelFor(activeProvider, AiModelSlot.groundedness);
  String get embeddingModel => modelFor(activeProvider, AiModelSlot.embedding);

  String modelFor(AiProvider provider, AiModelSlot slot) {
    return switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.answer) => openAiAnswerModel,
      (AiProvider.openAi, AiModelSlot.extraction) => openAiExtractionModel,
      (AiProvider.openAi, AiModelSlot.groundedness) => openAiGroundednessModel,
      (AiProvider.openAi, AiModelSlot.embedding) => openAiEmbeddingModel,
      (AiProvider.gemini, AiModelSlot.answer) => geminiAnswerModel,
      (AiProvider.gemini, AiModelSlot.extraction) => geminiExtractionModel,
      (AiProvider.gemini, AiModelSlot.groundedness) => geminiGroundednessModel,
      (AiProvider.gemini, AiModelSlot.embedding) => geminiEmbeddingModel,
    };
  }

  AppSettings copyWith({
    String? runtimeMode,
    AiProvider? activeProvider,
    String? openAiAnswerModel,
    String? openAiExtractionModel,
    String? openAiGroundednessModel,
    String? openAiEmbeddingModel,
    String? geminiAnswerModel,
    String? geminiExtractionModel,
    String? geminiGroundednessModel,
    String? geminiEmbeddingModel,
    String? answerModel,
    String? extractionModel,
    String? groundednessModel,
    String? embeddingModel,
    String? answerMode,
    bool? deleteOpenAiFilesAfterProcessing,
    bool? groundednessCheckEnabled,
    bool? offlineFallbackEnabled,
    int? retrievalLimit,
    double? minimumSimilarity,
    VoiceMode? voiceMode,
    String? voiceLocale,
    String? chunkingMode,
    String? localIndexingMode,
    AppNavigationMode? navigationMode,
  }) {
    final effectiveProvider = activeProvider ?? this.activeProvider;
    final aliasesTargetOpenAi = effectiveProvider == AiProvider.openAi;
    final aliasesTargetGemini = effectiveProvider == AiProvider.gemini;
    final requestedRuntimeMode = runtimeMode ?? answerMode ?? this.runtimeMode;
    final effectiveRuntimeMode = requestedRuntimeMode == AnswerModes.autoFallback
        ? AnswerModes.ai
        : requestedRuntimeMode;
    final effectiveOfflineFallback = false;

    return AppSettings(
      runtimeMode: effectiveRuntimeMode,
      activeProvider: effectiveProvider,
      openAiAnswerModel:
          openAiAnswerModel ??
          (aliasesTargetOpenAi ? answerModel : null) ??
          this.openAiAnswerModel,
      openAiExtractionModel:
          openAiExtractionModel ??
          (aliasesTargetOpenAi ? extractionModel : null) ??
          this.openAiExtractionModel,
      openAiGroundednessModel:
          openAiGroundednessModel ??
          (aliasesTargetOpenAi ? groundednessModel : null) ??
          this.openAiGroundednessModel,
      openAiEmbeddingModel:
          openAiEmbeddingModel ??
          (aliasesTargetOpenAi ? embeddingModel : null) ??
          this.openAiEmbeddingModel,
      geminiAnswerModel:
          geminiAnswerModel ??
          (aliasesTargetGemini ? answerModel : null) ??
          this.geminiAnswerModel,
      geminiExtractionModel:
          geminiExtractionModel ??
          (aliasesTargetGemini ? extractionModel : null) ??
          this.geminiExtractionModel,
      geminiGroundednessModel:
          geminiGroundednessModel ??
          (aliasesTargetGemini ? groundednessModel : null) ??
          this.geminiGroundednessModel,
      geminiEmbeddingModel:
          geminiEmbeddingModel ??
          (aliasesTargetGemini ? embeddingModel : null) ??
          this.geminiEmbeddingModel,
      deleteOpenAiFilesAfterProcessing:
          deleteOpenAiFilesAfterProcessing ??
          this.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled:
          groundednessCheckEnabled ?? this.groundednessCheckEnabled,
      offlineFallbackEnabled: effectiveOfflineFallback,
      retrievalLimit: retrievalLimit ?? this.retrievalLimit,
      minimumSimilarity: minimumSimilarity ?? this.minimumSimilarity,
      voiceMode: voiceMode ?? this.voiceMode,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      chunkingMode: ChunkingModes.normalize(chunkingMode ?? this.chunkingMode),
      localIndexingMode: LocalIndexingModes.normalize(
        localIndexingMode ?? this.localIndexingMode,
      ),
      navigationMode: AppNavigationMode.bottomNav,
    );
  }
}
