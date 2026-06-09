import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../ai/ai_provider.dart';

abstract class ApiKeyStore {
  Future<bool> hasKey() => hasKeyForProvider(AiProvider.openAi);
  Future<String?> readKey() => readKeyForProvider(AiProvider.openAi);
  Future<void> saveKey(String value) =>
      saveKeyForProvider(AiProvider.openAi, value);
  Future<void> deleteKey() => deleteKeyForProvider(AiProvider.openAi);

  Future<bool> hasKeyForProvider(AiProvider provider) async {
    final value = await readKeyForProvider(provider);
    return value != null && value.trim().isNotEmpty;
  }

  Future<String?> readKeyForProvider(AiProvider provider);
  Future<void> saveKeyForProvider(AiProvider provider, String value);
  Future<void> deleteKeyForProvider(AiProvider provider);
}

class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String keyNameForProvider(AiProvider provider) {
    return switch (provider) {
      AiProvider.openAi => 'openai_api_key',
      AiProvider.gemini => 'gemini_api_key',
    };
  }

  @override
  Future<bool> hasKey() => hasKeyForProvider(AiProvider.openAi);

  @override
  Future<String?> readKey() => readKeyForProvider(AiProvider.openAi);

  @override
  Future<void> saveKey(String value) =>
      saveKeyForProvider(AiProvider.openAi, value);

  @override
  Future<void> deleteKey() => deleteKeyForProvider(AiProvider.openAi);

  @override
  Future<bool> hasKeyForProvider(AiProvider provider) async {
    final value = await readKeyForProvider(provider);
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readKeyForProvider(AiProvider provider) {
    return _storage.read(key: keyNameForProvider(provider));
  }

  @override
  Future<void> saveKeyForProvider(AiProvider provider, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('${provider.label} API key must not be blank');
    }
    await _storage.write(key: keyNameForProvider(provider), value: trimmed);
  }

  @override
  Future<void> deleteKeyForProvider(AiProvider provider) {
    return _storage.delete(key: keyNameForProvider(provider));
  }
}

class MemoryApiKeyStore implements ApiKeyStore {
  final Map<AiProvider, String> _values = {};

  @override
  Future<bool> hasKey() => hasKeyForProvider(AiProvider.openAi);

  @override
  Future<String?> readKey() => readKeyForProvider(AiProvider.openAi);

  @override
  Future<void> saveKey(String value) =>
      saveKeyForProvider(AiProvider.openAi, value);

  @override
  Future<void> deleteKey() => deleteKeyForProvider(AiProvider.openAi);

  @override
  Future<bool> hasKeyForProvider(AiProvider provider) async {
    final value = await readKeyForProvider(provider);
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readKeyForProvider(AiProvider provider) async {
    return _values[provider];
  }

  @override
  Future<void> saveKeyForProvider(AiProvider provider, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('${provider.label} API key must not be blank');
    }
    _values[provider] = trimmed;
  }

  @override
  Future<void> deleteKeyForProvider(AiProvider provider) async {
    _values.remove(provider);
  }
}
