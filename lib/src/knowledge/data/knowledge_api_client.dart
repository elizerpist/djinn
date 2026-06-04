import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/knowledge_document.dart';

class BackendComponentReadiness {
  const BackendComponentReadiness({required this.ready, required this.detail});

  final bool ready;
  final String detail;

  factory BackendComponentReadiness.fromJson(Map<String, Object?> json) {
    return BackendComponentReadiness(
      ready: json['ready'] as bool? ?? false,
      detail: json['detail'] as String? ?? 'unavailable',
    );
  }
}

class BackendSystemReadiness {
  const BackendSystemReadiness({
    required this.ready,
    required this.strictMode,
    required this.components,
  });

  final bool ready;
  final bool strictMode;
  final Map<String, BackendComponentReadiness> components;

  factory BackendSystemReadiness.fromJson(Map<String, Object?> json) {
    final rawComponents = json['components'] as Map? ?? const {};
    return BackendSystemReadiness(
      ready: json['ready'] as bool? ?? false,
      strictMode: json['strict_mode'] as bool? ?? true,
      components: rawComponents.map(
        (key, value) => MapEntry(
          key.toString(),
          BackendComponentReadiness.fromJson(
            (value as Map).cast<String, Object?>(),
          ),
        ),
      ),
    );
  }
}

class BackendKnowledgeStatus {
  const BackendKnowledgeStatus({
    required this.ready,
    required this.documentCount,
    required this.pendingCount,
    required this.processedCount,
    required this.failedCount,
  });

  final bool ready;
  final int documentCount;
  final int pendingCount;
  final int processedCount;
  final int failedCount;

  factory BackendKnowledgeStatus.fromJson(Map<String, Object?> json) {
    return BackendKnowledgeStatus(
      ready: json['ready'] as bool? ?? false,
      documentCount: json['document_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      processedCount: json['processed_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
    );
  }
}

class KnowledgeApiClient {
  KnowledgeApiClient({required Uri baseUri, http.Client? client})
    : _baseUri = baseUri,
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Future<KnowledgeDocument> uploadDocument({
    required String localPath,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _baseUri.resolve('/knowledge/documents'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', localPath, filename: filename),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'knowledge document upload failed: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    return _documentFromBackendJson(
      decoded,
      fallbackFilename: filename,
      fallbackLocalPath: localPath,
    );
  }

  Future<BackendSystemReadiness> getSystemReadiness() async {
    final response = await _client.get(_baseUri.resolve('/system/readiness'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('system readiness failed: ${response.statusCode}');
    }
    return BackendSystemReadiness.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  Future<BackendKnowledgeStatus> getStatus() async {
    final response = await _client.get(_baseUri.resolve('/knowledge/status'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('knowledge status failed: ${response.statusCode}');
    }
    return BackendKnowledgeStatus.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  Future<List<KnowledgeDocument>> listDocuments() async {
    final response = await _client.get(
      _baseUri.resolve('/knowledge/documents'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'knowledge document list failed: ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body) as List<Object?>;
    return decoded
        .whereType<Map>()
        .map((item) => _documentFromBackendJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  Future<KnowledgeDocument> startIngest(String backendDocumentId) async {
    final response = await _client.post(
      _baseUri.resolve('/knowledge/documents/$backendDocumentId/ingest'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('knowledge ingest failed: ${response.statusCode}');
    }
    return _documentFromBackendJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }

  KnowledgeDocument _documentFromBackendJson(
    Map<String, Object?> decoded, {
    String fallbackFilename = '',
    String fallbackLocalPath = '',
  }) {
    final id = decoded['id'] as String? ?? '';
    return KnowledgeDocument(
      id: id,
      filename: decoded['filename'] as String? ?? fallbackFilename,
      localPath:
          decoded['stored_path'] as String? ??
          decoded['source_path'] as String? ??
          fallbackLocalPath,
      sizeBytes: decoded['size_bytes'] as int? ?? 0,
      importedAt:
          DateTime.tryParse(decoded['imported_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: KnowledgeDocumentStatus.fromWireName(
        decoded['status'] as String?,
      ),
      backendDocumentId: decoded['backend_document_id'] as String? ?? id,
      errorMessage: decoded['error_message'] as String?,
    );
  }
}
