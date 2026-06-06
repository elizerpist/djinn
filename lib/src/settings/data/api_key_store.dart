import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ApiKeyStore {
  Future<bool> hasKey();
  Future<String?> readKey();
  Future<void> saveKey(String value);
  Future<void> deleteKey();
}

class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'openai_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasKey() async {
    final value = await readKey();
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readKey() => _storage.read(key: _key);

  @override
  Future<void> saveKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('OpenAI API key must not be blank');
    }
    await _storage.write(key: _key, value: trimmed);
  }

  @override
  Future<void> deleteKey() => _storage.delete(key: _key);
}

class MemoryApiKeyStore implements ApiKeyStore {
  String? _value;

  @override
  Future<bool> hasKey() async => _value != null && _value!.isNotEmpty;

  @override
  Future<String?> readKey() async => _value;

  @override
  Future<void> saveKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('OpenAI API key must not be blank');
    }
    _value = trimmed;
  }

  @override
  Future<void> deleteKey() async {
    _value = null;
  }
}
