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
    final entity = items.isEmpty ? _toEntity(settings) : _toEntity(settings)
      ..id = items.first.id;
    _box.put(entity);
    return settings;
  }

  AppSettings _fromEntity(AppSettingsEntity entity) {
    return AppSettings(
      runtimeMode: entity.runtimeMode,
      answerModel: entity.answerModel,
      extractionModel: entity.extractionModel,
      groundednessModel: entity.groundednessModel,
      embeddingModel: entity.embeddingModel,
      deleteOpenAiFilesAfterProcessing: entity.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled: entity.groundednessCheckEnabled,
      retrievalLimit: entity.retrievalLimit,
      minimumSimilarity: entity.minimumSimilarity,
    );
  }

  AppSettingsEntity _toEntity(AppSettings settings) {
    return AppSettingsEntity(
      runtimeMode: settings.runtimeMode,
      answerModel: settings.answerModel,
      extractionModel: settings.extractionModel,
      groundednessModel: settings.groundednessModel,
      embeddingModel: settings.embeddingModel,
      deleteOpenAiFilesAfterProcessing:
          settings.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled: settings.groundednessCheckEnabled,
      retrievalLimit: settings.retrievalLimit,
      minimumSimilarity: settings.minimumSimilarity,
    );
  }
}
