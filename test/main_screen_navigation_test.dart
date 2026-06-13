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
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  testWidgets('drawer navigation is the default shell', (tester) async {
    await tester.pumpWidget(_mainScreenApp(AppSettings.defaults()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Beszélgetések'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Esetek'), findsOneWidget);
    expect(find.text('Tudástár'), findsOneWidget);
    expect(find.text('Flowchart validáció'), findsOneWidget);
    expect(find.text('Beállítások'), findsOneWidget);
  });

  testWidgets('bottom navigation renders Flow before Tudástár and opens the hub', (
    tester,
  ) async {
    await tester.pumpWidget(
      _mainScreenApp(
        AppSettings.defaults().copyWith(
          navigationMode: AppNavigationMode.bottomNav,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((destination) => destination.label)
        .toList();
    expect(labels, ['Esetek', 'Flow', 'Chat', 'Tudástár', 'Beáll.']);
    expect(find.byTooltip('Új chat'), findsOneWidget);
    expect(find.byKey(const ValueKey('debug-header-button')), findsOneWidget);

    await tester.tap(find.text('Esetek'));
    await tester.pumpAndSettle();
    expect(find.text('Nincs mentett eset'), findsOneWidget);
    expect(find.byTooltip('Új chat'), findsNothing);
    expect(find.byTooltip('Új eset'), findsOneWidget);

    await tester.tap(find.text('Flow'));
    await tester.pumpAndSettle();
    expect(find.text('Validálás'), findsOneWidget);
    expect(find.text('Kinyert'), findsOneWidget);
    expect(find.text('Építő'), findsOneWidget);
    expect(find.text('Sablonok'), findsOneWidget);
    expect(
      find.textContaining('Flowchart validáció nem elérhető'),
      findsOneWidget,
    );
  });
}

Widget _mainScreenApp(AppSettings initialSettings) {
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
