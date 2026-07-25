import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test(
    'one global chunk can be linked idempotently to multiple notes',
    () async {
      final repository = MemoryNoteRepository();
      final first = await repository.createDocumentNote(
        title: 'Első jegyzet',
        document: NoteDocument.empty(),
      );
      final second = await repository.createDocumentNote(
        title: 'Második jegyzet',
        document: NoteDocument.empty(),
      );

      final firstResult = await repository.linkChunksToNote(first.id, const [
        'pdf-1:chunk-1',
        'pdf-1:chunk-2',
        'pdf-1:chunk-1',
      ]);
      final repeatedResult = await repository.linkChunksToNote(first.id, const [
        'pdf-1:chunk-1',
      ]);
      await repository.linkChunksToNote(second.id, const ['pdf-1:chunk-1']);

      expect(firstResult.addedCount, 2);
      expect(firstResult.alreadyLinkedCount, 1);
      expect(repeatedResult.addedCount, 0);
      expect(repeatedResult.alreadyLinkedCount, 1);
      expect(await repository.listLinkedChunkIds(first.id), {
        'pdf-1:chunk-1',
        'pdf-1:chunk-2',
      });
      expect(await repository.listLinkedChunkIds(second.id), {'pdf-1:chunk-1'});
    },
  );

  test(
    'linking chunks rejects a missing note instead of creating an orphan',
    () {
      final repository = MemoryNoteRepository();

      expect(
        () => repository.linkChunksToNote('missing', const ['pdf-1:chunk-1']),
        throwsStateError,
      );
    },
  );
}
