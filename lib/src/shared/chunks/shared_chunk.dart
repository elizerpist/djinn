import '../../chunks/models/chunk.dart';
import '../../knowledge/models/local_extraction.dart';
import '../../notes/models/note_document.dart';

enum SharedChunkKind { noteChunk, flowchartChunk }

enum SharedChunkOrigin { note, pdf, image }

class SharedChunkViewModel {
  const SharedChunkViewModel({
    required this.id,
    required this.origin,
    required this.kind,
    required this.title,
    required this.preview,
    required this.content,
    required this.tags,
    this.creationMethod,
    this.pageLabel,
    this.sourceRectJson,
    this.auditState,
    this.indexFresh = false,
    this.needsReindex = false,
  });

  final String id;
  final SharedChunkOrigin origin;
  final SharedChunkKind kind;
  final String title;
  final String preview;
  final String content;
  final List<NoteKnowledgeTag> tags;
  final ChunkCreationMethod? creationMethod;
  final String? pageLabel;
  final String? sourceRectJson;
  final LocalAuditState? auditState;
  final bool indexFresh;
  final bool needsReindex;

  bool get hasSourceRect =>
      sourceRectJson != null && sourceRectJson!.trim().isNotEmpty;
}

SharedChunkKind sharedKindFromLocalChunkKind(LocalChunkKind kind) {
  return switch (kind) {
    LocalChunkKind.flowchart => SharedChunkKind.flowchartChunk,
    LocalChunkKind.text ||
    LocalChunkKind.list ||
    LocalChunkKind.table => SharedChunkKind.noteChunk,
  };
}

SharedChunkKind sharedKindFromNoteBlockType(NoteBlockType type) {
  return switch (type) {
    NoteBlockType.flowchart => SharedChunkKind.flowchartChunk,
    NoteBlockType.heading ||
    NoteBlockType.paragraph ||
    NoteBlockType.listItem ||
    NoteBlockType.table ||
    NoteBlockType.mixed => SharedChunkKind.noteChunk,
  };
}
