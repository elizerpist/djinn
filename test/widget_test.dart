import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/main.dart';
import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/chat_bubble.dart';
import 'package:djinn/src/knowledge/data/knowledge_api_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/knowledge_sync_service.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  testWidgets('Djinn opens a new chat and sends a text message', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    expect(find.text('Djinn'), findsOneWidget);
    expect(find.text('Nincs még beszélgetés'), findsOneWidget);
    expect(find.byTooltip('Tudastar'), findsOneWidget);

    await tester.tap(find.byTooltip('Új chat'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('message-input')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Új chat'), findsOneWidget);
    expect(find.text('Nincs betoltott tudastar'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mi az ellatasi algoritmus?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await _pumpUntilFound(tester, find.text('Mi az ellatasi algoritmus?'));

    expect(find.text('Mi az ellatasi algoritmus?'), findsOneWidget);
    expect(find.textContaining('tudasbazis'), findsOneWidget);
  });

  testWidgets('Djinn renders backend chat response text', (tester) async {
    final chatRepository = LocalChatRepository();
    final chatService = ChatService(
      repository: chatRepository,
      answerService: const _BackendAnswerService(),
    );

    await tester.pumpWidget(
      _testApp(chatRepository: chatRepository, chatService: chatService),
    );
    await _pumpUntilFound(tester, find.text('Djinn'));

    await tester.tap(find.byTooltip('Új chat'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('message-input')));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mi a teendo?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await _pumpUntilFound(tester, find.text('Forrasbol valaszolok.'));

    expect(find.text('Forrasbol valaszolok.'), findsOneWidget);
    expect(find.text('omsz.pdf p.1'), findsOneWidget);
  });

  testWidgets('Djinn refreshes knowledge readiness before sending', (
    tester,
  ) async {
    final knowledgeRepository = KnowledgeDocumentRepository();
    final syncService = _SequencedKnowledgeSyncService(
      repository: knowledgeRepository,
      states: [
        KnowledgeBaseState.fromDocuments(const []),
        KnowledgeBaseState.fromDocuments([_processedDocument()]),
      ],
    );

    await tester.pumpWidget(
      _testApp(
        knowledgeRepository: knowledgeRepository,
        knowledgeSyncService: syncService,
      ),
    );
    await _pumpUntilFound(tester, find.text('Djinn'));

    await tester.tap(find.byTooltip('Új chat'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('message-input')));
    await tester.pump(const Duration(milliseconds: 500));
    await _pumpUntilFound(tester, find.text('Nincs betoltott tudastar'));

    await tester.enterText(
      find.byKey(const ValueKey('message-input')),
      'Mit mond a protokoll?',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await _pumpUntilFound(tester, find.text('Tudastar kesz: 1 PDF'));

    expect(syncService.refreshReadinessCalls, 2);
  });

  testWidgets('Djinn renders a friendly strict refusal label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatBubble(
            message: ChatMessage(
              id: 'message-1',
              conversationId: 'conversation-1',
              sender: ChatSender.assistant,
              text: 'A valasz allitasai nem voltak teljesen alatamaszthatok.',
              createdAt: DateTime.utc(2026, 1, 1),
              status: 'insufficient_evidence',
              refusalReason: 'groundedness_verification_failed',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nem tamaszthato ala teljesen'), findsOneWidget);
  });

  testWidgets('Djinn opens the knowledge base screen from the folder button', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    await tester.tap(find.byTooltip('Tudastar'));
    await _pumpUntilFound(tester, find.text('Tudástár'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tudástár'), findsOneWidget);
    expect(find.text('Nincs importált PDF'), findsOneWidget);
    expect(find.byTooltip('PDF hozzáadása'), findsOneWidget);
  });

  testWidgets('Djinn opens settings from the hamburger menu', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beállítások'));
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.byKey(const Key('openai-api-key-field')), findsOneWidget);
  });

  testWidgets('Djinn shows the onscreen debug button', (tester) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    expect(find.byKey(const ValueKey('debug-floating-button')), findsOneWidget);
  });

  testWidgets('Djinn keeps the onscreen debug button on pushed routes', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beállítások'));
    await tester.pumpAndSettle();

    expect(find.text('AI'), findsOneWidget);
    expect(find.byKey(const ValueKey('debug-floating-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('debug-floating-button')));
    await tester.pumpAndSettle();

    expect(find.text('Debug Console'), findsOneWidget);
  });
}

DjinnApp _testApp({
  LocalChatRepository? chatRepository,
  ChatService? chatService,
  KnowledgeDocumentRepository? knowledgeRepository,
  KnowledgeSyncService? knowledgeSyncService,
}) {
  final resolvedChatRepository = chatRepository ?? LocalChatRepository();
  final resolvedKnowledgeRepository =
      knowledgeRepository ?? KnowledgeDocumentRepository();
  var settings = AppSettings.defaults();
  return DjinnApp(
    chatRepository: resolvedChatRepository,
    chatService:
        chatService ??
        ChatService(
          repository: resolvedChatRepository,
          answerService: const _DefaultRefusalService(),
        ),
    knowledgeRepository: resolvedKnowledgeRepository,
    pdfImportService: PdfImportService(importDirectory: Directory('/memory')),
    knowledgeSyncService: knowledgeSyncService,
    apiKeyStore: MemoryApiKeyStore(),
    loadSettings: () async => settings,
    saveSettings: (value) async => settings = value,
    testApiKey: () async => true,
  );
}

KnowledgeDocument _processedDocument() {
  return KnowledgeDocument(
    id: 'document-1',
    filename: 'omsz.pdf',
    localPath: '/memory/omsz.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 1, 1, 12),
    status: KnowledgeDocumentStatus.processed,
    backendDocumentId: 'backend-1',
  );
}

class _SequencedKnowledgeSyncService extends KnowledgeSyncService {
  _SequencedKnowledgeSyncService({
    required super.repository,
    required this.states,
  }) : super(
         client: KnowledgeApiClient(baseUri: Uri.parse('http://localhost')),
       );

  final List<KnowledgeBaseState> states;
  int refreshReadinessCalls = 0;

  @override
  Future<KnowledgeBaseState> refreshReadiness() async {
    if (states.isEmpty) {
      return repository.state();
    }
    final index = refreshReadinessCalls < states.length
        ? refreshReadinessCalls
        : states.length - 1;
    refreshReadinessCalls += 1;
    return states[index];
  }
}

class _DefaultRefusalService implements AnswerService {
  const _DefaultRefusalService();

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    return const LocalAnswerResult(
      text:
          'A tudasbazisban nincs elegendo hitelesitett forras ehhez a valaszhoz. Csak az alkalmazas dokumentumai alapjan tudok valaszolni.',
      status: 'insufficient_evidence',
      citations: [],
      refusalReason: 'insufficient_evidence',
    );
  }
}

class _BackendAnswerService implements AnswerService {
  const _BackendAnswerService();

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    return const LocalAnswerResult(
      text: 'Forrasbol valaszolok.',
      status: 'grounded',
      citations: [
        ChatCitation(
          documentId: 'backend-doc-1',
          title: 'omsz.pdf',
          page: 1,
          section: null,
          excerpt: 'Forrasbol valaszolok.',
        ),
      ],
    );
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}
