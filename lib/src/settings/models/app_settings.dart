import '../../ai/ai_provider.dart';

class AnswerModes {
  static const ai = 'ai';
  static const offline = 'offline_search';
  static const autoFallback = 'auto_fallback';
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
      voiceMode: 'push_to_talk',
      voiceLocale: 'hu-HU',
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
  final String voiceMode;
  final String voiceLocale;

  String get answerMode {
    return switch (runtimeMode) {
      AnswerModes.offline => AnswerModes.offline,
      AnswerModes.autoFallback => AnswerModes.autoFallback,
      _ => offlineFallbackEnabled ? AnswerModes.autoFallback : AnswerModes.ai,
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
    String? voiceMode,
    String? voiceLocale,
  }) {
    final effectiveProvider = activeProvider ?? this.activeProvider;
    final aliasesTargetOpenAi = effectiveProvider == AiProvider.openAi;
    final aliasesTargetGemini = effectiveProvider == AiProvider.gemini;
    final effectiveRuntimeMode = runtimeMode ?? answerMode ?? this.runtimeMode;
    final effectiveOfflineFallback =
        offlineFallbackEnabled ??
        switch (answerMode) {
          AnswerModes.autoFallback => true,
          AnswerModes.ai || AnswerModes.offline => false,
          _ => this.offlineFallbackEnabled,
        };

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
    );
  }
}
