import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:djinn/src/ai/gemini_ai_client.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';

void main() {
  test('Gemini key test succeeds against model list endpoint', () async {
    final store = MemoryApiKeyStore();
    await store.saveKey('google-test', provider: ApiKeyProvider.google);
    final client = GeminiAiClient(
      apiKeyStore: store,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1beta/models');
        expect(request.headers['x-goog-api-key'], 'google-test');
        return http.Response(jsonEncode({'models': []}), 200);
      }),
    );

    await client.testApiKey(apiKey: 'google-test');
  });

  test('Gemini embedding requests 3072 dimensions', () async {
    final store = MemoryApiKeyStore();
    await store.saveKey('google-test', provider: ApiKeyProvider.google);
    final client = GeminiAiClient(
      apiKeyStore: store,
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['outputDimensionality'], 3072);
        return http.Response(
          jsonEncode({
            'embedding': {'values': List<double>.filled(3072, 0.25)},
          }),
          200,
        );
      }),
    );

    final embedding = await client.createEmbedding(
      input: 'ABCDE',
      model: 'gemini-embedding-001',
    );

    expect(embedding, hasLength(3072));
  });

  test(
    'Gemini extraction parses chunks and flowcharts from JSON text',
    () async {
      final store = MemoryApiKeyStore();
      await store.saveKey('google-test', provider: ApiKeyProvider.google);
      final client = GeminiAiClient(
        apiKeyStore: store,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'chunks': [
                            {
                              'id': 'p1-main',
                              'text': 'Protocol text',
                              'page_number': 1,
                              'section_title': null,
                            },
                          ],
                          'flowcharts': [
                            {
                              'id': 'flow-1',
                              'title': 'ABCDE',
                              'page_number': 2,
                              'confidence': 0.8,
                              'nodes': [
                                {'id': 'a', 'label': 'Airway'},
                                {'id': 'b', 'label': 'Breathing'},
                              ],
                              'edges': [
                                {
                                  'id': 'a-b',
                                  'from_node_id': 'a',
                                  'to_node_id': 'b',
                                  'label': 'then',
                                },
                              ],
                            },
                          ],
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await client.extractDocument(
        pdfPath: '/tmp/protocol.pdf',
        model: 'gemini-2.5-flash',
      );

      expect(result.chunks.single.id, 'p1-main');
      expect(result.flowcharts.single.title, 'ABCDE');
      expect(result.flowcharts.single.edges.single.fromNodeId, 'a');
    },
  );

  test('Gemini 429 produces provider exception with billing context', () async {
    final store = MemoryApiKeyStore();
    await store.saveKey('google-test', provider: ApiKeyProvider.google);
    final client = GeminiAiClient(
      apiKeyStore: store,
      httpClient: MockClient((_) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'quota exceeded'},
          }),
          429,
        );
      }),
    );

    expect(
      () =>
          client.createEmbedding(input: 'ABCDE', model: 'gemini-embedding-001'),
      throwsA(
        isA<GeminiException>().having(
          (error) => error.message,
          'message',
          contains('Google Gemini quota/rate limit reached'),
        ),
      ),
    );
  });
}
