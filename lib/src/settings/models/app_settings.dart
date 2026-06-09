import '../../ai/ai_provider.dart';

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
  final int retrievalLimit;
  final double minimumSimilarity;
  final String voiceMode;
  final String voiceLocale;

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
    bool? deleteOpenAiFilesAfterProcessing,
    bool? groundednessCheckEnabled,
    int? retrievalLimit,
    double? minimumSimilarity,
    String? voiceMode,
    String? voiceLocale,
  }) {
    return AppSettings(
      runtimeMode: runtimeMode ?? this.runtimeMode,
      activeProvider: activeProvider ?? this.activeProvider,
      openAiAnswerModel:
          openAiAnswerModel ?? answerModel ?? this.openAiAnswerModel,
      openAiExtractionModel:
          openAiExtractionModel ??
          extractionModel ??
          this.openAiExtractionModel,
      openAiGroundednessModel:
          openAiGroundednessModel ??
          groundednessModel ??
          this.openAiGroundednessModel,
      openAiEmbeddingModel:
          openAiEmbeddingModel ?? embeddingModel ?? this.openAiEmbeddingModel,
      geminiAnswerModel: geminiAnswerModel ?? this.geminiAnswerModel,
      geminiExtractionModel:
          geminiExtractionModel ?? this.geminiExtractionModel,
      geminiGroundednessModel:
          geminiGroundednessModel ?? this.geminiGroundednessModel,
      geminiEmbeddingModel: geminiEmbeddingModel ?? this.geminiEmbeddingModel,
      deleteOpenAiFilesAfterProcessing:
          deleteOpenAiFilesAfterProcessing ??
          this.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled:
          groundednessCheckEnabled ?? this.groundednessCheckEnabled,
      retrievalLimit: retrievalLimit ?? this.retrievalLimit,
      minimumSimilarity: minimumSimilarity ?? this.minimumSimilarity,
      voiceMode: voiceMode ?? this.voiceMode,
      voiceLocale: voiceLocale ?? this.voiceLocale,
    );
  }
}
