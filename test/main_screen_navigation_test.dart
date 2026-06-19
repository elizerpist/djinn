import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/cases/data/case_repository.dart';
import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/main_screen.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  testWidgets('main shell always uses fixed bottom navigation', (tester) async {
    await tester.pumpWidget(_mainScreenApp(AppSettings.defaults()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();
    expect(labels, ['Jegyzetek', 'Tudástár', 'Chat', 'Beáll.']);
    expect(find.text('Audit'), findsNothing);
    expect(find.text('Validálás'), findsNothing);
    expect(find.text('Flow'), findsNothing);
  });

  testWidgets('bottom navigation opens notes, knowledge, chat and settings', (
    tester,
  ) async {
    await tester.pumpWidget(_mainScreenApp(AppSettings.defaults()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jegyzetek'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs mentett jegyzet'), findsOneWidget);
    expect(find.byTooltip('Új chat'), findsNothing);

    await tester.tap(find.text('Tudástár'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs importált dokumentum'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs még beszélgetés'), findsOneWidget);
    expect(find.byTooltip('Új chat'), findsOneWidget);

    await tester.tap(find.text('Beáll.'));
    await tester.pumpAndSettle();
    expect(find.text('AI'), findsOneWidget);
  });

  testWidgets('bottom navigation keeps visited destinations alive', (
    tester,
  ) async {
    final noteRepository = _CountingNoteRepository();
    await tester.pumpWidget(
      _mainScreenApp(AppSettings.defaults(), noteRepository: noteRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jegyzetek'));
    await tester.pumpAndSettle();
    final callsAfterFirstOpen = noteRepository.listNotesCalls;
    expect(callsAfterFirstOpen, greaterThan(0));

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jegyzetek'));
    await tester.pumpAndSettle();

    expect(noteRepository.listNotesCalls, callsAfterFirstOpen);
  });
}

Widget _mainScreenApp(
  AppSettings initialSettings, {
  NoteRepository? noteRepository,
}) {
  final chatRepository = LocalChatRepository();
  final knowledgeRepository = KnowledgeDocumentRepository();
  var settings = initialSettings;
  return MaterialApp(
    home: MainScreen(
      repository: chatRepository,
      chatService: ChatService(
        repository: chatRepository,
        answerService: const _StubAnswerService(),
      ),
      knowledgeRepository: knowledgeRepository,
      noteRepository: noteRepository ?? MemoryNoteRepository(),
      pdfImportService: PdfImportService(importDirectory: Directory('/memory')),
      refreshKnowledgeReadiness: knowledgeRepository.state,
      apiKeyStore: MemoryApiKeyStore(),
      loadSettings: () async => settings,
      saveSettings: (value) async => settings = value,
      testApiKey: () async => true,
      testApiKeyForProvider: (AiProvider provider, String model) async => true,
      caseRepository: MemoryCaseRepository(),
    ),
  );
}

class _StubAnswerService implements AnswerService {
  const _StubAnswerService();

  @override
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    return const LocalAnswerResult(text: 'OK', status: 'ok', citations: []);
  }
}

class _CountingNoteRepository extends MemoryNoteRepository {
  int listNotesCalls = 0;

  @override
  Future<List<NoteItem>> listNotes({String? folderId, NoteItemType? type}) {
    listNotesCalls += 1;
    return super.listNotes(folderId: folderId, type: type);
  }
}
