import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  test('default settings use local ObjectBox mode and OpenAI defaults', () {
    final settings = AppSettings.defaults();

    expect(settings.runtimeMode, 'local_objectbox');
    expect(settings.answerModel, 'gpt-5.5');
    expect(settings.extractionModel, 'gpt-5.5');
    expect(settings.groundednessModel, 'gpt-5.5');
    expect(settings.embeddingModel, 'text-embedding-3-large');
    expect(settings.deleteOpenAiFilesAfterProcessing, isTrue);
    expect(settings.groundednessCheckEnabled, isFalse);
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
