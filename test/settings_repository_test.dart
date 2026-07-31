import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/settings/data/app_settings_repository.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  test('default settings use whisper conversation and OpenAI defaults', () {
    final settings = AppSettings.defaults();

    expect(settings.runtimeMode, 'whisper_conversation');
    expect(settings.voiceMode, VoiceMode.whisperConversation);
    expect(settings.answerModel, 'gpt-5.5');
    expect(settings.extractionModel, 'gpt-5.5');
    expect(settings.groundednessModel, 'gpt-5.5');
    expect(settings.embeddingModel, 'text-embedding-3-large');
    expect(settings.deleteOpenAiFilesAfterProcessing, isTrue);
    expect(settings.groundednessCheckEnabled, isFalse);
  });

  test('parses legacy voice mode strings from stored values', () {
    expect(
      VoiceMode.fromStoredValue('push_to_talk'),
      VoiceMode.nativeAndroidPtt,
    );
    expect(
      VoiceMode.fromStoredValue('conversation'),
      VoiceMode.whisperConversation,
    );
    expect(
      VoiceMode.fromStoredValue('hands_free'),
      VoiceMode.whisperConversation,
    );
  });

  test('persists voice mode strings through ObjectBox without schema changes', (
    ) async {
    final directory = await Directory.systemTemp.createTemp('djinn-settings-');
    addTearDown(() => directory.delete(recursive: true));
    final ObjectBoxStore objectBox;
    try {
      objectBox = await ObjectBoxStore.open(directory: directory);
    } on ArgumentError catch (error) {
      markTestSkipped('Host ObjectBox library unavailable: $error');
      return;
    }
    addTearDown(objectBox.close);

    final firstRepository = AppSettingsRepository(store: objectBox.store);
    await firstRepository.save(
      AppSettings.defaults().copyWith(voiceMode: VoiceMode.nativeAndroidPtt),
    );

    final secondRepository = AppSettingsRepository(store: objectBox.store);
    final loaded = await secondRepository.load();

    expect(loaded.runtimeMode, 'native_android_ptt');
    expect(loaded.voiceMode, VoiceMode.nativeAndroidPtt);
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
}
