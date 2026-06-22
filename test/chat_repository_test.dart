import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/core/storage/json_file_store.dart';

import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';

void main() {
  test('createConversation stores a new conversation summary', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );

    final conversation = await repository.createConversation();
    final conversations = await repository.listConversations();

    expect(conversation.title, 'Új chat');
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

  test('reloads messages with citations and refusal reason', () async {
    final message = ChatMessage(
      id: 'message-1',
      conversationId: 'conversation-1',
      sender: ChatSender.assistant,
      text: 'Valasz forrassal',
      createdAt: DateTime.utc(2026, 1, 1, 12),
      status: 'grounded',
      refusalReason: null,
      citations: const [
        ChatCitation(
          documentId: 'backend-doc-1',
          title: 'omsz.pdf',
          page: 2,
          section: null,
          excerpt: 'Valasz forrassal',
          fullChunkText: 'Teljes chunk szovege',
        ),
      ],
    );

    final reloaded = ChatMessage.fromJson(message.toJson());

    expect(reloaded.citations.single.documentId, 'backend-doc-1');
    expect(reloaded.citations.single.page, 2);
    expect(reloaded.citations.single.fullChunkText, 'Teljes chunk szovege');
    expect(reloaded.refusalReason, isNull);
  });

  test('persists conversations across repository reload', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-chat-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonFileStore(File('${directory.path}/chat.json'));

    final firstRepository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
      store: store,
    );
    await firstRepository.load();
    final conversation = await firstRepository.createConversation();
    await firstRepository.sendMessage(
      conversation.id,
      'Mellkasi fajdalom protokoll?',
    );

    final secondRepository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 13),
      store: store,
    );
    await secondRepository.load();

    final conversations = await secondRepository.listConversations();
    final messages = await secondRepository.getMessages(conversation.id);
    expect(conversations, hasLength(1));
    expect(conversations.single.title, 'Mellkasi fajdalom protokoll?');
    expect(messages, hasLength(2));
  });
}
