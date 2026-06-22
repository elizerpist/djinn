import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/data/tag_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('memory repository reuses duplicate labels and updates color slot', () async {
    final repository = MemoryTagRepository(
      clock: () => DateTime.utc(2026, 6, 22, 12),
    );

    final first = await repository.upsertTag(
      label: ' Légzés ',
      colorSlotId: 1,
    );
    final duplicate = await repository.upsertTag(
      label: 'légzés',
      colorSlotId: 3,
    );

    expect(duplicate.id, first.id);
    expect(duplicate.label, 'légzés');
    expect(duplicate.colorSlotId, 3);
    expect(await repository.listTags(), hasLength(1));
  });

  test('memory repository resolves edited labels to existing visible tag', () async {
    final repository = MemoryTagRepository(
      clock: () => DateTime.utc(2026, 6, 22, 12),
    );

    final first = await repository.upsertTag(label: 'Shock', colorSlotId: 1);
    final second = await repository.upsertTag(label: 'Sepsis', colorSlotId: 2);
    final edited = await repository.upsertTag(
      id: first.id,
      label: 'sepsis',
      colorSlotId: 3,
    );

    expect(edited.id, second.id);
    expect(edited.label, 'sepsis');
    expect(edited.colorSlotId, 3);
    expect(await repository.listTags(), hasLength(2));
  });

  test('memory repository creates folders and clears tag folder assignment', () async {
    final repository = MemoryTagRepository(
      clock: () => DateTime.utc(2026, 6, 22, 12),
    );
    final folder = await repository.createFolder(' Respiráció ');
    final tag = await repository.upsertTag(
      label: 'High flow',
      colorSlotId: 2,
      folderId: folder.id,
    );

    expect((await repository.listFolders()).single.label, 'Respiráció');
    expect(tag.folderId, folder.id);

    final cleared = await repository.setTagFolder(tag.id, null);

    expect(cleared.folderId, isNull);
  });

  test('memory repository seeds embedded legacy tags as registry assignments', () async {
    final repository = MemoryTagRepository(
      clock: () => DateTime.utc(2026, 6, 22, 12),
    );

    final remembered = await repository.rememberEmbeddedTags(const [
      NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'Légzés',
        colorValue: 0xFFDC2626,
      ),
    ]);

    expect(remembered, hasLength(1));
    expect(remembered.single.id, isNotNull);
    expect(remembered.single.type, NoteKnowledgeTagTypes.custom);
    expect(remembered.single.label, 'Légzés');
    expect(remembered.single.colorSlotId, 4);
    expect(remembered.single.resolvedColorValue, 0xFFDC2626);
    expect(await repository.listTags(), hasLength(1));
  });
}
