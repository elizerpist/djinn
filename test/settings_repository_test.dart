import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/data/app_settings_repository.dart';
import 'package:djinn/src/settings/models/app_settings.dart';
import 'package:djinn/src/settings/models/model_catalog.dart';

void main() {
  test('default settings use local ObjectBox mode and OpenAI defaults', () {
    final settings = AppSettings.defaults();

    expect(settings.runtimeMode, 'local_objectbox');
    expect(settings.activeProvider, AiProvider.openAi);
    expect(settings.answerModel, 'gpt-5.5');
    expect(settings.extractionModel, 'gpt-5.5');
    expect(settings.groundednessModel, 'gpt-5.5');
    expect(settings.embeddingModel, 'text-embedding-3-large');
    expect(settings.modelFor(AiProvider.openAi, AiModelSlot.answer), 'gpt-5.5');
    expect(
      settings.modelFor(AiProvider.openAi, AiModelSlot.extraction),
      'gpt-5.5',
    );
    expect(
      settings.modelFor(AiProvider.openAi, AiModelSlot.embedding),
      'text-embedding-3-large',
    );
    expect(
      settings.modelFor(AiProvider.gemini, AiModelSlot.extraction),
      'gemini-2.5-flash-lite',
    );
    expect(
      ModelCatalog.options(AiProvider.openAi, AiModelSlot.answer),
      isNotEmpty,
    );
    expect(
      ModelCatalog.options(AiProvider.gemini, AiModelSlot.extraction),
      isNotEmpty,
    );
    expect(settings.deleteOpenAiFilesAfterProcessing, isTrue);
    expect(settings.groundednessCheckEnabled, isFalse);
    expect(settings.offlineFallbackEnabled, isFalse);
    expect(
      settings.copyWith(offlineFallbackEnabled: true).offlineFallbackEnabled,
      isTrue,
    );
  });

  test('legacy model aliases update Gemini slots when Gemini is active', () {
    final settings = AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
      openAiAnswerModel: 'gpt-openai-answer',
      openAiExtractionModel: 'gpt-openai-extraction',
      geminiAnswerModel: 'gemini-old-answer',
      geminiExtractionModel: 'gemini-old-extraction',
    );

    final updated = settings.copyWith(
      answerModel: 'gemini-2.5-pro',
      extractionModel: 'gemini-2.5-flash',
    );

    expect(updated.geminiAnswerModel, 'gemini-2.5-pro');
    expect(updated.geminiExtractionModel, 'gemini-2.5-flash');
    expect(updated.openAiAnswerModel, 'gpt-openai-answer');
    expect(updated.openAiExtractionModel, 'gpt-openai-extraction');
  });

  test('legacy model aliases update OpenAI slots when OpenAI is active', () {
    final settings = AppSettings.defaults().copyWith(
      activeProvider: AiProvider.openAi,
      openAiAnswerModel: 'gpt-old-answer',
      openAiExtractionModel: 'gpt-old-extraction',
      geminiAnswerModel: 'gemini-2.5-pro',
      geminiExtractionModel: 'gemini-2.5-flash',
    );

    final updated = settings.copyWith(
      answerModel: 'gpt-4.1',
      extractionModel: 'gpt-5-mini',
    );

    expect(updated.openAiAnswerModel, 'gpt-4.1');
    expect(updated.openAiExtractionModel, 'gpt-5-mini');
    expect(updated.geminiAnswerModel, 'gemini-2.5-pro');
    expect(updated.geminiExtractionModel, 'gemini-2.5-flash');
  });

  test('OpenAI answer catalog includes valid mini model name', () {
    final options = ModelCatalog.options(AiProvider.openAi, AiModelSlot.answer);

    expect(options, contains('gpt-5-mini'));
    expect(options, isNot(contains('gpt-5.5-mini')));
  });

  test('memory API key store can save, read, and delete key', () async {
    final store = MemoryApiKeyStore();

    expect(await store.hasKey(), isFalse);
    await store.saveKey('sk-test');
    expect(await store.hasKey(), isTrue);
    expect(await store.readKey(), 'sk-test');
    await store.deleteKey();
    expect(await store.hasKey(), isFalse);
    expect(await store.readKey(), isNull);
  });

  test('memory API key store keeps OpenAI and Gemini keys separate', () async {
    final store = MemoryApiKeyStore();

    await store.saveKeyForProvider(AiProvider.openAi, 'sk-openai');
    await store.saveKeyForProvider(AiProvider.gemini, 'AIza-gemini');

    expect(await store.readKeyForProvider(AiProvider.openAi), 'sk-openai');
    expect(await store.readKeyForProvider(AiProvider.gemini), 'AIza-gemini');
    expect(await store.hasKeyForProvider(AiProvider.openAi), isTrue);
    expect(await store.hasKeyForProvider(AiProvider.gemini), isTrue);

    await store.deleteKeyForProvider(AiProvider.openAi);
    expect(await store.hasKeyForProvider(AiProvider.openAi), isFalse);
    expect(await store.readKeyForProvider(AiProvider.gemini), 'AIza-gemini');
  });

  test('settings repository persists provider-specific models', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-settings-test-',
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

    final repository = AppSettingsRepository(store: objectBox.store);
    final settings = AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
      openAiAnswerModel: 'gpt-5-mini',
      openAiExtractionModel: 'gpt-4.1',
      openAiGroundednessModel: 'gpt-5-mini',
      openAiEmbeddingModel: 'text-embedding-3-small',
      geminiAnswerModel: 'gemini-2.5-pro',
      geminiExtractionModel: 'gemini-2.5-flash',
      geminiGroundednessModel: 'gemini-2.5-flash-lite',
      geminiEmbeddingModel: 'gemini-embedding-001',
      offlineFallbackEnabled: true,
      voiceMode: 'hands_free',
      voiceLocale: 'en-US',
    );

    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.activeProvider, AiProvider.gemini);
    expect(loaded.answerModel, 'gemini-2.5-pro');
    expect(loaded.extractionModel, 'gemini-2.5-flash');
    expect(
      loaded.modelFor(AiProvider.openAi, AiModelSlot.answer),
      'gpt-5-mini',
    );
    expect(loaded.openAiExtractionModel, 'gpt-4.1');
    expect(loaded.openAiEmbeddingModel, 'text-embedding-3-small');
    expect(loaded.geminiEmbeddingModel, 'gemini-embedding-001');
    expect(loaded.offlineFallbackEnabled, isTrue);
    expect(loaded.voiceMode, 'hands_free');
    expect(loaded.voiceLocale, 'en-US');
  });

  test('settings repository preserves zero numeric settings', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-settings-test-',
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

    final repository = AppSettingsRepository(store: objectBox.store);
    final settings = AppSettings.defaults().copyWith(
      retrievalLimit: 0,
      minimumSimilarity: 0.0,
    );

    await repository.save(settings);
    final loaded = await repository.load();

    expect(loaded.retrievalLimit, 0);
    expect(loaded.minimumSimilarity, 0.0);
  });
}
