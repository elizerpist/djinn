import '../../ai/ai_provider.dart';

class ModelCatalog {
  const ModelCatalog._();

  static const openAiAnswerModels = ['gpt-5.5', 'gpt-5-mini', 'gpt-4.1'];
  static const openAiEmbeddingModels = [
    'text-embedding-3-large',
    'text-embedding-3-small',
  ];
  static const geminiTextModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];
  static const geminiEmbeddingModels = ['gemini-embedding-001'];

  static List<String> options(AiProvider provider, AiModelSlot slot) {
    return switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.embedding) => openAiEmbeddingModels,
      (AiProvider.openAi, _) => openAiAnswerModels,
      (AiProvider.gemini, AiModelSlot.embedding) => geminiEmbeddingModels,
      (AiProvider.gemini, _) => geminiTextModels,
    };
  }
}
