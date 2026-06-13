import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/cases/data/case_repository.dart';

void main() {
  test('memory case repository creates updates and links a case', () async {
    final repository = MemoryCaseRepository(
      clock: () => DateTime.utc(2026, 6, 13, 10),
    );

    final created = await repository.createCase(title: 'Új eset');

    expect(created.title, 'Új eset');
    expect((await repository.listCases()).single.title, 'Új eset');

    final updated = await repository.updateNotes(
      created.id,
      'ABCDE megfigyelés',
    );
    await repository.linkChat(created.id, 'chat-1');
    await repository.linkDocument(created.id, 'doc-1');

    final listed = (await repository.listCases()).single;
    expect(updated.notes, 'ABCDE megfigyelés');
    expect(listed.notes, 'ABCDE megfigyelés');
    expect(listed.linkedChatCount, 1);
    expect(listed.linkedDocumentCount, 1);
    expect(await repository.listLinkedChats(created.id), ['chat-1']);
    expect(await repository.listLinkedDocuments(created.id), ['doc-1']);
    expect(listed.updatedAt, DateTime.utc(2026, 6, 13, 10));
  });
}
