import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_message.dart';

void main() {
  test('createConversation stores a new conversation summary', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );

    final conversation = await repository.createConversation();
    final conversations = await repository.listConversations();

    expect(conversation.title, 'Uj chat');
    expect(conversations, hasLength(1));
    expect(conversations.single.id, conversation.id);
  });

  test('sendMessage appends user message and assistant refusal', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();

    await repository.sendMessage(conversation.id, 'Mi az ellatasi algoritmus?');
    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.first.sender, ChatSender.user);
    expect(messages.first.text, 'Mi az ellatasi algoritmus?');
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.status, 'insufficient_evidence');
    expect(messages.last.text, contains('tudasbazis'));
  });
}
