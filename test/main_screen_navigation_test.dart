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
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
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

  testWidgets('main shell creates stable destination containers up front', (
    tester,
  ) async {
    await tester.pumpWidget(_mainScreenApp(AppSettings.defaults()));
    await tester.pumpAndSettle();

    for (final destination in ['notes', 'knowledge', 'chat', 'settings']) {
      expect(
        find.byKey(
          ValueKey('main-destination-shell-$destination'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    }
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

  testWidgets('destination FABs rotate and scale in both directions', (
    tester,
  ) async {
    await tester.pumpWidget(_mainScreenApp(AppSettings.defaults()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('main-destination-fab-chat')),
      findsOneWidget,
    );

    await tester.tap(find.text('Jegyzetek'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(const ValueKey('main-destination-fab-chat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('main-destination-fab-notes')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('main-destination-fab-chat')),
        matching: find.byType(RotationTransition),
      ),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('main-destination-fab-notes')),
        matching: find.byType(RotationTransition),
      ),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('main-destination-fab-chat')),
        matching: find.byType(ScaleTransition),
      ),
      findsWidgets,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('main-destination-fab-notes')),
        matching: find.byType(ScaleTransition),
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('main-destination-fab-chat')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('main-destination-fab-notes')),
      findsOneWidget,
    );

    await tester.tap(find.text('Tudástár'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(const ValueKey('main-destination-fab-notes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('main-destination-fab-knowledge')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(const ValueKey('main-destination-fab-knowledge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('main-destination-fab-chat')),
      findsOneWidget,
    );
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

  testWidgets('pdf chunk list stays inside knowledge tab navigation shell', (
    tester,
  ) async {
    final knowledgeRepository = KnowledgeDocumentRepository();
    final document = await knowledgeRepository.addDocument(
      filename: 'chunks.pdf',
      localPath: '/memory/chunks.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 25),
      sha256: 'hash-chunks',
    );
    await knowledgeRepository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'manual-chunk-1',
        documentId: 'document-1',
        text: 'Manuális chunk',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      _mainScreenApp(
        AppSettings.defaults(),
        knowledgeRepository: knowledgeRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tudástár'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chunks.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('AI chunkok'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Tudástár'), findsWidgets);
  });

  testWidgets(
    'note chunk list keeps bottom nav and chunk editor is fullscreen',
    (tester) async {
      final noteRepository = MemoryNoteRepository();
      final note = await noteRepository.createDocumentNote(
        title: 'Oxigén cél',
        document: const NoteDocument(
          blocks: [
            NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Régi'),
          ],
        ),
      );

      await tester.pumpWidget(
        _mainScreenApp(AppSettings.defaults(), noteRepository: noteRepository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jegyzetek'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('note-box-${note.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('note-chunk-card-a')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note-text-chunk-editor')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
}

Widget _mainScreenApp(
  AppSettings initialSettings, {
  NoteRepository? noteRepository,
  KnowledgeDocumentRepository? knowledgeRepository,
}) {
  final chatRepository = LocalChatRepository();
  final resolvedKnowledgeRepository =
      knowledgeRepository ?? KnowledgeDocumentRepository();
  var settings = initialSettings;
  return MaterialApp(
    home: MainScreen(
      repository: chatRepository,
      chatService: ChatService(
        repository: chatRepository,
        answerService: const _StubAnswerService(),
      ),
      knowledgeRepository: resolvedKnowledgeRepository,
      noteRepository: noteRepository ?? MemoryNoteRepository(),
      pdfImportService: PdfImportService(importDirectory: Directory('/memory')),
      refreshKnowledgeReadiness: resolvedKnowledgeRepository.state,
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
