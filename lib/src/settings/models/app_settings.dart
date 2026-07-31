enum VoiceMode {
  whisperConversation('whisper_conversation'),
  nativeAndroidPtt('native_android_ptt');

  const VoiceMode(this.wireValue);

  final String wireValue;

  static VoiceMode fromStoredValue(String value) {
    switch (value.trim()) {
      case 'whisper_conversation':
      case 'conversation':
      case 'hands_free':
        return VoiceMode.whisperConversation;
      case 'native_android_ptt':
      case 'push_to_talk':
        return VoiceMode.nativeAndroidPtt;
      default:
        return VoiceMode.whisperConversation;
    }
  }
}

class AppSettings {
  const AppSettings({
    required this.runtimeMode,
    required this.answerModel,
    required this.extractionModel,
    required this.groundednessModel,
    required this.embeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      runtimeMode: 'whisper_conversation',
      answerModel: 'gpt-5.5',
      extractionModel: 'gpt-5.5',
      groundednessModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      deleteOpenAiFilesAfterProcessing: true,
      groundednessCheckEnabled: false,
      retrievalLimit: 8,
      minimumSimilarity: 0.72,
    );
  }

  final String runtimeMode;
  final String answerModel;
  final String extractionModel;
  final String groundednessModel;
  final String embeddingModel;
  final bool deleteOpenAiFilesAfterProcessing;
  final bool groundednessCheckEnabled;
  final int retrievalLimit;
  final double minimumSimilarity;

  VoiceMode get voiceMode => VoiceMode.fromStoredValue(runtimeMode);

  AppSettings copyWith({
    String? runtimeMode,
    VoiceMode? voiceMode,
    String? answerModel,
    String? extractionModel,
    String? groundednessModel,
    String? embeddingModel,
    bool? deleteOpenAiFilesAfterProcessing,
    bool? groundednessCheckEnabled,
    int? retrievalLimit,
    double? minimumSimilarity,
  }) {
    final effectiveRuntimeMode =
        runtimeMode ?? voiceMode?.wireValue ?? this.runtimeMode;
    return AppSettings(
      runtimeMode: effectiveRuntimeMode,
      answerModel: answerModel ?? this.answerModel,
      extractionModel: extractionModel ?? this.extractionModel,
      groundednessModel: groundednessModel ?? this.groundednessModel,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      deleteOpenAiFilesAfterProcessing:
          deleteOpenAiFilesAfterProcessing ??
          this.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled:
          groundednessCheckEnabled ?? this.groundednessCheckEnabled,
      retrievalLimit: retrievalLimit ?? this.retrievalLimit,
      minimumSimilarity: minimumSimilarity ?? this.minimumSimilarity,
    );
  }
}
