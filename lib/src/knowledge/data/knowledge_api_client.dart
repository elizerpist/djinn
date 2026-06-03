import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/knowledge_document.dart';

class KnowledgeApiClient {
  KnowledgeApiClient({
    required Uri baseUri,
    http.Client? client,
  })  : _baseUri = baseUri,
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Future<KnowledgeDocument> uploadDocument({
    required String localPath,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', _baseUri.resolve('/knowledge/documents'));
    request.files.add(await http.MultipartFile.fromPath('file', localPath, filename: filename));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('knowledge document upload failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final id = decoded['id'] as String? ?? '';
    return KnowledgeDocument(
      id: id,
      filename: decoded['filename'] as String? ?? filename,
      localPath: decoded['source_path'] as String? ?? localPath,
      sizeBytes: decoded['size_bytes'] as int? ?? 0,
      importedAt: DateTime.tryParse(decoded['imported_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: KnowledgeDocumentStatus.fromWireName(decoded['status'] as String?),
      backendDocumentId: id,
    );
  }
}
