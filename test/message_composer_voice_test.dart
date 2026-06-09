import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/ui/message_composer.dart';
import 'package:djinn/src/voice/voice_input_service.dart';

void main() {
  testWidgets('microphone fills composer with voice transcript', (
    tester,
  ) async {
    final voice = FakeVoiceInputService(transcript: 'Mi a stroke protokoll?');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageComposer(
            onSend: (_) async {},
            sending: false,
            voiceInputService: voice,
            voiceLocale: 'hu-HU',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Diktálás'));
    await tester.pumpAndSettle();

    expect(find.text('Mi a stroke protokoll?'), findsOneWidget);
    expect(voice.listenLocales, ['hu-HU']);
  });
}
