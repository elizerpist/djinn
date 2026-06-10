import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/ai/ai_error.dart';
import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/google/gemini_http_client.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';

void main() {
  test('sends Gemini extraction with JSON mime type and schema', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    final tempDir = await Directory.systemTemp.createTemp('djinn_gemini_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final pdf = File('${tempDir.path}/source.pdf');
    await pdf.writeAsBytes([1, 2, 3]);

    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/v1beta/models/gemini-2.5-flash:generateContent',
        );
        expect(request.url.queryParameters['key'], 'gemini-key');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.body, contains('"responseMimeType":"application/json"'));
        expect(request.body, contains('"responseSchema"'));
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final generationConfig =
            body['generationConfig'] as Map<String, Object?>;
        final schema =
            generationConfig['responseSchema'] as Map<String, Object?>;
        _expectNoTypeLists(schema);
        final properties = schema['properties'] as Map<String, Object?>;
        final chunks = properties['chunks'] as Map<String, Object?>;
        final items = chunks['items'] as Map<String, Object?>;
        final chunkProperties = items['properties'] as Map<String, Object?>;
        final sectionTitle =
            chunkProperties['section_title'] as Map<String, Object?>;
        expect(sectionTitle['type'], 'string');
        expect(sectionTitle['nullable'], isTrue);

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
                            'text': 'abc',
                            'page_number': 1,
                            'section_title': null,
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
      baseUri: Uri.parse('https://gemini.test'),
    );

    final result = await client.extractDocument(
      pdfPath: pdf.path,
      model: 'gemini-2.5-flash',
    );

    expect(result.chunks.single.id, 'p1-main');
  });

  test(
    'sends Gemini answer schema with nullable fields as Gemini schema',
    () async {
      final keyStore = MemoryApiKeyStore();
      await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');

      final client = GeminiHttpClient(
        apiKeyStore: keyStore,
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/v1beta/models/gemini-2.5-flash:generateContent',
          );
          final body = jsonDecode(request.body) as Map<String, Object?>;
          final generationConfig =
              body['generationConfig'] as Map<String, Object?>;
          final schema =
              generationConfig['responseSchema'] as Map<String, Object?>;
          _expectNoTypeLists(schema);
          final properties = schema['properties'] as Map<String, Object?>;
          final refusalReason =
              properties['refusal_reason'] as Map<String, Object?>;
          expect(refusalReason['type'], 'string');
          expect(refusalReason['nullable'], isTrue);

          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'answer': 'válasz',
                          'cited_source_ids': ['e1'],
                          'abstain': false,
                          'refusal_reason': null,
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
        baseUri: Uri.parse('https://gemini.test'),
      );

      final result = await client.generateAnswer(
        model: 'gemini-2.5-flash',
        question: 'Mi a teendő?',
        evidence: const [AiEvidence(id: 'e1', label: 'Forrás', text: 'Szöveg')],
      );

      expect(result.answer, 'válasz');
    },
  );

  test('maps Gemini 503 to retryable high demand failure', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"message":"The model is currently overloaded."}}',
          503,
        ),
      ),
      baseUri: Uri.parse('https://gemini.test'),
    );

    expect(
      () => client.createEmbedding(input: 'abc', model: 'gemini-embedding-001'),
      throwsA(
        isA<AiProviderException>()
            .having(
              (error) => error.failure.code,
              'code',
              AiFailureCode.highDemand,
            )
            .having((error) => error.failure.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('redacts Gemini API keys from provider failure messages', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient(
        (_) async => http.Response(
          'upstream echoed /v1beta/models/gemini-embedding-001:embedContent?key=gemini-key',
          502,
        ),
      ),
      baseUri: Uri.parse('https://gemini.test'),
    );

    await expectLater(
      client.createEmbedding(input: 'abc', model: 'gemini-embedding-001'),
      throwsA(
        isA<AiProviderException>().having(
          (error) => error.failure.message,
          'message',
          isNot(contains('gemini-key')),
        ),
      ),
    );
  });

  test(
    'maps invalid Gemini structured response to validation failure',
    () async {
      final keyStore = MemoryApiKeyStore();
      await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
      final tempDir = await Directory.systemTemp.createTemp(
        'djinn_gemini_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final client = GeminiHttpClient(
        apiKeyStore: keyStore,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"not_chunks":[]}'},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
        baseUri: Uri.parse('https://gemini.test'),
      );

      expect(
        () => client.extractDocument(
          pdfPath: '${tempDir.path}/missing.pdf',
          model: 'gemini-2.5-flash',
        ),
        throwsA(
          isA<AiProviderException>().having(
            (error) => error.failure.code,
            'code',
            AiFailureCode.invalidStructuredResponse,
          ),
        ),
      );
    },
  );
}

void _expectNoTypeLists(Map<String, Object?> schema) {
  final type = schema['type'];
  expect(type, isNot(isA<List<Object?>>()));
  final properties = schema['properties'];
  if (properties is Map) {
    for (final value in properties.values) {
      if (value is Map<String, Object?>) {
        _expectNoTypeLists(value);
      }
    }
  }
  final items = schema['items'];
  if (items is Map<String, Object?>) {
    _expectNoTypeLists(items);
  }
}
