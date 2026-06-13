import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/ai_client.dart';
import '../ai/ai_error.dart';
import '../ai/ai_provider.dart';
import '../settings/data/api_key_store.dart';
import '../settings/models/app_settings.dart';

class GeminiHttpClient implements AiClient {
  GeminiHttpClient({
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
  static const _defaultTestModel = 'gemini-3.5-flash';
  static const _supportedEmbeddingModels = {
    'gemini-embedding-001',
    'gemini-embedding-2',
  };

  @override
  Future<void> testApiKey({required String apiKey, String? model}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw AiProviderException(AiFailure.missingApiKey(AiProvider.gemini));
    }
    final testModel = model?.trim().isNotEmpty == true
        ? model!.trim()
        : _defaultTestModel;
    await _generateContent(
      model: testModel,
      apiKeyOverride: trimmed,
      body: const {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'ping'},
            ],
          },
        ],
      },
    );
  }

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) async {
    if (!_supportedEmbeddingModels.contains(model)) {
      throw AiProviderException(
        AiFailure.unsupportedEmbedding(AiProvider.gemini, model),
      );
    }
    final response = await _postModelMethod(
      model: model,
      method: 'embedContent',
      body: {
        'content': {
          'parts': [
            {'text': input},
          ],
        },
      },
    );
    final embedding = response['embedding'];
    if (embedding is! Map) {
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(
          AiProvider.gemini,
          'embedding must be an object',
        ),
      );
    }
    final values = embedding['values'];
    if (values is! List) {
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(
          AiProvider.gemini,
          'embedding values must be a list',
        ),
      );
    }
    return values
        .map((value) {
          if (value is! num) {
            throw AiProviderException(
              AiFailure.invalidStructuredResponse(
                AiProvider.gemini,
                'embedding values must be numeric',
              ),
            );
          }
          return value.toDouble();
        })
        .toList(growable: false);
  }

  @override
  Future<AiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    final file = File(pdfPath);
    final bytes = await file.exists() ? await file.readAsBytes() : <int>[];
    final filename = pdfPath.trim().isEmpty
        ? 'document.pdf'
        : p.basename(pdfPath);
    final mimeType = _mimeTypeForPath(pdfPath);
    final response = await _generateContent(
      model: model,
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': _documentExtractionInstruction},
              {'text': _visualExtractionInstruction},
              {'text': _chunkingInstruction(chunkingMode)},
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Encode(bytes),
                },
              },
              {'text': 'Filename: $filename'},
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _documentExtractionSchema,
        },
      },
    );
    final extractionJson = _decodeStructuredText(response);
    return _parseExtraction(extractionJson);
  }

  String _mimeTypeForPath(String path) {
    return p.extension(path).toLowerCase() == '.png'
        ? 'image/png'
        : 'application/pdf';
  }

  @override
  Future<AiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<AiEvidence> evidence,
    String? conversationContext,
  }) async {
    final response = await _generateContent(
      model: model,
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': jsonEncode({
                  'instruction':
                      'Answer only from supplied evidence. Return JSON only. '
                      'Use conversation_context only to resolve follow-up references; '
                      'never treat it as evidence. '
                      '$_answerLanguagePolicy',
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
                      .toList(growable: false),
                }),
              },
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _answerSchema,
        },
      },
    );
    final json = _decodeStructuredText(response);
    final cited = json['cited_source_ids'];
    return AiAnswer(
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
    required List<AiEvidence> evidence,
  }) async {
    final response = await _generateContent(
      model: model,
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': jsonEncode({
                  'instruction':
                      'Return whether the answer is fully supported by the evidence.',
                  'answer': answer,
                  'evidence': evidence
                      .map((item) => {'id': item.id, 'text': item.text})
                      .toList(growable: false),
                }),
              },
            ],
          },
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': _groundednessSchema,
        },
      },
    );
    final json = _decodeStructuredText(response);
    final grounded = json['grounded'];
    if (grounded is! bool) {
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(
          AiProvider.gemini,
          'grounded must be a boolean',
        ),
      );
    }
    return grounded;
  }

  Future<Map<String, Object?>> _generateContent({
    required String model,
    required Map<String, Object?> body,
    String? apiKeyOverride,
  }) {
    return _postModelMethod(
      model: model,
      method: 'generateContent',
      body: body,
      apiKeyOverride: apiKeyOverride,
    );
  }

  Future<Map<String, Object?>> _postModelMethod({
    required String model,
    required String method,
    required Map<String, Object?> body,
    String? apiKeyOverride,
  }) async {
    final key =
        apiKeyOverride ??
        await _apiKeyStore.readKeyForProvider(AiProvider.gemini);
    if (key == null || key.trim().isEmpty) {
      throw AiProviderException(AiFailure.missingApiKey(AiProvider.gemini));
    }
    try {
      final response = await _httpClient.post(
        _modelMethodUri(model, method, key.trim()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiProviderException(
          _mapGeminiStatus(response.statusCode, response.body),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(
          AiProvider.gemini,
          'top-level response is not an object',
        ),
      );
    } on AiProviderException {
      rethrow;
    } on SocketException catch (error) {
      throw AiProviderException(
        AiFailure.networkAbort(AiProvider.gemini, error.message),
      );
    } on http.ClientException catch (error) {
      throw AiProviderException(
        AiFailure.networkAbort(AiProvider.gemini, error.message),
      );
    } on FormatException catch (error) {
      throw AiProviderException(
        AiFailure.invalidJson(AiProvider.gemini, error.message),
      );
    }
  }

  Uri _modelMethodUri(String model, String method, String key) {
    return _baseUri.replace(
      path: '/v1beta/models/$model:$method',
      queryParameters: {'key': key},
    );
  }

  AiFailure _mapGeminiStatus(int statusCode, String body) {
    final detail = _redactApiKey(_geminiErrorMessage(body) ?? body);
    final normalized = detail.toLowerCase();
    if (statusCode == 429 ||
        normalized.contains('quota') ||
        normalized.contains('billing') ||
        normalized.contains('prepayment') ||
        normalized.contains('credits are depleted') ||
        normalized.contains('rate limit')) {
      return AiFailure.quota(AiProvider.gemini, detail);
    }
    if (statusCode == 503 ||
        normalized.contains('high demand') ||
        normalized.contains('overloaded')) {
      return AiFailure.highDemand(AiProvider.gemini, detail);
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return AiFailure.providerServerError(AiProvider.gemini, detail);
    }
    if (statusCode == 404 ||
        (normalized.contains('model') &&
            (normalized.contains('not found') ||
                normalized.contains('not supported') ||
                normalized.contains('does not exist') ||
                normalized.contains('not available')))) {
      return AiFailure.modelUnavailable(AiProvider.gemini, detail);
    }
    if ((statusCode == 400 || statusCode == 401 || statusCode == 403) &&
        (normalized.contains('api key') ||
            normalized.contains('permission') ||
            normalized.contains('auth') ||
            normalized.contains('denied'))) {
      return AiFailure.keyTestFailed(AiProvider.gemini, detail);
    }
    return AiFailure.unknown(
      AiProvider.gemini,
      'Gemini request failed: $statusCode: $detail',
    );
  }

  String? _geminiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      final error = decoded['error'];
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _redactApiKey(String value) {
    return value.replaceAllMapped(
      RegExp(r'([?&]key=)[^&\s"<>]+'),
      (match) => '${match.group(1)}<redacted>',
    );
  }

  Map<String, Object?> _decodeStructuredText(Map<String, Object?> response) {
    final text = _extractOutputText(response);
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(
          AiProvider.gemini,
          'structured text is not an object',
        ),
      );
    } on AiProviderException {
      rethrow;
    } on FormatException catch (error) {
      throw AiProviderException(
        AiFailure.invalidJson(AiProvider.gemini, error.message),
      );
    }
  }

  String _extractOutputText(Map<String, Object?> response) {
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
    throw AiProviderException(
      AiFailure.invalidStructuredResponse(
        AiProvider.gemini,
        'missing Gemini output text',
      ),
    );
  }

  AiExtractionResult _parseExtraction(Map<String, Object?> json) {
    final chunks = json['chunks'];
    if (chunks is! List) {
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(
          AiProvider.gemini,
          'chunks must be a list',
        ),
      );
    }
    final parsedChunks = chunks
        .map((item) {
          if (item is! Map) {
            throw AiProviderException(
              AiFailure.invalidStructuredResponse(
                AiProvider.gemini,
                'chunk must be an object',
              ),
            );
          }
          final id = item['id'];
          final text = item['text'];
          final pageNumber = item['page_number'];
          final sectionTitle = item['section_title'];
          if (id is! String || text is! String || pageNumber is! num) {
            throw AiProviderException(
              AiFailure.invalidStructuredResponse(
                AiProvider.gemini,
                'chunk id/text/page_number invalid',
              ),
            );
          }
          if (sectionTitle != null && sectionTitle is! String) {
            throw AiProviderException(
              AiFailure.invalidStructuredResponse(
                AiProvider.gemini,
                'chunk section_title invalid',
              ),
            );
          }
          return AiExtractedChunk(
            id: id,
            text: text,
            pageNumber: pageNumber.toInt(),
            sectionTitle: sectionTitle as String?,
          );
        })
        .toList(growable: false);
    return AiExtractionResult(
      chunks: parsedChunks,
      evidence: [..._parseTables(json), ..._parseScores(json)],
      flowcharts: _parseFlowcharts(json),
    );
  }

  List<AiExtractedEvidence> _parseTables(Map<String, Object?> json) {
    final tables = _optionalList(json, 'tables');
    final evidence = <AiExtractedEvidence>[];
    for (final table in tables) {
      if (table is! Map) {
        throw _invalidStructured('table must be an object');
      }
      final id = _requiredString(table, 'id', 'table');
      final pageNumber = _requiredNum(table, 'page_number', 'table').toInt();
      final title = _optionalString(table, 'title', 'table');
      final rows = table['rows'];
      if (rows is! List) {
        throw _invalidStructured('table rows must be a list');
      }
      for (var index = 0; index < rows.length; index += 1) {
        final row = rows[index];
        if (row is! Map) {
          throw _invalidStructured('table row must be an object');
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
            throw _invalidStructured('score must be an object');
          }
          final id = _requiredString(score, 'id', 'score');
          final pageNumber = _requiredNum(
            score,
            'page_number',
            'score',
          ).toInt();
          final scoreName = _requiredString(score, 'score_name', 'score');
          final criterion = _requiredString(score, 'criterion', 'score');
          final value = _optionalString(score, 'value', 'score') ?? '';
          final text = _requiredString(score, 'text', 'score');
          return AiExtractedEvidence(
            id: id,
            text: _joinParts([scoreName, criterion, value, text]),
            pageNumber: pageNumber,
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
            throw _invalidStructured('flowchart must be an object');
          }
          final id = _requiredString(flowchart, 'id', 'flowchart');
          final pageNumber = _requiredNum(
            flowchart,
            'page_number',
            'flowchart',
          ).toInt();
          final title = _optionalString(flowchart, 'title', 'flowchart');
          final confidence = _optionalNum(flowchart, 'confidence', 'flowchart');
          final nodes = _requiredList(flowchart, 'nodes', 'flowchart')
              .map((node) {
                if (node is! Map) {
                  throw _invalidStructured('flowchart node must be an object');
                }
                return AiFlowchartNode(
                  id: _requiredString(node, 'id', 'flowchart node'),
                  label: _requiredString(node, 'label', 'flowchart node'),
                  shape: AiFlowchartNodeShape.fromWireName(
                    _optionalString(node, 'shape', 'flowchart node'),
                  ),
                  order:
                      _optionalNum(node, 'order', 'flowchart node')?.toInt() ??
                      0,
                  sourceRect: _optionalMap(
                    node,
                    'source_rect',
                    'flowchart node',
                  ),
                );
              })
              .toList(growable: false);
          final edges = _requiredList(flowchart, 'edges', 'flowchart')
              .map((edge) {
                if (edge is! Map) {
                  throw _invalidStructured('flowchart edge must be an object');
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
                  order:
                      _optionalNum(edge, 'order', 'flowchart edge')?.toInt() ??
                      0,
                  sourceRect: _optionalMap(
                    edge,
                    'source_rect',
                    'flowchart edge',
                  ),
                );
              })
              .toList(growable: false);
          return AiFlowchartCandidate(
            id: id,
            pageNumber: pageNumber,
            title: title,
            confidence: confidence?.toDouble(),
            nodes: nodes,
            edges: edges,
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
    throw _invalidStructured('$key must be a list');
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
    throw _invalidStructured('$context $key must be a list');
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
    throw _invalidStructured('$context $key must be a string');
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
    throw _invalidStructured('$context $key must be a string');
  }

  num _requiredNum(Map<dynamic, dynamic> json, String key, String context) {
    final value = json[key];
    if (value is num) {
      return value;
    }
    throw _invalidStructured('$context $key must be numeric');
  }

  Map<String, Object?>? _optionalMap(
    Map<dynamic, dynamic> json,
    String key,
    String context,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    throw _invalidStructured('$context $key must be an object');
  }

  num? _optionalNum(Map<dynamic, dynamic> json, String key, String context) {
    final value = json[key];
    if (value == null || value is num) {
      return value as num?;
    }
    throw _invalidStructured('$context $key must be numeric');
  }

  AiProviderException _invalidStructured(String message) {
    return AiProviderException(
      AiFailure.invalidStructuredResponse(AiProvider.gemini, message),
    );
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
If a page contains a table, score, or flowchart as an image, extract it from the document image content. Preserve clinically relevant table rows. For RAVE or other scores, return each criterion as a score item. For flowcharts, capture the visible title or caption immediately above or below the diagram in the flowchart title field. Return every visible clinical box and directed arrow, including medication/treatment process boxes and small process boxes that sit on a branch. Label each node shape as one of start_end, process, decision, input_output, subprocess, data_store, connector, or unknown. Use edge labels for IGEN/NEM/YES/NO branch text; do not create a separate node for a branch label unless the source diagram draws it as its own box. Use order to preserve the reading/flow order. If a bounding box is visible, return source_rect using image-relative x, y, width, height; otherwise return null. Do not invent uncertain nodes.
''';

const _answerLanguagePolicy =
    'Answer language policy: detect the latest user question language. '
    'If it is Hungarian, answer in Hungarian. If it is ambiguous or mixed, '
    'answer in Hungarian. If it is clearly English, answer in English. '
    'Do not choose the answer language from the source document language alone.';

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

const Map<String, Object?> _documentExtractionSchema = {
  'type': 'object',
  'properties': {
    'chunks': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'text': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'section_title': {'type': 'string', 'nullable': true},
        },
        'required': ['id', 'text', 'page_number', 'section_title'],
      },
    },
    'tables': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'title': {'type': 'string', 'nullable': true},
          'rows': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'label': {'type': 'string', 'nullable': true},
                'value': {'type': 'string', 'nullable': true},
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
        'properties': {
          'id': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'score_name': {'type': 'string'},
          'criterion': {'type': 'string'},
          'value': {'type': 'string', 'nullable': true},
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
        'properties': {
          'id': {'type': 'string'},
          'page_number': {'type': 'integer'},
          'title': {'type': 'string', 'nullable': true},
          'confidence': {'type': 'number', 'nullable': true},
          'nodes': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
                'label': {'type': 'string'},
                'shape': {'type': 'string'},
                'order': {'type': 'integer'},
                'source_rect': {
                  'type': 'object',
                  'nullable': true,
                  'properties': {
                    'x': {'type': 'number'},
                    'y': {'type': 'number'},
                    'width': {'type': 'number'},
                    'height': {'type': 'number'},
                  },
                  'required': ['x', 'y', 'width', 'height'],
                },
              },
              'required': ['id', 'label', 'shape', 'order', 'source_rect'],
            },
          },
          'edges': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
                'from_node_id': {'type': 'string'},
                'to_node_id': {'type': 'string'},
                'label': {'type': 'string'},
                'order': {'type': 'integer'},
                'source_rect': {
                  'type': 'object',
                  'nullable': true,
                  'properties': {
                    'x': {'type': 'number'},
                    'y': {'type': 'number'},
                    'width': {'type': 'number'},
                    'height': {'type': 'number'},
                  },
                  'required': ['x', 'y', 'width', 'height'],
                },
              },
              'required': [
                'id',
                'from_node_id',
                'to_node_id',
                'label',
                'order',
                'source_rect',
              ],
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
  'properties': {
    'answer': {'type': 'string'},
    'cited_source_ids': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'abstain': {'type': 'boolean'},
    'refusal_reason': {'type': 'string', 'nullable': true},
  },
  'required': ['answer', 'cited_source_ids', 'abstain', 'refusal_reason'],
};

const Map<String, Object?> _groundednessSchema = {
  'type': 'object',
  'properties': {
    'grounded': {'type': 'boolean'},
    'reason': {'type': 'string'},
  },
  'required': ['grounded', 'reason'],
};
