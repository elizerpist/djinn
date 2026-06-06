import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/chat/data/objectbox_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';

void main() {
  test('persists conversations and assistant citations in ObjectBox', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-ob-chat-');
    addTearDown(() => directory.delete(recursive: true));
    final ObjectBoxStore objectBox;
    try {
      objectBox = await ObjectBoxStore.open(directory: directory);
    } on ArgumentError catch (error) {
      markTestSkipped('Host ObjectBox library unavailable: $error');
      return;
    }
    addTearDown(objectBox.close);

    final firstRepository = ObjectBoxChatRepository(
      store: objectBox.store,
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await firstRepository.createConversation();
    await firstRepository.appendUserMessage(conversation.id, 'Kérdés');
    await firstRepository.appendAssistantMessage(
      conversation.id,
      text: 'Válasz',
      status: 'grounded',
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'omsz.pdf',
          page: 1,
          section: null,
          excerpt: 'Forrás',
          sourceId: 'chunk-1',
          sourceLabel: 'Szöveges PDF-részlet',
          validationState: 'validated',
        ),
      ],
    );

    final secondRepository = ObjectBoxChatRepository(
      store: objectBox.store,
      clock: () => DateTime.utc(2026, 1, 1, 13),
    );
    final conversations = await secondRepository.listConversations();
    final messages = await secondRepository.getMessages(conversation.id);

    expect(conversations.single.title, 'Kérdés');
    expect(messages, hasLength(2));
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.citations.single.sourceLabel, 'Szöveges PDF-részlet');
  });
}
