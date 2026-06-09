import 'package:objectbox/objectbox.dart';

import '../../../objectbox.g.dart';
import '../../ai/ai_provider.dart';
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
    final entity = items.isEmpty ? _toEntity(settings) : _toEntity(settings)
      ..id = items.first.id;
    _box.put(entity);
    return settings;
  }

  AppSettings _fromEntity(AppSettingsEntity entity) {
    final defaults = AppSettings.defaults();
    final activeProvider = entity.activeProvider.trim().isEmpty
        ? defaults.activeProvider
        : AiProvider.fromWireName(entity.activeProvider);
    final openAiAnswerModel = _fallback(
      entity.openAiAnswerModel,
      _fallback(entity.answerModel, defaults.openAiAnswerModel),
    );
    final openAiExtractionModel = _fallback(
      entity.openAiExtractionModel,
      _fallback(entity.extractionModel, defaults.openAiExtractionModel),
    );
    final openAiGroundednessModel = _fallback(
      entity.openAiGroundednessModel,
      _fallback(entity.groundednessModel, defaults.openAiGroundednessModel),
    );
    final openAiEmbeddingModel = _fallback(
      entity.openAiEmbeddingModel,
      _fallback(entity.embeddingModel, defaults.openAiEmbeddingModel),
    );

    return AppSettings(
      runtimeMode: _fallback(entity.runtimeMode, defaults.runtimeMode),
      activeProvider: activeProvider,
      openAiAnswerModel: openAiAnswerModel,
      openAiExtractionModel: openAiExtractionModel,
      openAiGroundednessModel: openAiGroundednessModel,
      openAiEmbeddingModel: openAiEmbeddingModel,
      geminiAnswerModel: _fallback(
        entity.geminiAnswerModel,
        defaults.geminiAnswerModel,
      ),
      geminiExtractionModel: _fallback(
        entity.geminiExtractionModel,
        defaults.geminiExtractionModel,
      ),
      geminiGroundednessModel: _fallback(
        entity.geminiGroundednessModel,
        defaults.geminiGroundednessModel,
      ),
      geminiEmbeddingModel: _fallback(
        entity.geminiEmbeddingModel,
        defaults.geminiEmbeddingModel,
      ),
      deleteOpenAiFilesAfterProcessing: entity.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled: entity.groundednessCheckEnabled,
      retrievalLimit: entity.retrievalLimit,
      minimumSimilarity: entity.minimumSimilarity,
      voiceMode: _fallback(entity.voiceMode, defaults.voiceMode),
      voiceLocale: _fallback(entity.voiceLocale, defaults.voiceLocale),
    );
  }

  AppSettingsEntity _toEntity(AppSettings settings) {
    return AppSettingsEntity(
      runtimeMode: settings.runtimeMode,
      activeProvider: settings.activeProvider.wireName,
      openAiAnswerModel: settings.openAiAnswerModel,
      openAiExtractionModel: settings.openAiExtractionModel,
      openAiGroundednessModel: settings.openAiGroundednessModel,
      openAiEmbeddingModel: settings.openAiEmbeddingModel,
      geminiAnswerModel: settings.geminiAnswerModel,
      geminiExtractionModel: settings.geminiExtractionModel,
      geminiGroundednessModel: settings.geminiGroundednessModel,
      geminiEmbeddingModel: settings.geminiEmbeddingModel,
      answerModel: settings.openAiAnswerModel,
      extractionModel: settings.openAiExtractionModel,
      groundednessModel: settings.openAiGroundednessModel,
      embeddingModel: settings.openAiEmbeddingModel,
      deleteOpenAiFilesAfterProcessing:
          settings.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled: settings.groundednessCheckEnabled,
      retrievalLimit: settings.retrievalLimit,
      minimumSimilarity: settings.minimumSimilarity,
      voiceMode: settings.voiceMode,
      voiceLocale: settings.voiceLocale,
    );
  }

  String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
