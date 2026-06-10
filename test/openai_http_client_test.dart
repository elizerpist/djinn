import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:djinn/src/ai/ai_client.dart';
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

  test('parses OpenAI tables scores and flowchart candidates', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKey('sk-test');
    final tempDir = await Directory.systemTemp.createTemp('djinn_openai_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final pdf = File('${tempDir.path}/rave.pdf');
    await pdf.writeAsBytes([1, 2, 3]);

    final client = OpenAiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/responses');
        expect(request.body, contains('"tables"'));
        expect(request.body, contains('"scores"'));
        expect(request.body, contains('"flowcharts"'));
        return http.Response(
          jsonEncode({
            'output_text': jsonEncode({
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
                    {'id': 'n1', 'label': 'FAST pozitiv'},
                  ],
                  'edges': [],
                },
              ],
            }),
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://api.openai.test'),
    );

    final result = await client.extractDocument(
      pdfPath: pdf.path,
      model: 'gpt-5.5',
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
    expect(result.flowcharts.single.nodes.single.label, 'FAST pozitiv');
  });

  test(
    'sends OpenAI answer language policy with grounded answer request',
    () async {
      final keyStore = MemoryApiKeyStore();
      await keyStore.saveKey('sk-test');
      final client = OpenAiHttpClient(
        apiKeyStore: keyStore,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/responses');
          expect(request.body, contains('Answer language policy'));
          expect(request.body, contains('ambiguous'));
          expect(request.body, contains('Hungarian'));
          expect(request.body, contains('English'));
          return http.Response(
            jsonEncode({
              'output_text': jsonEncode({
                'answer': 'Magyar valasz.',
                'cited_source_ids': ['e1'],
                'abstain': false,
                'refusal_reason': null,
              }),
            }),
            200,
          );
        }),
        baseUri: Uri.parse('https://api.openai.test'),
      );

      final result = await client.generateAnswer(
        model: 'gpt-5.5',
        question: 'Mi a teendo?',
        evidence: const [AiEvidence(id: 'e1', label: 'Forras', text: 'Szoveg')],
      );

      expect(result.answer, 'Magyar valasz.');
    },
  );
}
