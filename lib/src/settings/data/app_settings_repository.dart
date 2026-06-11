import 'package:objectbox/objectbox.dart';

import '../../../objectbox.g.dart';
import '../../ai/ai_provider.dart';
import '../../local_store/entities.dart';
import '../models/app_settings.dart';
import '../../voice/voice_mode.dart';

class AppSettingsRepository {
  AppSettingsRepository({required Store store})
    : _box = store.box<AppSettingsEntity>();

  final Box<AppSettingsEntity> _box;

  Future<AppSettings> load() async {
    final items = _box.getAll();
    if (items.isEmpty) {
      return AppSettings.defaults();
    }
    return _fromEntity(_canonicalEntity(items));
  }

  Future<AppSettings> save(AppSettings settings) async {
    final items = _box.getAll();
    final entity = _toEntity(settings);
    if (items.isNotEmpty) {
      entity.id = _canonicalEntity(items).id;
    }
    final savedId = _box.put(entity);
    final duplicateIds = items
        .map((item) => item.id)
        .where((id) => id != savedId)
        .toList(growable: false);
    if (duplicateIds.isNotEmpty) {
      _box.removeMany(duplicateIds);
    }
    return settings;
  }

  AppSettingsEntity _canonicalEntity(List<AppSettingsEntity> items) {
    return items.reduce(
      (current, next) => next.id > current.id ? next : current,
    );
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
      offlineFallbackEnabled: entity.offlineFallbackEnabled,
      retrievalLimit: entity.retrievalLimit,
      minimumSimilarity: entity.minimumSimilarity,
      voiceMode: VoiceMode.fromWireName(entity.voiceMode),
      voiceLocale: _fallback(entity.voiceLocale, defaults.voiceLocale),
      chunkingMode: ChunkingModes.normalize(
        _fallback(entity.chunkingMode, defaults.chunkingMode),
      ),
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
      offlineFallbackEnabled: settings.offlineFallbackEnabled,
      retrievalLimit: settings.retrievalLimit,
      minimumSimilarity: settings.minimumSimilarity,
      voiceMode: settings.voiceMode.wireName,
      voiceLocale: settings.voiceLocale,
      chunkingMode: settings.chunkingMode,
    );
  }

  String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
