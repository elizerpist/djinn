import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../ai/ai_client.dart';
import '../ai/ai_error.dart';
import '../ai/ai_provider.dart';
import '../settings/data/api_key_store.dart';

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

  @override
  Future<void> testApiKey({required String apiKey}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw AiProviderException(AiFailure.missingApiKey(AiProvider.gemini));
    }
    await _generateContent(
      model: 'gemini-2.5-flash-lite',
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
    if (model != 'gemini-embedding-001') {
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
  }) async {
    final file = File(pdfPath);
    final bytes = await file.exists() ? await file.readAsBytes() : <int>[];
    final filename = pdfPath.trim().isEmpty
        ? 'document.pdf'
        : p.basename(pdfPath);
    final response = await _generateContent(
      model: model,
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': _documentExtractionInstruction},
              {
                'inlineData': {
                  'mimeType': 'application/pdf',
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

  @override
  Future<AiAnswer> generateAnswer({
    required String model,
    required String question,
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
                      'Answer only from supplied evidence. Return JSON only.',
                  'question': question,
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
    final detail = _geminiErrorMessage(body) ?? body;
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
        normalized.contains('overloaded') ||
        normalized.contains('unavailable')) {
      return AiFailure.highDemand(AiProvider.gemini, detail);
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
    return AiExtractionResult(
      chunks: chunks
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
          .toList(growable: false),
    );
  }
}

const _documentExtractionInstruction = '''
Extract this OMSZ PDF into source-grounded chunks. Return JSON only. Include page-aware text chunks and preserve source wording. Flowchart extraction will be validated later, so do not invent missing nodes or arrows.
''';

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
          'section_title': {
            'type': ['string', 'null'],
          },
        },
        'required': ['id', 'text', 'page_number', 'section_title'],
      },
    },
  },
  'required': ['chunks'],
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
    'refusal_reason': {
      'type': ['string', 'null'],
    },
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
