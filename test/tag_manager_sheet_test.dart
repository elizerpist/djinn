import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/data/tag_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/tag_manager_sheet.dart';

void main() {
  testWidgets('folder trigger uses inline editor without framework errors', (
    tester,
  ) async {
    final repository = MemoryTagRepository();
    await _pumpHost(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('open-tag-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-folder-add')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tag-folder-create-mode')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'Resp',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Resp'), findsOneWidget);
    expect(await repository.listFolders(), hasLength(1));
    expect((await repository.listFolders()).single.label, 'Resp');
  });

  testWidgets('empty tag sheet is content-adaptive instead of max height', (
    tester,
  ) async {
    await _pumpHost(tester, repository: MemoryTagRepository());

    await tester.tap(find.byKey(const ValueKey('open-tag-sheet')));
    await tester.pumpAndSettle();

    final sheetHeight = tester
        .getSize(find.byKey(const ValueKey('tag-manager-sheet')))
        .height;
    expect(sheetHeight, lessThan(430));
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required TagRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-tag-sheet'),
            onPressed: () {
              showTagManagerSheet(
                context,
                initialTags: const <NoteKnowledgeTag>[],
                tagRepository: repository,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
