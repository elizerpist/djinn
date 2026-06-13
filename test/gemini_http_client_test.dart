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
  test(
    'tests the selected Gemini model instead of hard-coded Flash Lite',
    () async {
      final keyStore = MemoryApiKeyStore();
      var requestedPath = '';

      final client = GeminiHttpClient(
        apiKeyStore: keyStore,
        httpClient: MockClient((request) async {
          requestedPath = request.url.path;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'pong'},
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

      await client.testApiKey(
        apiKey: 'gemini-key',
        model: 'gemma-4-26b-a4b-it',
      );

      expect(
        requestedPath,
        '/v1beta/models/gemma-4-26b-a4b-it:generateContent',
      );
    },
  );

  test('maps Gemini quota test failure without calling it an API key error', () {
    final client = GeminiHttpClient(
      apiKeyStore: MemoryApiKeyStore(),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"message":"Quota exceeded for metric: generate_content_free_tier_requests, model: gemini-2.5-flash-lite"}}',
          429,
        ),
      ),
      baseUri: Uri.parse('https://gemini.test'),
    );

    expect(
      () => client.testApiKey(
        apiKey: 'gemini-key',
        model: 'gemini-2.5-flash-lite',
      ),
      throwsA(
        isA<AiProviderException>()
            .having(
              (error) => error.failure.code,
              'code',
              AiFailureCode.quotaOrBilling,
            )
            .having(
              (error) => error.failure.userMessage,
              'userMessage',
              allOf(contains('kvota'), contains('gemini-2.5-flash-lite')),
            )
            .having(
              (error) => error.failure.userMessage,
              'userMessage',
              isNot(contains('kulcs hibas')),
            ),
      ),
    );
  });

  test('allows Gemini Embedding 2 for vector creation', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    var requestedPath = '';

    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'embedding': {
              'values': [0.1, 0.2, 0.3],
            },
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://gemini.test'),
    );

    final vector = await client.createEmbedding(
      input: 'stroke',
      model: 'gemini-embedding-2',
    );

    expect(requestedPath, '/v1beta/models/gemini-embedding-2:embedContent');
    expect(vector, [0.1, 0.2, 0.3]);
  });

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
                        'tables': [],
                        'scores': [],
                        'flowcharts': [],
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
      chunkingMode: 'normal',
    );

    expect(result.chunks.single.id, 'p1-main');
  });

  test('sends PNG documents to Gemini with image/png inline data', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    final tempDir = await Directory.systemTemp.createTemp('djinn_gemini_png_');
    addTearDown(() => tempDir.delete(recursive: true));
    final png = File('${tempDir.path}/flowchart.png');
    await png.writeAsBytes([137, 80, 78, 71]);

    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final contents = body['contents'] as List;
        final message = contents.single as Map;
        final parts = message['parts'] as List;
        final inlineData = parts
            .whereType<Map>()
            .map((item) => item['inlineData'])
            .whereType<Map>()
            .single;
        expect(inlineData['mimeType'], 'image/png');
        expect(inlineData['data'], base64Encode([137, 80, 78, 71]));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'chunks': [],
                        'tables': [],
                        'scores': [],
                        'flowcharts': [],
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
      pdfPath: png.path,
      model: 'gemini-2.5-flash',
      chunkingMode: 'normal',
    );

    expect(result.chunks, isEmpty);
  });

  test('parses Gemini tables scores and flowchart candidates', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
    final tempDir = await Directory.systemTemp.createTemp('djinn_gemini_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final pdf = File('${tempDir.path}/rave.pdf');
    await pdf.writeAsBytes([1, 2, 3]);

    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((request) async {
        expect(request.body, contains('"tables"'));
        expect(request.body, contains('"scores"'));
        expect(request.body, contains('"flowcharts"'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'chunks': [],
                        'tables': [
                          {
                            'id': 'table-1',
                            'page_number': 2,
                            'title': 'RAVE score',
                            'rows': [
                              {
                                'label': 'Arcparesis',
                                'value': '1',
                                'text': 'Arcparesis - 1 pont',
                              },
                            ],
                          },
                        ],
                        'scores': [
                          {
                            'id': 'rave-arc',
                            'page_number': 2,
                            'score_name': 'RAVE',
                            'criterion': 'Arcparesis',
                            'value': '1',
                            'text': 'RAVE Arcparesis 1 pont',
                          },
                        ],
                        'flowcharts': [
                          {
                            'id': 'flow-1',
                            'page_number': 3,
                            'title': 'Stroke dontesi fa',
                            'confidence': 0.82,
                            'nodes': [
                              {
                                'id': 'n1',
                                'label': 'FAST pozitiv',
                                'shape': 'decision',
                                'order': 1,
                                'source_rect': {
                                  'x': 10,
                                  'y': 20,
                                  'width': 120,
                                  'height': 40,
                                },
                              },
                            ],
                            'edges': [],
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
      model: 'gemini-2.5-flash-lite',
      chunkingMode: 'normal',
    );

    expect(
      result.evidence.map((item) => item.sourceType),
      containsAll([AiEvidenceSourceType.table, AiEvidenceSourceType.score]),
    );
    expect(
      result.evidence
          .singleWhere((item) => item.sourceType == AiEvidenceSourceType.score)
          .text,
      contains('RAVE Arcparesis 1 pont'),
    );
    expect(result.flowcharts.single.id, 'flow-1');
    expect(result.flowcharts.single.nodes.single.label, 'FAST pozitiv');
    expect(
      result.flowcharts.single.nodes.single.shape,
      AiFlowchartNodeShape.decision,
    );
    expect(result.flowcharts.single.nodes.single.order, 1);
    expect(result.flowcharts.single.nodes.single.sourceRect?['width'], 120);
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
          expect(request.body, contains('Answer language policy'));
          expect(request.body, contains('ambiguous'));
          expect(request.body, contains('Hungarian'));
          expect(request.body, contains('English'));

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
          chunkingMode: 'normal',
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
