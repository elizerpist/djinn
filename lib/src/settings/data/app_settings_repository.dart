import 'package:objectbox/objectbox.dart';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../models/app_settings.dart';

class AppSettingsRepository {
  AppSettingsRepository({required Store store})
    : _box = store.box<AppSettingsEntity>();

  final Box<AppSettingsEntity> _box;

  Future<AppSettings> load() async {
    final items = _box.getAll();
    if (items.isEmpty) {
      return AppSettings.defaults();
    }
    return _fromEntity(items.first);
  }

  Future<AppSettings> save(AppSettings settings) async {
    final items = _box.getAll();
    final entity = _toEntity(settings);
    if (items.isNotEmpty) {
      entity.id = items.first.id;
    }
    _box.put(entity);
    return settings;
  }

  AppSettings _fromEntity(AppSettingsEntity entity) {
    final defaults = AppSettings.defaults();
    final legacyEntity =
        entity.aiProvider.isEmpty &&
        entity.googleAnswerModel.isEmpty &&
        entity.googleExtractionModel.isEmpty &&
        entity.googleGroundednessModel.isEmpty &&
        entity.googleEmbeddingModel.isEmpty &&
        entity.voiceLocale.isEmpty &&
        entity.ttsSpeechRate == 0 &&
        entity.ttsPitch == 0;
    return AppSettings(
      runtimeMode: entity.runtimeMode,
      aiProvider: entity.aiProvider.isEmpty ? 'openai' : entity.aiProvider,
      answerModel: entity.answerModel,
      extractionModel: entity.extractionModel,
      groundednessModel: entity.groundednessModel,
      embeddingModel: entity.embeddingModel,
      googleAnswerModel: entity.googleAnswerModel.isEmpty
          ? 'gemini-2.5-flash'
          : entity.googleAnswerModel,
      googleExtractionModel: entity.googleExtractionModel.isEmpty
          ? 'gemini-2.5-flash'
          : entity.googleExtractionModel,
      googleGroundednessModel: entity.googleGroundednessModel.isEmpty
          ? 'gemini-2.5-flash'
          : entity.googleGroundednessModel,
      googleEmbeddingModel: entity.googleEmbeddingModel.isEmpty
          ? 'gemini-embedding-001'
          : entity.googleEmbeddingModel,
      deleteOpenAiFilesAfterProcessing: entity.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled: entity.groundednessCheckEnabled,
      retrievalLimit: entity.retrievalLimit,
      minimumSimilarity: entity.minimumSimilarity,
      allowPaidAi: legacyEntity ? defaults.allowPaidAi : entity.allowPaidAi,
      confirmBeforeAiProcessing: legacyEntity
          ? defaults.confirmBeforeAiProcessing
          : entity.confirmBeforeAiProcessing,
      voiceLocale: entity.voiceLocale.isEmpty
          ? defaults.voiceLocale
          : entity.voiceLocale,
      ttsSpeechRate: entity.ttsSpeechRate == 0
          ? defaults.ttsSpeechRate
          : entity.ttsSpeechRate,
      ttsPitch: entity.ttsPitch == 0 ? defaults.ttsPitch : entity.ttsPitch,
    );
  }

  AppSettingsEntity _toEntity(AppSettings settings) {
    return AppSettingsEntity(
      runtimeMode: settings.runtimeMode,
      aiProvider: settings.aiProvider,
      answerModel: settings.answerModel,
      extractionModel: settings.extractionModel,
      groundednessModel: settings.groundednessModel,
      embeddingModel: settings.embeddingModel,
      googleAnswerModel: settings.googleAnswerModel,
      googleExtractionModel: settings.googleExtractionModel,
      googleGroundednessModel: settings.googleGroundednessModel,
      googleEmbeddingModel: settings.googleEmbeddingModel,
      deleteOpenAiFilesAfterProcessing:
          settings.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled: settings.groundednessCheckEnabled,
      retrievalLimit: settings.retrievalLimit,
      minimumSimilarity: settings.minimumSimilarity,
      allowPaidAi: settings.allowPaidAi,
      confirmBeforeAiProcessing: settings.confirmBeforeAiProcessing,
      voiceLocale: settings.voiceLocale,
      ttsSpeechRate: settings.ttsSpeechRate,
      ttsPitch: settings.ttsPitch,
    );
  }
}
