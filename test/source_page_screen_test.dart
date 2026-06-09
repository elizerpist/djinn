import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/knowledge/ui/source_page_screen.dart';

void main() {
  testWidgets('source page shows filename, page, source type and excerpt', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SourcePageScreen(
          citation: ChatCitation(
            documentId: 'doc-1',
            title: 'protocol.pdf',
            page: 4,
            section: null,
            excerpt: 'ABCDE részlet',
            sourceId: 'chunk-1',
            sourceLabel: 'Szöveges PDF-részlet',
            validationState: 'validated',
          ),
        ),
      ),
    );

    expect(find.text('protocol.pdf'), findsOneWidget);
    expect(find.text('4. oldal'), findsOneWidget);
    expect(find.text('Szöveges PDF-részlet'), findsOneWidget);
    expect(find.text('ABCDE részlet'), findsOneWidget);
  });
}
