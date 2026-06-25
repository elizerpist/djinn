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
    this.searchText = '',
    this.isIndexFresh = false,
    this.needsReindex = false,
  });

  final String id;
  final String noteId;
  final String noteTitle;
  final String blockId;
  final NoteChunkKind kind;
  final String text;
  final String groupId;
  final String searchText;
  final bool isIndexFresh;
  final bool needsReindex;
}

class NoteChunkBuilder {
  const NoteChunkBuilder();

  List<NoteChunkViewModel> build({
    required String noteId,
    required String noteTitle,
    required NoteDocument document,
  }) {
    final chunks = <NoteChunkViewModel>[];
    final documentSearchText = document.searchMetadataText;
    for (final block in document.blocks) {
      if (NoteSearchRoles.normalize(block.searchRole) ==
          NoteSearchRoles.ignore) {
        continue;
      }
      final text = block.displayTextForIndexing.trimRight();
      if (text.trim().isEmpty) {
        continue;
      }
      chunks.add(
        NoteChunkViewModel(
          id: '$noteId:${block.id}',
          noteId: noteId,
          noteTitle: noteTitle,
          blockId: block.id,
          kind: _kindFor(block.type),
          text: text,
          groupId: noteId,
          searchText: _joinSearchText([
            documentSearchText,
            block.searchMetadataText,
          ]),
          isIndexFresh: block.isIndexFresh,
          needsReindex: block.needsReindex,
        ),
      );
    }
    return List.unmodifiable(chunks);
  }

  NoteChunkKind _kindFor(NoteBlockType type) {
    return switch (type) {
      NoteBlockType.listItem => NoteChunkKind.list,
      NoteBlockType.table => NoteChunkKind.table,
      NoteBlockType.flowchart => NoteChunkKind.flowchart,
      NoteBlockType.heading ||
      NoteBlockType.paragraph ||
      NoteBlockType.mixed => NoteChunkKind.text,
    };
  }

  String _joinSearchText(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join('\n')
        .trim();
  }
}
