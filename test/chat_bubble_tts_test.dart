import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/chat_bubble.dart';

void main() {
  testWidgets('assistant bubble exposes TTS controls', (tester) async {
    final calls = <String>[];
    final message = ChatMessage(
      id: 'assistant-1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Olvasható válasz.',
      createdAt: DateTime.utc(2026),
      status: 'grounded',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: message,
            onSpeak: () => calls.add('speak'),
            onPause: () => calls.add('pause'),
            onStop: () => calls.add('stop'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tts-play-assistant-1')));
    await tester.tap(find.byKey(const ValueKey('tts-pause-assistant-1')));
    await tester.tap(find.byKey(const ValueKey('tts-stop-assistant-1')));

    expect(calls, ['speak', 'pause', 'stop']);
  });

  testWidgets('user bubble does not show TTS controls', (tester) async {
    final message = ChatMessage(
      id: 'user-1',
      conversationId: 'c1',
      sender: ChatSender.user,
      text: 'Kérdés.',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(find.byKey(const ValueKey('tts-play-user-1')), findsNothing);
  });
}
