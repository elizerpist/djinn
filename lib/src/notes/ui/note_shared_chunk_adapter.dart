import '../../shared/chunks/shared_chunk.dart';
import '../models/note_document.dart';

SharedChunkViewModel sharedChunkFromNoteBlock({
  required String noteId,
  required String noteTitle,
  required NoteBlock block,
}) {
  final content = block.displayTextForIndexing.trimRight();
  final title = block.title?.trim().isNotEmpty == true
      ? block.title!.trim()
      : _titleFor(block.type);
  return SharedChunkViewModel(
    id: '$noteId:${block.id}',
    origin: SharedChunkOrigin.note,
    kind: sharedKindFromNoteBlockType(block.type),
    title: title,
    preview: content,
    content: content,
    tags: block.tags,
    indexFresh: block.isIndexFresh,
    needsReindex: block.needsReindex,
  );
}

String _titleFor(NoteBlockType type) {
  return switch (type) {
    NoteBlockType.heading => 'Címsor chunk',
    NoteBlockType.paragraph => 'Szöveg chunk',
    NoteBlockType.mixed => 'Szöveg chunk',
    NoteBlockType.listItem => 'Lista chunk',
    NoteBlockType.table => 'Táblázat chunk',
    NoteBlockType.flowchart => 'Flowchart chunk',
  };
}
