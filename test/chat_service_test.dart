import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/openai/openai_client.dart';

void main() {
  test('persists user message and local grounded assistant response', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final service = ChatService(
      repository: repository,
      answerService: const _FakeAnswerService(
        response: LocalAnswerResult(
          text: 'Forrasbol valaszolok.',
          status: 'grounded',
          citations: [
            ChatCitation(
              documentId: 'local-doc-1',
              title: 'omsz.pdf',
              page: 1,
              section: null,
              excerpt: 'Forrasbol valaszolok.',
              sourceId: 'chunk-1',
              sourceLabel: 'Szöveges PDF-részlet',
              validationState: 'validated',
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
    expect(messages.last.citations.single.sourceId, 'chunk-1');
  });

  test('records OpenAI provider error assistant message', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final service = ChatService(
      repository: repository,
      answerService: _FailingAnswerService(),
    );

    await service.sendMessage(conversation.id, 'Mi a teendo?');
    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.status, 'openai_error');
    expect(messages.last.refusalReason, 'openai_error');
    expect(messages.last.text, contains('OpenAI'));
  });

  test('passes recent conversation history to answer service', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    await repository.appendUserMessage(
      conversation.id,
      'Mikor kell trombolizis?',
    );
    await repository.appendAssistantMessage(
      conversation.id,
      text: 'A dokumentum szerint 4,5 oran belul merul fel.',
      status: 'grounded',
    );
    final answerService = _RecordingAnswerService(
      response: const LocalAnswerResult(
        text: 'Azert, mert idofuggo beavatkozas.',
        status: 'grounded',
        citations: [],
      ),
    );
    final service = ChatService(
      repository: repository,
      answerService: answerService,
    );

    await service.sendMessage(conversation.id, 'Miért?');

    expect(answerService.questions, ['Miért?']);
    expect(
      answerService.contexts.single.map((message) => message.text),
      [
        'Mikor kell trombolizis?',
        'A dokumentum szerint 4,5 oran belul merul fel.',
      ],
    );
  });
}

class _FakeAnswerService implements AnswerService {
  const _FakeAnswerService({required this.response});

  final LocalAnswerResult response;

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async => response;
}

class _FailingAnswerService implements AnswerService {
  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    throw const OpenAiException('provider failed');
  }
}

class _RecordingAnswerService implements AnswerService {
  _RecordingAnswerService({required this.response});

  final LocalAnswerResult response;
  final questions = <String>[];
  final contexts = <List<ChatMessage>>[];

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    questions.add(question);
    contexts.add(context);
    return response;
  }
}
