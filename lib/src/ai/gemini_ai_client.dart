import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../openai/openai_client.dart';
import '../settings/data/api_key_store.dart';

class GeminiException extends OpenAiException {
  const GeminiException(super.message);

  @override
  String toString() => 'GeminiException: $message';
}

class GeminiAiClient implements OpenAiClient {
  GeminiAiClient({
    required ApiKeyStore apiKeyStore,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _apiKeyStore = apiKeyStore,
       _httpClient = httpClient ?? http.Client(),
       _baseUri =
           baseUri ?? Uri.parse('https://generativelanguage.googleapis.com');

  final ApiKeyStore _apiKeyStore;
  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  Future<void> testApiKey({required String apiKey}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const GeminiException('Google API key is missing');
    }
    final response = await _httpClient.get(
      _baseUri.resolve('/v1beta/models'),
      headers: {'x-goog-api-key': trimmed},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiException(
        'Google Gemini key test failed: ${response.statusCode}',
      );
    }
  }

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) async {
    final response = await _postJson('/v1beta/models/$model:embedContent', {
      'model': 'models/$model',
      'content': {
        'parts': [
          {'text': input},
        ],
      },
      'outputDimensionality': 3072,
    });
    final embedding = response['embedding'];
    if (embedding is! Map) {
      throw const GeminiException('invalid Gemini embedding response');
    }
    final values = embedding['values'];
    if (values is! List) {
      throw const GeminiException('invalid Gemini embedding response');
    }
    return values
        .map((value) => (value as num).toDouble())
        .toList(growable: false);
  }

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    final response = await _postJson('/v1beta/models/$model:generateContent', {
      'contents': [
        {'role': 'user', 'parts': await _documentParts(pdfPath)},
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });
    final json = _decodeGeneratedJson(response);
    return _parseExtraction(json);
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  }) async {
    final response = await _postJson('/v1beta/models/$model:generateContent', {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': jsonEncode({
                'instruction':
                    'Answer only from local evidence. Return JSON with answer, cited_source_ids, abstain, refusal_reason.',
                'question': question,
                'evidence': evidence
                    .map(
                      (item) => {
                        'id': item.id,
                        'label': item.label,
                        'text': item.text,
                      },
                    )
                    .toList(),
              }),
            },
          ],
        },
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });
    final json = _decodeGeneratedJson(response);
    final cited = json['cited_source_ids'];
    return OpenAiAnswer(
      answer: json['answer'] as String? ?? '',
      citedSourceIds: cited is List
          ? cited.whereType<String>().toList(growable: false)
          : const [],
      abstain: json['abstain'] as bool? ?? false,
      refusalReason: json['refusal_reason'] as String?,
    );
  }

  @override
  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<OpenAiEvidence> evidence,
  }) async {
    final response = await _postJson('/v1beta/models/$model:generateContent', {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': jsonEncode({
                'instruction':
                    'Return JSON only: {"grounded": true|false}. Use only supplied evidence.',
                'answer': answer,
                'evidence': evidence
                    .map((item) => {'id': item.id, 'text': item.text})
                    .toList(),
              }),
            },
          ],
        },
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });
    final json = _decodeGeneratedJson(response);
    return json['grounded'] as bool? ?? false;
  }

  Future<List<Map<String, Object?>>> _documentParts(String pdfPath) async {
    final instruction = {
      'text':
          'Extract this OMSZ PDF into JSON with chunks and flowcharts. Flowcharts must contain id, title, page_number, confidence, nodes, and edges. Do not invent missing arrows.',
    };
    final file = File(pdfPath);
    if (!await file.exists()) {
      return [instruction];
    }
    final bytes = await file.readAsBytes();
    return [
      instruction,
      {
        'inlineData': {
          'mimeType': 'application/pdf',
          'data': base64Encode(bytes),
        },
      },
    ];
  }

  OpenAiExtractionResult _parseExtraction(Map<String, Object?> json) {
    final chunks = json['chunks'];
    if (chunks is! List) {
      throw const GeminiException('invalid Gemini extraction response');
    }
    final flowcharts = json['flowcharts'];
    return OpenAiExtractionResult(
      chunks: chunks.map(_parseChunk).toList(growable: false),
      flowcharts: flowcharts is List
          ? flowcharts.map(_parseFlowchart).toList(growable: false)
          : const [],
    );
  }

  OpenAiExtractedChunk _parseChunk(Object? item) {
    if (item is! Map) {
      throw const GeminiException('invalid Gemini extraction chunk');
    }
    return OpenAiExtractedChunk(
      id: item['id'] as String? ?? '',
      text: item['text'] as String? ?? '',
      pageNumber: (item['page_number'] as num?)?.toInt() ?? 0,
      sectionTitle: item['section_title'] as String?,
    );
  }

  OpenAiExtractedFlowchart _parseFlowchart(Object? item) {
    if (item is! Map) {
      throw const GeminiException('invalid Gemini extraction flowchart');
    }
    final nodes = item['nodes'];
    final edges = item['edges'];
    return OpenAiExtractedFlowchart(
      id: item['id'] as String? ?? '',
      title: item['title'] as String?,
      pageNumber: (item['page_number'] as num?)?.toInt() ?? 0,
      confidence: (item['confidence'] as num?)?.toDouble(),
      nodes: nodes is List
          ? nodes.map(_parseNode).toList(growable: false)
          : const [],
      edges: edges is List
          ? edges.map(_parseEdge).toList(growable: false)
          : const [],
    );
  }

  OpenAiExtractedFlowchartNode _parseNode(Object? item) {
    if (item is! Map) {
      throw const GeminiException('invalid Gemini extraction node');
    }
    return OpenAiExtractedFlowchartNode(
      id: item['id'] as String? ?? '',
      label: item['label'] as String? ?? '',
      positionX: (item['x'] as num?)?.toDouble() ?? 0,
      positionY: (item['y'] as num?)?.toDouble() ?? 0,
    );
  }

  OpenAiExtractedFlowchartEdge _parseEdge(Object? item) {
    if (item is! Map) {
      throw const GeminiException('invalid Gemini extraction edge');
    }
    return OpenAiExtractedFlowchartEdge(
      id: item['id'] as String? ?? '',
      fromNodeId: item['from_node_id'] as String? ?? '',
      toNodeId: item['to_node_id'] as String? ?? '',
      label: item['label'] as String? ?? '',
    );
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _httpClient.post(
      _baseUri.resolve(path),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': await _apiKey(),
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _geminiErrorMessage(response.body);
      final suffix = detail == null ? '' : ': $detail';
      if (response.statusCode == 429) {
        throw GeminiException(
          'Google Gemini quota/rate limit reached (429)$suffix',
        );
      }
      throw GeminiException(
        'Google Gemini request failed: ${response.statusCode}$suffix',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const GeminiException('invalid Gemini response');
    }
    return decoded;
  }

  Future<String> _apiKey() async {
    final key = await _apiKeyStore.readKey(provider: ApiKeyProvider.google);
    if (key == null || key.trim().isEmpty) {
      throw const GeminiException('Google API key is missing');
    }
    return key;
  }

  Map<String, Object?> _decodeGeneratedJson(Map<String, Object?> response) {
    final text = _extractGeneratedText(response);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const GeminiException('invalid Gemini structured response');
    }
    return decoded;
  }

  String _extractGeneratedText(Map<String, Object?> response) {
    final candidates = response['candidates'];
    if (candidates is List) {
      for (final candidate in candidates) {
        if (candidate is! Map) {
          continue;
        }
        final content = candidate['content'];
        if (content is! Map) {
          continue;
        }
        final parts = content['parts'];
        if (parts is! List) {
          continue;
        }
        for (final part in parts) {
          if (part is! Map) {
            continue;
          }
          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }
    throw const GeminiException('missing Gemini output text');
  }

  String? _geminiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      final error = decoded['error'];
      if (error is! Map) {
        return null;
      }
      final message = error['message'];
      if (message is! String || message.trim().isEmpty) {
        return null;
      }
      return message.trim();
    } catch (_) {
      return null;
    }
  }
}
