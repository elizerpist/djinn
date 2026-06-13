import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/cases/data/case_repository.dart';
import 'package:djinn/src/cases/ui/cases_screen.dart';

void main() {
  testWidgets('cases screen creates a new case and opens notes detail', (
    tester,
  ) async {
    final repository = MemoryCaseRepository(
      clock: () => DateTime.utc(2026, 6, 13, 10),
    );

    await tester.pumpWidget(
      MaterialApp(home: CasesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nincs mentett eset'), findsOneWidget);

    await tester.tap(find.byTooltip('Új eset'));
    await tester.pumpAndSettle();

    expect(find.text('Új eset'), findsOneWidget);
    expect(find.text('0 chat'), findsOneWidget);
    expect(find.text('0 PDF'), findsOneWidget);

    await tester.tap(find.text('Új eset'));
    await tester.pumpAndSettle();

    expect(find.text('Jegyzetek'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('case-notes-field')), 'ABCDE');
    await tester.pumpAndSettle();

    expect((await repository.listCases()).single.notes, 'ABCDE');
  });

  testWidgets('case detail links chats and PDFs instead of placeholder rows', (
    tester,
  ) async {
    final repository = MemoryCaseRepository(
      clock: () => DateTime.utc(2026, 6, 13, 10),
    );
    final created = await repository.createCase(title: 'Trauma eset');
    await repository.linkChat(created.id, 'chat-existing');
    await repository.linkDocument(created.id, 'doc-existing');

    await tester.pumpWidget(
      MaterialApp(home: CasesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trauma eset'));
    await tester.pumpAndSettle();

    expect(find.text('chat-existing'), findsOneWidget);
    expect(find.text('doc-existing'), findsOneWidget);
    expect(find.textContaining('Később'), findsNothing);

    await tester.tap(find.byKey(const Key('add-case-chat-link')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('case-link-id-field')),
      'chat-new',
    );
    await tester.tap(find.text('Hozzáadás'));
    await tester.pumpAndSettle();

    expect(find.text('chat-new'), findsOneWidget);
    expect(await repository.listLinkedChats(created.id), [
      'chat-existing',
      'chat-new',
    ]);
  });
}
