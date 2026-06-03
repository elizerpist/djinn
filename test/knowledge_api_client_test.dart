import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/knowledge_api_client.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';

void main() {
  test('uploads a PDF to the backend knowledge document endpoint', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-api-client-');
    addTearDown(() => directory.delete(recursive: true));
    final pdf = File('${directory.path}/protocol.pdf');
    await pdf.writeAsBytes([37, 80, 68, 70]);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final requestSeen = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/knowledge/documents');
      expect(request.headers.contentType?.mimeType, 'multipart/form-data');
      final body = await utf8.decoder.bind(request).join();
      expect(body, contains('protocol.pdf'));
      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'id': 'backend-1',
          'filename': 'protocol.pdf',
          'status': 'pending_ingest',
          'size_bytes': 4,
          'imported_at': '2026-01-01T12:00:00Z',
          'source_path': '/corpus/protocol.pdf',
        }));
      await request.response.close();
    });

    final client = KnowledgeApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );
    final result = await client.uploadDocument(localPath: pdf.path, filename: 'protocol.pdf');

    expect(result.id, 'backend-1');
    expect(result.status, KnowledgeDocumentStatus.pendingIngest);
    await requestSeen;
  });
}
