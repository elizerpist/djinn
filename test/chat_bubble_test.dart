import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/chat_bubble.dart';

void main() {
  testWidgets(
    'assistant messages expose play button but user messages do not',
    (tester) async {
      final assistant = ChatMessage(
        id: 'assistant-1',
        conversationId: 'c1',
        sender: ChatSender.assistant,
        text: 'Felolvasható válasz.',
        createdAt: DateTime.utc(2026),
      );
      final user = ChatMessage(
        id: 'user-1',
        conversationId: 'c1',
        sender: ChatSender.user,
        text: 'Kérdés',
        createdAt: DateTime.utc(2026),
      );
      ChatMessage? played;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ChatBubble(
                  message: assistant,
                  onPlay: (message) => played = message,
                ),
                ChatBubble(
                  message: user,
                  onPlay: (message) => played = message,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('assistant-play-assistant-1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistant-play-user-1')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('assistant-play-assistant-1')),
      );
      await tester.pump();

      expect(played, assistant);
    },
  );

  testWidgets('assistant TTS controls sit below the bubble text', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'assistant-1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Felolvasható válasz.',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(message: message, onPlay: (_) {}),
        ),
      ),
    );

    final textBottom = tester.getRect(find.text('Felolvasható válasz.')).bottom;
    final playTop = tester
        .getRect(find.byKey(const ValueKey('assistant-play-assistant-1')))
        .top;

    expect(playTop, greaterThan(textBottom));
  });

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

  testWidgets('citation row is tappable', (tester) async {
    const citation = ChatCitation(
      documentId: 'doc-1',
      title: 'omsz.pdf',
      page: 4,
      section: 'ABCDE',
      excerpt: 'Forrás részlet',
      sourceId: 'chunk-1',
      sourceLabel: 'PDF',
      validationState: 'valid',
    );
    final message = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Válasz.',
      createdAt: DateTime.utc(2026),
      status: 'grounded',
      citations: const [citation],
    );
    ChatCitation? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: message,
            onCitationTap: (citation) => opened = citation,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('citation-chunk-1')));
    await tester.pump();

    expect(opened, citation);
  });

  testWidgets('renders table citation as a compact structured card', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'm-table',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'A táblázat szerint.',
      createdAt: DateTime.utc(2026),
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'rave.png',
          page: 2,
          section: 'RAVE',
          excerpt: 'Tünet | Érték | Pont\nArcparesis | jelen | 1',
          sourceId: 'table-1',
          sourceType: 'table_chunk',
          sourceLabel: 'Táblázatból kinyert részlet',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(find.byKey(const ValueKey('citation-card-table-1')), findsOneWidget);
    expect(find.text('Tünet'), findsOneWidget);
    expect(find.text('Arcparesis'), findsOneWidget);
  });

  testWidgets('renders flowchart citation as a relationship card', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'm-flow',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Az algoritmus szerint.',
      createdAt: DateTime.utc(2026),
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'stroke.pdf',
          page: 3,
          section: 'Stroke döntési fa',
          excerpt: 'ABCDE vizsgálat -> Légzési elégtelenség? [romlik]',
          sourceId: 'flow-1:e1',
          sourceType: 'flowchart_edge',
          sourceLabel: 'Nem validált flowchart',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(
      find.byKey(const ValueKey('citation-card-flow-1:e1')),
      findsOneWidget,
    );
    expect(find.textContaining('ABCDE vizsgálat'), findsOneWidget);
    expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
  });

  testWidgets('speaking assistant bubble shows pause and stop', (tester) async {
    final message = ChatMessage(
      id: 'assistant-1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Válasz.',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: message,
            ttsState: BubbleTtsState.speaking,
            onPause: (_) {},
            onStop: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('assistant-pause-assistant-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-stop-assistant-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('assistant-play-assistant-1')),
      findsNothing,
    );
  });
  testWidgets('message body text is selectable for copy and highlight', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'assistant-selectable',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Másolható válasz.',
      createdAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: message)),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == 'Másolható válasz.',
      ),
      findsOneWidget,
    );
  });
}
