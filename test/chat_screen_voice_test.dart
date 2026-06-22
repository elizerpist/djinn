import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/chat_screen.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/settings/models/app_settings.dart';
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
    await tester.tap(find.byKey(const ValueKey('voice-listen')));
    await tester.pumpAndSettle();
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
      await tester.tap(find.byKey(const ValueKey('voice-listen')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('message-input')),
        'Mi a teendo?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-message')));
      await tester.pump();

      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('message-input')),
      );
      expect(input.controller?.text, isEmpty);
      expect(input.enabled, isTrue);
      expect(input.readOnly, isFalse);
      expect(tts.started, isTrue);
    },
  );

  testWidgets('mic tap uses saved locale and enables conversation', (
    tester,
  ) async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final speech = _RecordingSpeechAdapter();
    final voiceController = VoiceController(
      speech: speech,
      tts: FakeTtsAdapter(),
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
          loadSettings: () async =>
              AppSettings.defaults().copyWith(voiceLocale: 'en-US'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('voice-reply-toggle')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('voice-listen')));
    await tester.pumpAndSettle();

    expect(speech.locales, ['en-US']);
    expect(find.byKey(const ValueKey('voice-pause')), findsNothing);
    expect(find.byKey(const ValueKey('voice-stop')), findsNothing);
  });

  testWidgets('mic long press uses push to talk without automatic TTS', (
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
    await tester.longPress(find.byKey(const ValueKey('voice-listen')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mi a teendo?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await tester.pumpAndSettle();

    expect(tts.spokenTexts, isEmpty);
  });

  testWidgets('assistant play button reads that answer aloud', (tester) async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    await repository.appendAssistantMessage(
      conversation.id,
      text: 'Korábbi válasz.',
      status: 'grounded',
    );
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

    await tester.tap(find.byKey(const ValueKey('assistant-play-message-1')));
    await tester.pumpAndSettle();

    expect(tts.spokenTexts, ['Korábbi válasz.']);
  });

  testWidgets('stopping a spoken voice reply restarts conversation listening', (
    tester,
  ) async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final speech = _RecordingSpeechAdapter();
    final tts = _BlockingTtsAdapter();
    final voiceController = VoiceController(
      speech: speech,
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
    await tester.tap(find.byKey(const ValueKey('voice-listen')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mi a teendo?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));

    final stopButton = find.byKey(const ValueKey('assistant-stop-message-2'));
    for (var i = 0; i < 10 && stopButton.evaluate().isEmpty; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(stopButton, findsOneWidget);
    expect(speech.locales, ['hu-HU']);

    await tester.tap(stopButton);
    for (var i = 0; i < 5 && speech.locales.length < 2; i += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(speech.locales, ['hu-HU', 'hu-HU']);
  });

  testWidgets('mic tap during TTS stops playback and starts conversation', (
    tester,
  ) async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    await repository.appendAssistantMessage(
      conversation.id,
      text: 'Felolvasott válasz.',
      status: 'grounded',
    );
    final speech = _RecordingSpeechAdapter();
    final tts = _BlockingTtsAdapter();
    final voiceController = VoiceController(
      speech: speech,
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

    await tester.tap(find.byKey(const ValueKey('assistant-play-message-1')));
    await tester.pump();

    expect(voiceController.state, VoiceState.speaking);

    await tester.tap(find.byKey(const ValueKey('voice-listen')));
    await tester.pumpAndSettle();

    expect(tts.stopCount, 1);
    expect(speech.locales, ['hu-HU']);
  });

  testWidgets('citation tap opens fullscreen read-only source preview', (
    tester,
  ) async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    await repository.appendAssistantMessage(
      conversation.id,
      text: 'Forrásolt válasz.',
      status: 'grounded',
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'omsz.pdf',
          page: 7,
          section: 'ABCDE',
          excerpt: 'Ez a hivatkozott forrásrészlet.',
          fullChunkText:
              'Teljes chunk szöveg első mondata.\nMásodik releváns rész.',
          sourceId: 'chunk-7',
          sourceLabel: 'PDF',
        ),
      ],
    );

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
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('citation-chunk-7')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('citation-preview-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('citation-preview-text')), findsOneWidget);
    expect(find.text('omsz.pdf'), findsWidgets);
    expect(find.text('7. oldal'), findsOneWidget);
    expect(find.text('ABCDE'), findsOneWidget);
    expect(find.text('Ez a hivatkozott forrásrészlet.'), findsOneWidget);
    expect(find.text('Teljes chunk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('citation-preview-full-chunk')),
      findsOneWidget,
    );
    expect(
      find.text('Teljes chunk szöveg első mondata.\nMásodik releváns rész.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('citation-start-scope')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('citation-start-scope')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('citation-preview-screen')), findsNothing);
    expect(find.text('Ez a hivatkozott forrásrészlet.'), findsOneWidget);
  });
}

class _FakeAnswerService implements AnswerService {
  const _FakeAnswerService();

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
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

class _RecordingSpeechAdapter implements SpeechAdapter {
  final List<String> locales = [];

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    locales.add(locale);
    return Stream<SpeechEvent>.fromIterable(const []);
  }

  @override
  Future<void> stop() async {}
}
