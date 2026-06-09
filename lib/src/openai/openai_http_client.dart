import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../settings/data/api_key_store.dart';
import 'openai_client.dart';

class OpenAiHttpClient implements OpenAiClient {
  OpenAiHttpClient({
    required ApiKeyStore apiKeyStore,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _apiKeyStore = apiKeyStore,
       _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://api.openai.com');

  final ApiKeyStore _apiKeyStore;
  final http.Client _httpClient;
  final Uri _baseUri;

  @override
  Future<void> testApiKey({required String apiKey}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const OpenAiException('OpenAI API key is missing');
    }
    final response = await _httpClient.get(
      _baseUri.resolve('/v1/models'),
      headers: {'Authorization': 'Bearer $trimmed'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiException('api key test failed: ${response.statusCode}');
    }
  }

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) async {
    final response = await _postJson('/v1/embeddings', {
      'model': model,
      'input': input,
    });
    final data = response['data'];
    if (data is! List || data.isEmpty || data.first is! Map) {
      throw const OpenAiException('invalid OpenAI embedding response');
    }
    final embedding = (data.first as Map)['embedding'];
    if (embedding is! List) {
      throw const OpenAiException('invalid OpenAI embedding response');
    }
    return embedding
        .map((value) => (value as num).toDouble())
        .toList(growable: false);
  }

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final response = await _postJson('/v1/responses', {
      'model': model,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': _documentExtractionInstruction},
            {
              'type': 'input_file',
              'filename': p.basename(pdfPath),
              'file_data': 'data:application/pdf;base64,${base64Encode(bytes)}',
            },
          ],
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'djinn_document_extraction',
          'strict': true,
          'schema': _documentExtractionSchema,
        },
      },
    });
    final json = _decodeOutputJson(response);
    final chunks = json['chunks'];
    if (chunks is! List) {
      throw const OpenAiException('invalid OpenAI extraction response');
    }
    final flowcharts = json['flowcharts'];
    return OpenAiExtractionResult(
      chunks: chunks.map(_parseExtractedChunk).toList(growable: false),
      flowcharts: flowcharts is List
          ? flowcharts.map(_parseExtractedFlowchart).toList(growable: false)
          : const [],
    );
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  }) async {
    final response = await _postJson('/v1/responses', {
      'model': model,
      'input': [
        {
          'role': 'system',
          'content': [
            {'type': 'input_text', 'text': _closedAnswerInstruction},
          ],
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': jsonEncode({
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
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'djinn_grounded_answer',
          'strict': true,
          'schema': _answerSchema,
        },
      },
    });
    final json = _decodeOutputJson(response);
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
    final response = await _postJson('/v1/responses', {
      'model': model,
      'input': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_text',
              'text': jsonEncode({
                'instruction':
                    'Return whether the answer is fully supported by the evidence. Do not use outside knowledge.',
                'answer': answer,
                'evidence': evidence
                    .map((item) => {'id': item.id, 'text': item.text})
                    .toList(),
              }),
            },
          ],
        },
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'djinn_groundedness_check',
          'strict': true,
          'schema': _groundednessSchema,
        },
      },
    });
    final json = _decodeOutputJson(response);
    return json['grounded'] as bool? ?? false;
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _httpClient.post(
      _baseUri.resolve(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _openAiErrorMessage(response.body);
      final suffix = detail == null ? '' : ': $detail';
      if (response.statusCode == 429) {
        throw OpenAiException('OpenAI quota/rate limit reached (429)$suffix');
      }
      throw OpenAiException(
        'OpenAI request failed: ${response.statusCode}$suffix',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const OpenAiException('invalid OpenAI response');
    }
    return decoded;
  }

  Future<Map<String, String>> _headers() async {
    final key = await _apiKeyStore.readKey();
    if (key == null || key.trim().isEmpty) {
      throw const OpenAiException('OpenAI API key is missing');
    }
    return {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'};
  }

  String? _openAiErrorMessage(String body) {
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

  Map<String, Object?> _decodeOutputJson(Map<String, Object?> response) {
    final text = _extractOutputText(response);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const OpenAiException('invalid OpenAI structured response');
    }
    return decoded;
  }

  OpenAiExtractedChunk _parseExtractedChunk(Object? item) {
    if (item is! Map) {
      throw const OpenAiException('invalid OpenAI extraction chunk');
    }
    return OpenAiExtractedChunk(
      id: item['id'] as String? ?? '',
      text: item['text'] as String? ?? '',
      pageNumber: (item['page_number'] as num?)?.toInt() ?? 0,
      sectionTitle: item['section_title'] as String?,
    );
  }

  OpenAiExtractedFlowchart _parseExtractedFlowchart(Object? item) {
    if (item is! Map) {
      throw const OpenAiException('invalid OpenAI extraction flowchart');
    }
    final nodes = item['nodes'];
    final edges = item['edges'];
    return OpenAiExtractedFlowchart(
      id: item['id'] as String? ?? '',
      title: item['title'] as String?,
      pageNumber: (item['page_number'] as num?)?.toInt() ?? 0,
      confidence: (item['confidence'] as num?)?.toDouble(),
      nodes: nodes is List
          ? nodes.map(_parseExtractedFlowchartNode).toList(growable: false)
          : const [],
      edges: edges is List
          ? edges.map(_parseExtractedFlowchartEdge).toList(growable: false)
          : const [],
    );
  }

  OpenAiExtractedFlowchartNode _parseExtractedFlowchartNode(Object? item) {
    if (item is! Map) {
      throw const OpenAiException('invalid OpenAI extraction flowchart node');
    }
    return OpenAiExtractedFlowchartNode(
      id: item['id'] as String? ?? '',
      label: item['label'] as String? ?? '',
      positionX: (item['x'] as num?)?.toDouble() ?? 0,
      positionY: (item['y'] as num?)?.toDouble() ?? 0,
    );
  }

  OpenAiExtractedFlowchartEdge _parseExtractedFlowchartEdge(Object? item) {
    if (item is! Map) {
      throw const OpenAiException('invalid OpenAI extraction flowchart edge');
    }
    return OpenAiExtractedFlowchartEdge(
      id: item['id'] as String? ?? '',
      fromNodeId: item['from_node_id'] as String? ?? '',
      toNodeId: item['to_node_id'] as String? ?? '',
      label: item['label'] as String? ?? '',
    );
  }

  String _extractOutputText(Map<String, Object?> response) {
    final direct = response['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct;
    }
    final output = response['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map) {
          continue;
        }
        final content = item['content'];
        if (content is! List) {
          continue;
        }
        for (final contentItem in content) {
          if (contentItem is! Map) {
            continue;
          }
          final text = contentItem['text'] ?? contentItem['output_text'];
          if (text is String && text.trim().isNotEmpty) {
            return text;
          }
        }
      }
    }
    throw const OpenAiException('missing OpenAI output text');
  }
}

const _documentExtractionInstruction = '''
Extract this OMSZ PDF into source-grounded chunks. Return JSON only. Include page-aware text chunks and preserve source wording. Flowchart extraction will be validated later, so do not invent missing nodes or arrows.
''';

const _closedAnswerInstruction = '''
You are Djinn. Answer only from the supplied local evidence. Do not browse, do not use web search, do not use file search, do not use code execution, and do not use outside knowledge. If evidence is incomplete, abstain. Return JSON only with cited source IDs copied exactly from the supplied evidence.
''';

const Map<String, Object?> _documentExtractionSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'chunks': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string'},
          'text': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'section_title': {
            'type': ['string', 'null'],
          },
        },
        'required': ['id', 'text', 'page_number', 'section_title'],
      },
    },
    'flowcharts': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string'},
          'title': {
            'type': ['string', 'null'],
          },
          'page_number': {'type': 'integer'},
          'confidence': {
            'type': ['number', 'null'],
          },
          'nodes': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'id': {'type': 'string'},
                'label': {'type': 'string'},
                'x': {'type': 'number'},
                'y': {'type': 'number'},
              },
              'required': ['id', 'label', 'x', 'y'],
            },
          },
          'edges': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'id': {'type': 'string'},
                'from_node_id': {'type': 'string'},
                'to_node_id': {'type': 'string'},
                'label': {'type': 'string'},
              },
              'required': ['id', 'from_node_id', 'to_node_id', 'label'],
            },
          },
        },
        'required': [
          'id',
          'title',
          'page_number',
          'confidence',
          'nodes',
          'edges',
        ],
      },
    },
  },
  'required': ['chunks', 'flowcharts'],
};

const Map<String, Object?> _answerSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'answer': {'type': 'string'},
    'cited_source_ids': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'abstain': {'type': 'boolean'},
    'refusal_reason': {
      'type': ['string', 'null'],
    },
  },
  'required': ['answer', 'cited_source_ids', 'abstain', 'refusal_reason'],
};

const Map<String, Object?> _groundednessSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'grounded': {'type': 'boolean'},
    'reason': {'type': 'string'},
  },
  'required': ['grounded', 'reason'],
};
