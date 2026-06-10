import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/ui/chat_screen.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/voice/speech_adapter.dart';
import 'package:djinn/src/voice/tts_adapter.dart';
import 'package:djinn/src/voice/voice_controller.dart';

void main() {
  testWidgets('voice reply mode reads the latest assistant response', (
    tester,
  ) async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final tts = FakeTtsAdapter();
    final voiceController = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );
    addTearDown(voiceController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          repository: repository,
          chatService: ChatService(
            repository: repository,
            answerService: const _FakeAnswerService(),
          ),
          refreshKnowledgeReadiness: () async =>
              KnowledgeBaseState.fromDocuments(const []),
          conversation: conversation,
          voiceController: voiceController,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('voice-reply-toggle')));
    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mi a teendo?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await tester.pumpAndSettle();

    expect(tts.spokenTexts, ['Forrasolt valasz.']);
  });

  testWidgets(
    'voice reply does not keep composer blocked until TTS completes',
    (tester) async {
      final repository = LocalChatRepository(
        clock: () => DateTime.utc(2026, 1, 1, 12),
      );
      final conversation = await repository.createConversation();
      final tts = _BlockingTtsAdapter();
      final voiceController = VoiceController(
        speech: FakeSpeechAdapter(events: const []),
        tts: tts,
        onFinalTranscript: (_) async {},
      );
      addTearDown(voiceController.dispose);
      addTearDown(tts.complete);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            repository: repository,
            chatService: ChatService(
              repository: repository,
              answerService: const _FakeAnswerService(),
            ),
            refreshKnowledgeReadiness: () async =>
                KnowledgeBaseState.fromDocuments(const []),
            conversation: conversation,
            voiceController: voiceController,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('voice-reply-toggle')));
      await tester.enterText(
        find.byKey(const ValueKey('message-input')),
        'Mi a teendo?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-message')));
      await tester.pump();

      final input = tester.widget<EditableText>(find.byType(EditableText));
      expect(input.controller.text, isEmpty);
      expect(input.readOnly, isFalse);
      expect(tts.started, isTrue);
    },
  );
}

class _FakeAnswerService implements AnswerService {
  const _FakeAnswerService();

  @override
  Future<LocalAnswerResult> answer(String question) async {
    return const LocalAnswerResult(
      text: 'Forrasolt valasz.',
      status: 'grounded',
      citations: [],
    );
  }
}

class _BlockingTtsAdapter extends FakeTtsAdapter {
  final _completion = Completer<void>();
  var started = false;

  @override
  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    started = true;
    spokenTexts.add(text);
    await _completion.future;
  }

  void complete() {
    if (!_completion.isCompleted) {
      _completion.complete();
    }
  }
}
