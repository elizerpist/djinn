import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/backend_chat_client.dart';
import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';

void main() {
  test('persists user message and backend assistant response', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final service = ChatService(
      repository: repository,
      backend: _FakeBackendChatClient(
        response: const BackendChatResponse(
          conversationId: 'backend-conversation-1',
          answer: 'Forrasbol valaszolok.',
          status: 'grounded',
          citations: [
            ChatCitation(
              documentId: 'backend-doc-1',
              title: 'omsz.pdf',
              page: 1,
              section: null,
              excerpt: 'Forrasbol valaszolok.',
            ),
          ],
        ),
      ),
    );

    await service.sendMessage(conversation.id, 'Mi a teendo?');
    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.first.sender, ChatSender.user);
    expect(messages.first.text, 'Mi a teendo?');
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.text, 'Forrasbol valaszolok.');
    expect(messages.last.status, 'grounded');
    expect(messages.last.citations.single.documentId, 'backend-doc-1');
  });

  test('records backend unavailable assistant message', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final service = ChatService(
      repository: repository,
      backend: _FailingBackendChatClient(),
    );

    await service.sendMessage(conversation.id, 'Mi a teendo?');
    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.status, 'backend_unavailable');
    expect(messages.last.refusalReason, 'backend_unavailable');
    expect(messages.last.text, contains('Backend'));
  });
}

class _FakeBackendChatClient extends BackendChatClient {
  _FakeBackendChatClient({required this.response})
    : super(baseUri: Uri.parse('http://localhost'));

  final BackendChatResponse response;

  @override
  Future<BackendChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    return response;
  }
}

class _FailingBackendChatClient extends BackendChatClient {
  _FailingBackendChatClient() : super(baseUri: Uri.parse('http://localhost'));

  @override
  Future<BackendChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    throw BackendChatException('backend chat failed: 503');
  }
}
