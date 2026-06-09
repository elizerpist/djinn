import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/data/app_settings_repository.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  test('default settings use local ObjectBox mode and OpenAI defaults', () {
    final settings = AppSettings.defaults();

    expect(settings.runtimeMode, 'local_objectbox');
    expect(settings.aiProvider, 'openai');
    expect(settings.answerModel, 'gpt-5.5');
    expect(settings.extractionModel, 'gpt-5.5');
    expect(settings.groundednessModel, 'gpt-5.5');
    expect(settings.embeddingModel, 'text-embedding-3-large');
    expect(settings.googleAnswerModel, 'gemini-2.5-flash');
    expect(settings.googleEmbeddingModel, 'gemini-embedding-001');
    expect(settings.allowPaidAi, isFalse);
    expect(settings.confirmBeforeAiProcessing, isTrue);
    expect(settings.voiceLocale, 'hu-HU');
    expect(settings.ttsSpeechRate, 0.5);
    expect(settings.ttsPitch, 1.0);
    expect(settings.deleteOpenAiFilesAfterProcessing, isTrue);
    expect(settings.groundednessCheckEnabled, isFalse);
  });

  test('memory API key store isolates OpenAI and Google keys', () async {
    final store = MemoryApiKeyStore();

    expect(await store.hasKey(), isFalse);
    await store.saveKey('sk-test', provider: ApiKeyProvider.openai);
    await store.saveKey('google-test', provider: ApiKeyProvider.google);
    expect(await store.hasKey(provider: ApiKeyProvider.openai), isTrue);
    expect(await store.hasKey(provider: ApiKeyProvider.google), isTrue);
    expect(await store.readKey(provider: ApiKeyProvider.openai), 'sk-test');
    expect(await store.readKey(provider: ApiKeyProvider.google), 'google-test');
    await store.deleteKey(provider: ApiKeyProvider.openai);
    expect(await store.hasKey(), isFalse);
    expect(await store.hasKey(provider: ApiKeyProvider.google), isTrue);
    expect(await store.readKey(provider: ApiKeyProvider.openai), isNull);
  });

  test(
    'legacy ObjectBox settings keep confirmation enabled by default',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-ob-settings-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      objectBox.store.box<AppSettingsEntity>().put(
        AppSettingsEntity(
          runtimeMode: 'local_objectbox',
          aiProvider: '',
          answerModel: 'gpt-5.5',
          extractionModel: 'gpt-5.5',
          groundednessModel: 'gpt-5.5',
          embeddingModel: 'text-embedding-3-large',
          googleAnswerModel: '',
          googleExtractionModel: '',
          googleGroundednessModel: '',
          googleEmbeddingModel: '',
          deleteOpenAiFilesAfterProcessing: true,
          groundednessCheckEnabled: false,
          retrievalLimit: 8,
          minimumSimilarity: 0.72,
          allowPaidAi: false,
          confirmBeforeAiProcessing: false,
          voiceLocale: '',
          ttsSpeechRate: 0,
          ttsPitch: 0,
        ),
      );

      final settings = await AppSettingsRepository(
        store: objectBox.store,
      ).load();

      expect(settings.allowPaidAi, isFalse);
      expect(settings.confirmBeforeAiProcessing, isTrue);
      expect(settings.voiceLocale, 'hu-HU');
    },
  );
}
