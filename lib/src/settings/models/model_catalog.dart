import '../../ai/ai_provider.dart';

class ModelCatalog {
  const ModelCatalog._();

  static const openAiAnswerModels = ['gpt-5.5', 'gpt-5-mini', 'gpt-4.1'];
  static const openAiEmbeddingModels = [
    'text-embedding-3-large',
    'text-embedding-3-small',
  ];

  static const geminiAnswerModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-3.5-flash',
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite',
    'gemma-4-26b-a4b-it',
    'gemma-4-31b-it',
  ];

  static const geminiTtsModels = [
    'gemini-3.1-flash-tts',
    'gemini-2.5-flash-tts',
  ];

  static const geminiExtractionModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
  ];

  static const geminiGroundednessModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
  ];

  static const geminiEmbeddingModels = [
    'gemini-embedding-2',
    'gemini-embedding-001',
  ];

  static List<String> options(AiProvider provider, AiModelSlot slot) {
    return switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.embedding) => openAiEmbeddingModels,
      (AiProvider.openAi, _) => openAiAnswerModels,
      (AiProvider.gemini, AiModelSlot.answer) => geminiAnswerModels,
      (AiProvider.gemini, AiModelSlot.extraction) => geminiExtractionModels,
      (AiProvider.gemini, AiModelSlot.groundedness) => geminiGroundednessModels,
      (AiProvider.gemini, AiModelSlot.embedding) => geminiEmbeddingModels,
    };
  }

  static String defaultFor(AiProvider provider, AiModelSlot slot) {
    return switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.embedding) => 'text-embedding-3-large',
      (AiProvider.openAi, _) => 'gpt-5.5',
      (AiProvider.gemini, AiModelSlot.embedding) => 'gemini-embedding-001',
      (AiProvider.gemini, _) => 'gemini-2.5-flash-lite',
    };
  }

  static String sanitize(AiProvider provider, AiModelSlot slot, String model) {
    final trimmed = model.trim();
    final slotOptions = options(provider, slot);
    return slotOptions.contains(trimmed) ? trimmed : defaultFor(provider, slot);
  }
}
