import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/ui/chat_screen.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  testWidgets('chat mode chip renders forced offline mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatModeChip(
            settings: AppSettings.defaults().copyWith(
              answerMode: AnswerModes.offline,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chat-mode-chip')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });
}
