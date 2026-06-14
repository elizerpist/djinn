import '../models/note_document.dart';

enum NoteChunkKind { text, list, table, flowchart }

class NoteChunkViewModel {
  const NoteChunkViewModel({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.blockId,
    required this.kind,
    required this.text,
    required this.groupId,
  });

  final String id;
  final String noteId;
  final String noteTitle;
  final String blockId;
  final NoteChunkKind kind;
  final String text;
  final String groupId;
}

class NoteChunkBuilder {
  const NoteChunkBuilder();

  List<NoteChunkViewModel> build({
    required String noteId,
    required String noteTitle,
    required NoteDocument document,
  }) {
    final chunks = <NoteChunkViewModel>[];
    var pendingText = <NoteBlock>[];
    NoteChunkKind? pendingTextKind;

    void flushText() {
      if (pendingText.isEmpty) {
        return;
      }
      final first = pendingText.first;
      final text = pendingText
          .map((block) => block.plainText)
          .where((value) => value.trim().isNotEmpty)
          .join('\n')
          .trim();
      if (text.isNotEmpty) {
        chunks.add(
          NoteChunkViewModel(
            id: '$noteId:${first.id}',
            noteId: noteId,
            noteTitle: noteTitle,
            blockId: first.id,
            kind: pendingTextKind ?? NoteChunkKind.text,
            text: text,
            groupId: noteId,
          ),
        );
      }
      pendingText = <NoteBlock>[];
      pendingTextKind = null;
    }

    void appendTextBlock(NoteBlock block) {
      final kind = block.type == NoteBlockType.listItem
          ? NoteChunkKind.list
          : NoteChunkKind.text;
      if (pendingTextKind != null && pendingTextKind != kind) {
        flushText();
      }
      pendingTextKind = kind;
      pendingText.add(block);
    }

    for (final block in document.blocks) {
      switch (block.type) {
        case NoteBlockType.heading:
        case NoteBlockType.paragraph:
        case NoteBlockType.listItem:
          appendTextBlock(block);
        case NoteBlockType.table:
          flushText();
          final text = block.plainText;
          if (text.trim().isNotEmpty) {
            chunks.add(
              NoteChunkViewModel(
                id: '$noteId:${block.id}',
                noteId: noteId,
                noteTitle: noteTitle,
                blockId: block.id,
                kind: NoteChunkKind.table,
                text: text,
                groupId: noteId,
              ),
            );
          }
        case NoteBlockType.flowchart:
          flushText();
          final text = block.plainText;
          if (text.trim().isNotEmpty) {
            chunks.add(
              NoteChunkViewModel(
                id: '$noteId:${block.id}',
                noteId: noteId,
                noteTitle: noteTitle,
                blockId: block.id,
                kind: NoteChunkKind.flowchart,
                text: text,
                groupId: noteId,
              ),
            );
          }
      }
    }
    flushText();
    return List.unmodifiable(chunks);
  }
}
