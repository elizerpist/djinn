import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/backend_chat_client.dart';

void main() {
  test('posts a chat request and parses cited backend response', () async {
    final requests = <Map<String, Object?>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      requests.add({
        'method': request.method,
        'path': request.uri.path,
        'body': jsonDecode(await utf8.decoder.bind(request).join()),
      });
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'conversation_id': 'backend-conversation-1',
            'answer': 'Az ellatas lepesei a protokoll szerint...',
            'status': 'grounded',
            'citations': [
              {
                'document_id': 'backend-doc-1',
                'title': 'omsz.pdf',
                'page': 2,
                'section': null,
                'excerpt': 'Az ellatas lepesei a protokoll szerint...',
              },
            ],
            'refusal_reason': null,
          }),
        );
      await request.response.close();
    });

    final client = BackendChatClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    final response = await client.sendMessage(
      message: 'Mi a teendo?',
      conversationId: 'conversation-1',
    );

    expect(response.conversationId, 'backend-conversation-1');
    expect(response.answer, contains('protokoll'));
    expect(response.status, 'grounded');
    expect(response.citations.single.documentId, 'backend-doc-1');
    expect(response.citations.single.page, 2);
    expect(response.refusalReason, isNull);
    expect(requests.single['method'], 'POST');
    expect(requests.single['path'], '/chat');
    expect((requests.single['body'] as Map)['message'], 'Mi a teendo?');
    expect(
      (requests.single['body'] as Map)['conversation_id'],
      'conversation-1',
    );
  });

  test('throws BackendChatException on non-success response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = 503;
      await request.response.close();
    });

    final client = BackendChatClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    expect(
      () => client.sendMessage(message: 'Kerdes'),
      throwsA(isA<BackendChatException>()),
    );
  });
}
