import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ApiKeyProvider {
  openai('openai', 'openai_api_key'),
  google('google', 'google_api_key');

  const ApiKeyProvider(this.wireName, this.storageKey);

  final String wireName;
  final String storageKey;
}

abstract class ApiKeyStore {
  Future<bool> hasKey({ApiKeyProvider provider = ApiKeyProvider.openai});
  Future<String?> readKey({ApiKeyProvider provider = ApiKeyProvider.openai});
  Future<void> saveKey(
    String value, {
    ApiKeyProvider provider = ApiKeyProvider.openai,
  });
  Future<void> deleteKey({ApiKeyProvider provider = ApiKeyProvider.openai});
}

class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasKey({ApiKeyProvider provider = ApiKeyProvider.openai}) async {
    final value = await readKey(provider: provider);
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readKey({ApiKeyProvider provider = ApiKeyProvider.openai}) {
    return _storage.read(key: provider.storageKey);
  }

  @override
  Future<void> saveKey(
    String value, {
    ApiKeyProvider provider = ApiKeyProvider.openai,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('${provider.wireName} API key must not be blank');
    }
    await _storage.write(key: provider.storageKey, value: trimmed);
  }

  @override
  Future<void> deleteKey({ApiKeyProvider provider = ApiKeyProvider.openai}) {
    return _storage.delete(key: provider.storageKey);
  }
}

class MemoryApiKeyStore implements ApiKeyStore {
  final Map<ApiKeyProvider, String> _values = {};

  @override
  Future<bool> hasKey({ApiKeyProvider provider = ApiKeyProvider.openai}) async {
    final value = _values[provider];
    return value != null && value.isNotEmpty;
  }

  @override
  Future<String?> readKey({
    ApiKeyProvider provider = ApiKeyProvider.openai,
  }) async {
    return _values[provider];
  }

  @override
  Future<void> saveKey(
    String value, {
    ApiKeyProvider provider = ApiKeyProvider.openai,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('${provider.wireName} API key must not be blank');
    }
    _values[provider] = trimmed;
  }

  @override
  Future<void> deleteKey({
    ApiKeyProvider provider = ApiKeyProvider.openai,
  }) async {
    _values.remove(provider);
  }
}
