import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/chat_bubble.dart';

void main() {
  testWidgets('renders validation warning and citation label', (tester) async {
    final message = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Válasz.',
      createdAt: DateTime.utc(2026),
      status: 'grounded',
      hasValidationWarning: true,
      warningText: 'A válasz nem validált flowchart elemet használ.',
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'omsz.pdf',
          page: 1,
          section: null,
          excerpt: 'Forrás',
          sourceId: 'node-1',
          sourceLabel: 'Nem validált flowchart',
          validationState: 'unreviewed',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(find.textContaining('nem validált'), findsWidgets);
    expect(find.text('Nem validált flowchart'), findsOneWidget);
  });

  testWidgets('citation tap reports selected citation for source page', (
    tester,
  ) async {
    ChatCitation? opened;
    final message = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Válasz.',
      createdAt: DateTime.utc(2026),
      status: 'grounded',
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'omsz.pdf',
          page: 3,
          section: null,
          excerpt: 'Forrás',
          sourceId: 'chunk-1',
          sourceLabel: 'Szöveges PDF-részlet',
          validationState: 'validated',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: message,
            onCitationTap: (value) => opened = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('omsz.pdf p.3'));

    expect(opened?.sourceId, 'chunk-1');
  });
}
