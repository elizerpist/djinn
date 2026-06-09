class AppSettings {
  const AppSettings({
    required this.runtimeMode,
    required this.aiProvider,
    required this.answerModel,
    required this.extractionModel,
    required this.groundednessModel,
    required this.embeddingModel,
    required this.googleAnswerModel,
    required this.googleExtractionModel,
    required this.googleGroundednessModel,
    required this.googleEmbeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
    required this.allowPaidAi,
    required this.confirmBeforeAiProcessing,
    required this.voiceLocale,
    required this.ttsSpeechRate,
    required this.ttsPitch,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      runtimeMode: 'local_objectbox',
      aiProvider: 'openai',
      answerModel: 'gpt-5.5',
      extractionModel: 'gpt-5.5',
      groundednessModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      googleAnswerModel: 'gemini-2.5-flash',
      googleExtractionModel: 'gemini-2.5-flash',
      googleGroundednessModel: 'gemini-2.5-flash',
      googleEmbeddingModel: 'gemini-embedding-001',
      deleteOpenAiFilesAfterProcessing: true,
      groundednessCheckEnabled: false,
      retrievalLimit: 8,
      minimumSimilarity: 0.72,
      allowPaidAi: false,
      confirmBeforeAiProcessing: true,
      voiceLocale: 'hu-HU',
      ttsSpeechRate: 0.5,
      ttsPitch: 1.0,
    );
  }

  final String runtimeMode;
  final String aiProvider;
  final String answerModel;
  final String extractionModel;
  final String groundednessModel;
  final String embeddingModel;
  final String googleAnswerModel;
  final String googleExtractionModel;
  final String googleGroundednessModel;
  final String googleEmbeddingModel;
  final bool deleteOpenAiFilesAfterProcessing;
  final bool groundednessCheckEnabled;
  final int retrievalLimit;
  final double minimumSimilarity;
  final bool allowPaidAi;
  final bool confirmBeforeAiProcessing;
  final String voiceLocale;
  final double ttsSpeechRate;
  final double ttsPitch;

  bool get usesGoogle => aiProvider == 'google';

  String get activeAnswerModel => usesGoogle ? googleAnswerModel : answerModel;

  String get activeExtractionModel =>
      usesGoogle ? googleExtractionModel : extractionModel;

  String get activeGroundednessModel =>
      usesGoogle ? googleGroundednessModel : groundednessModel;

  String get activeEmbeddingModel =>
      usesGoogle ? googleEmbeddingModel : embeddingModel;

  AppSettings copyWith({
    String? runtimeMode,
    String? aiProvider,
    String? answerModel,
    String? extractionModel,
    String? groundednessModel,
    String? embeddingModel,
    String? googleAnswerModel,
    String? googleExtractionModel,
    String? googleGroundednessModel,
    String? googleEmbeddingModel,
    bool? deleteOpenAiFilesAfterProcessing,
    bool? groundednessCheckEnabled,
    int? retrievalLimit,
    double? minimumSimilarity,
    bool? allowPaidAi,
    bool? confirmBeforeAiProcessing,
    String? voiceLocale,
    double? ttsSpeechRate,
    double? ttsPitch,
  }) {
    return AppSettings(
      runtimeMode: runtimeMode ?? this.runtimeMode,
      aiProvider: aiProvider ?? this.aiProvider,
      answerModel: answerModel ?? this.answerModel,
      extractionModel: extractionModel ?? this.extractionModel,
      groundednessModel: groundednessModel ?? this.groundednessModel,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      googleAnswerModel: googleAnswerModel ?? this.googleAnswerModel,
      googleExtractionModel:
          googleExtractionModel ?? this.googleExtractionModel,
      googleGroundednessModel:
          googleGroundednessModel ?? this.googleGroundednessModel,
      googleEmbeddingModel: googleEmbeddingModel ?? this.googleEmbeddingModel,
      deleteOpenAiFilesAfterProcessing:
          deleteOpenAiFilesAfterProcessing ??
          this.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled:
          groundednessCheckEnabled ?? this.groundednessCheckEnabled,
      retrievalLimit: retrievalLimit ?? this.retrievalLimit,
      minimumSimilarity: minimumSimilarity ?? this.minimumSimilarity,
      allowPaidAi: allowPaidAi ?? this.allowPaidAi,
      confirmBeforeAiProcessing:
          confirmBeforeAiProcessing ?? this.confirmBeforeAiProcessing,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
    );
  }
}
