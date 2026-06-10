import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/ui/message_composer.dart';
import 'package:djinn/src/voice/speech_adapter.dart';
import 'package:djinn/src/voice/tts_adapter.dart';
import 'package:djinn/src/voice/voice_controller.dart';

void main() {
  testWidgets('voice listen button sends final transcript', (tester) async {
    final sent = <String>[];
    final controller = VoiceController(
      speech: FakeSpeechAdapter(
        events: const [SpeechEvent.result('mellkasi fajdalom', true)],
      ),
      tts: FakeTtsAdapter(),
      onFinalTranscript: (text) async => sent.add(text),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            onSend: (text) async => sent.add(text),
            sending: false,
            voiceController: controller,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('voice-listen')));
    await tester.pumpAndSettle();

    expect(sent, ['mellkasi fajdalom']);
  });

  testWidgets(
    'mic tap selects conversation and long press selects push to talk',
    (tester) async {
      final modes = <VoiceInputMode>[];
      final controller = VoiceController(
        speech: FakeSpeechAdapter(events: const []),
        tts: FakeTtsAdapter(),
        onFinalTranscript: (_) async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageComposer(
              onSend: (_) async {},
              sending: false,
              voiceController: controller,
              onVoiceInputModeSelected: modes.add,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('voice-reply-toggle')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('voice-listen')));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('voice-listen')));
      await tester.pumpAndSettle();

      expect(modes, [VoiceInputMode.conversation, VoiceInputMode.pushToTalk]);
    },
  );

  testWidgets('speaking state keeps composer mic-only', (tester) async {
    final tts = _BlockingTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );
    addTearDown(controller.dispose);
    addTearDown(tts.complete);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            onSend: (_) async {},
            sending: false,
            voiceController: controller,
          ),
        ),
      ),
    );

    final speaking = controller.speak('valasz', locale: 'hu-HU');
    await tester.pump();

    expect(find.byKey(const ValueKey('voice-listen')), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-pause')), findsNothing);
    expect(find.byKey(const ValueKey('voice-stop')), findsNothing);
    expect(controller.state, VoiceState.speaking);

    tts.complete();
    await speaking;
  });
}

class _BlockingTtsAdapter extends FakeTtsAdapter {
  final _completion = Completer<void>();

  @override
  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    spokenTexts.add(text);
    await _completion.future;
  }

  void complete() {
    if (!_completion.isCompleted) {
      _completion.complete();
    }
  }
}
