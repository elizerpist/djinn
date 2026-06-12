import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/ai_client.dart';
import '../settings/data/api_key_store.dart';
import '../settings/models/app_settings.dart';
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
  Future<void> testApiKey({required String apiKey, String? model}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const OpenAiException('OpenAI API key is missing');
    }
    final response = await _httpClient.get(
      _baseUri.resolve('/v1/models'),
      headers: {'Authorization': 'Bearer $trimmed'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = _openAiErrorMessage(response.body);
      final suffix = detail == null ? '' : ': $detail';
      throw OpenAiException(
        'api key test failed: ${response.statusCode}$suffix',
      );
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
    required String chunkingMode,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final mimeType = _mimeTypeForPath(pdfPath);
    final filename = pdfPath.trim().isEmpty ? 'document.pdf' : p.basename(pdfPath);
    final response = await _postJson('/v1/responses', {
      'model': model,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': _documentExtractionInstruction},
            {'type': 'input_text', 'text': _visualExtractionInstruction},
            {'type': 'input_text', 'text': _chunkingInstruction(chunkingMode)},
            _documentInputContent(
              filename: filename,
              mimeType: mimeType,
              bytes: bytes,
            ),
            {'type': 'input_text', 'text': 'Filename: $filename'},
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
    return _parseExtraction(json);
  }

  Map<String, Object?> _documentInputContent({
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) {
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    if (mimeType.startsWith('image/')) {
      return {'type': 'input_image', 'image_url': dataUrl};
    }
    return {
      'type': 'input_file',
      'filename': filename,
      'file_data': dataUrl,
    };
  }

  String _mimeTypeForPath(String path) {
    return p.extension(path).toLowerCase() == '.png'
        ? 'image/png'
        : 'application/pdf';
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
    String? conversationContext,
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
                if (conversationContext != null &&
                    conversationContext.trim().isNotEmpty)
                  'conversation_context': conversationContext,
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

  OpenAiExtractionResult _parseExtraction(Map<String, Object?> json) {
    final chunks = json['chunks'];
    if (chunks is! List) {
      throw const OpenAiException('invalid OpenAI extraction response');
    }
    return OpenAiExtractionResult(
      chunks: chunks
          .map((item) {
            if (item is! Map) {
              throw const OpenAiException('invalid OpenAI extraction chunk');
            }
            return OpenAiExtractedChunk(
              id: _requiredString(item, 'id', 'chunk'),
              text: _requiredString(item, 'text', 'chunk'),
              pageNumber: _requiredNum(item, 'page_number', 'chunk').toInt(),
              sectionTitle: _optionalString(item, 'section_title', 'chunk'),
            );
          })
          .toList(growable: false),
      evidence: [..._parseTables(json), ..._parseScores(json)],
      flowcharts: _parseFlowcharts(json),
    );
  }

  List<AiExtractedEvidence> _parseTables(Map<String, Object?> json) {
    final tables = _optionalList(json, 'tables');
    final evidence = <AiExtractedEvidence>[];
    for (final table in tables) {
      if (table is! Map) {
        throw const OpenAiException('invalid OpenAI extraction table');
      }
      final id = _requiredString(table, 'id', 'table');
      final pageNumber = _requiredNum(table, 'page_number', 'table').toInt();
      final title = _optionalString(table, 'title', 'table');
      final rows = _requiredList(table, 'rows', 'table');
      for (var index = 0; index < rows.length; index += 1) {
        final row = rows[index];
        if (row is! Map) {
          throw const OpenAiException('invalid OpenAI extraction table row');
        }
        final label = _optionalString(row, 'label', 'table row') ?? '';
        final value = _optionalString(row, 'value', 'table row') ?? '';
        final text = _requiredString(row, 'text', 'table row');
        evidence.add(
          AiExtractedEvidence(
            id: '$id-row-${index + 1}',
            text: _joinParts([title, label, value, text]),
            pageNumber: pageNumber,
            sectionTitle: title,
            sourceType: AiEvidenceSourceType.table,
          ),
        );
      }
    }
    return evidence;
  }

  List<AiExtractedEvidence> _parseScores(Map<String, Object?> json) {
    final scores = _optionalList(json, 'scores');
    return scores
        .map((score) {
          if (score is! Map) {
            throw const OpenAiException('invalid OpenAI extraction score');
          }
          final scoreName = _requiredString(score, 'score_name', 'score');
          final criterion = _requiredString(score, 'criterion', 'score');
          final value = _optionalString(score, 'value', 'score') ?? '';
          final text = _requiredString(score, 'text', 'score');
          return AiExtractedEvidence(
            id: _requiredString(score, 'id', 'score'),
            text: _joinParts([scoreName, criterion, value, text]),
            pageNumber: _requiredNum(score, 'page_number', 'score').toInt(),
            sectionTitle: scoreName,
            sourceType: AiEvidenceSourceType.score,
          );
        })
        .toList(growable: false);
  }

  List<AiFlowchartCandidate> _parseFlowcharts(Map<String, Object?> json) {
    final flowcharts = _optionalList(json, 'flowcharts');
    return flowcharts
        .map((flowchart) {
          if (flowchart is! Map) {
            throw const OpenAiException('invalid OpenAI extraction flowchart');
          }
          return AiFlowchartCandidate(
            id: _requiredString(flowchart, 'id', 'flowchart'),
            pageNumber: _requiredNum(
              flowchart,
              'page_number',
              'flowchart',
            ).toInt(),
            title: _optionalString(flowchart, 'title', 'flowchart'),
            confidence: _optionalNum(
              flowchart,
              'confidence',
              'flowchart',
            )?.toDouble(),
            nodes: _requiredList(flowchart, 'nodes', 'flowchart')
                .map((node) {
                  if (node is! Map) {
                    throw const OpenAiException(
                      'invalid OpenAI extraction flowchart node',
                    );
                  }
                  return AiFlowchartNode(
                    id: _requiredString(node, 'id', 'flowchart node'),
                    label: _requiredString(node, 'label', 'flowchart node'),
                  );
                })
                .toList(growable: false),
            edges: _requiredList(flowchart, 'edges', 'flowchart')
                .map((edge) {
                  if (edge is! Map) {
                    throw const OpenAiException(
                      'invalid OpenAI extraction flowchart edge',
                    );
                  }
                  return AiFlowchartEdge(
                    id: _requiredString(edge, 'id', 'flowchart edge'),
                    fromNodeId: _requiredString(
                      edge,
                      'from_node_id',
                      'flowchart edge',
                    ),
                    toNodeId: _requiredString(
                      edge,
                      'to_node_id',
                      'flowchart edge',
                    ),
                    label: _requiredString(edge, 'label', 'flowchart edge'),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  List<Object?> _optionalList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value;
    }
    throw OpenAiException('invalid OpenAI extraction $key');
  }

  List<Object?> _requiredList(
    Map<dynamic, dynamic> json,
    String key,
    String context,
  ) {
    final value = json[key];
    if (value is List) {
      return value;
    }
    throw OpenAiException('invalid OpenAI extraction $context $key');
  }

  String _requiredString(
    Map<dynamic, dynamic> json,
    String key,
    String context,
  ) {
    final value = json[key];
    if (value is String) {
      return value;
    }
    throw OpenAiException('invalid OpenAI extraction $context $key');
  }

  String? _optionalString(
    Map<dynamic, dynamic> json,
    String key,
    String context,
  ) {
    final value = json[key];
    if (value == null || value is String) {
      return value as String?;
    }
    throw OpenAiException('invalid OpenAI extraction $context $key');
  }

  num _requiredNum(Map<dynamic, dynamic> json, String key, String context) {
    final value = json[key];
    if (value is num) {
      return value;
    }
    throw OpenAiException('invalid OpenAI extraction $context $key');
  }

  num? _optionalNum(Map<dynamic, dynamic> json, String key, String context) {
    final value = json[key];
    if (value == null || value is num) {
      return value as num?;
    }
    throw OpenAiException('invalid OpenAI extraction $context $key');
  }

  String _joinParts(List<String?> parts) {
    return parts
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join(' | ');
  }
}

const _documentExtractionInstruction = '''
Extract this OMSZ document into source-grounded chunks. Return JSON only. Include page-aware text chunks and preserve source wording. Flowchart extraction will be validated later, so do not invent missing nodes or arrows.
''';

const _visualExtractionInstruction = '''
If a page contains a table, score, or flowchart as an image, extract it from the document image content. Preserve clinically relevant table rows. For RAVE or other scores, return each criterion as a score item. For flowcharts, return candidate nodes and directed edges; do not invent uncertain nodes.
''';

String _chunkingInstruction(String mode) {
  return switch (ChunkingModes.normalize(mode)) {
    ChunkingModes.compact =>
      'Chunking mode: compact. Prefer fewer, larger chunks. Keep related headings, lists, and tables together when they describe one clinical decision.',
    ChunkingModes.detailed =>
      'Chunking mode: detailed. Prefer smaller, precise chunks for distinct clinical decisions, but keep each list item with the context needed to interpret it.',
    _ =>
      'Chunking mode: normal. Use balanced chunks: one coherent clinical topic per chunk, preserving enough context for retrieval.',
  };
}

const _closedAnswerInstruction = '''
You are Djinn. Answer only from the supplied local evidence. Do not browse, do not use web search, do not use file search, do not use code execution, and do not use outside knowledge. If evidence is incomplete, abstain. Return JSON only with cited source IDs copied exactly from the supplied evidence.

If conversation_context is supplied, use it only to resolve follow-up references like "why" or "that treatment". Never cite or rely on conversation_context as evidence; the evidence array remains the only authoritative source.

Answer language policy: detect the latest user question language. If it is Hungarian, answer in Hungarian. If it is ambiguous or mixed, answer in Hungarian. If it is clearly English, answer in English. Do not choose the answer language from the source document language alone.
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
    'tables': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'title': {
            'type': ['string', 'null'],
          },
          'rows': {
            'type': 'array',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'label': {
                  'type': ['string', 'null'],
                },
                'value': {
                  'type': ['string', 'null'],
                },
                'text': {'type': 'string'},
              },
              'required': ['label', 'value', 'text'],
            },
          },
        },
        'required': ['id', 'page_number', 'title', 'rows'],
      },
    },
    'scores': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'score_name': {'type': 'string'},
          'criterion': {'type': 'string'},
          'value': {
            'type': ['string', 'null'],
          },
          'text': {'type': 'string'},
        },
        'required': [
          'id',
          'page_number',
          'score_name',
          'criterion',
          'value',
          'text',
        ],
      },
    },
    'flowcharts': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'id': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'title': {
            'type': ['string', 'null'],
          },
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
              },
              'required': ['id', 'label'],
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
          'page_number',
          'title',
          'confidence',
          'nodes',
          'edges',
        ],
      },
    },
  },
  'required': ['chunks', 'tables', 'scores', 'flowcharts'],
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
