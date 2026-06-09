import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:djinn/src/openai/openai_client.dart';
import 'package:djinn/src/openai/openai_http_client.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';

void main() {
  test('reports OpenAI 429 as quota or rate limit error', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKey('sk-test');
    final client = OpenAiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"message":"You exceeded your current quota."}}',
          429,
        ),
      ),
      baseUri: Uri.parse('https://api.openai.test'),
    );

    expect(
      () =>
          client.createEmbedding(input: 'abc', model: 'text-embedding-3-large'),
      throwsA(
        isA<OpenAiException>().having(
          (error) => error.message,
          'message',
          contains('OpenAI quota/rate limit reached (429)'),
        ),
      ),
    );
  });
}
