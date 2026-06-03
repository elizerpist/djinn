import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/main.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';

void main() {
  testWidgets('Djinn opens a new chat and sends a text message', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    expect(find.text('Djinn'), findsOneWidget);
    expect(find.text('Nincs meg chat'), findsOneWidget);
    expect(find.byTooltip('Tudastar'), findsOneWidget);

    await tester.tap(find.byTooltip('Uj chat'));
    await _pumpUntilFound(tester, find.byKey(const ValueKey('message-input')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Uj chat'), findsOneWidget);
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

  testWidgets('Djinn opens the knowledge base screen from the folder button', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());
    await _pumpUntilFound(tester, find.text('Djinn'));

    await tester.tap(find.byTooltip('Tudastar'));
    await _pumpUntilFound(tester, find.text('Tudastar'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Tudastar'), findsOneWidget);
    expect(find.text('Nincs importalt PDF'), findsOneWidget);
    expect(find.byTooltip('PDF hozzaadasa'), findsOneWidget);
  });
}

DjinnApp _testApp() {
  return DjinnApp(
    chatRepository: LocalChatRepository(),
    knowledgeRepository: KnowledgeDocumentRepository(),
    pdfImportService: PdfImportService(importDirectory: Directory('/memory')),
  );
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
