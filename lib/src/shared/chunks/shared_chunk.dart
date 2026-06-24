import '../../knowledge/models/local_extraction.dart';
import '../../notes/models/note_document.dart';

enum SharedChunkKind { text, list, table, flowchart }

enum SharedChunkOrigin { note, pdf, image }

enum SharedChunkMode { ai, manual }

class SharedChunkViewModel {
  const SharedChunkViewModel({
    required this.id,
    required this.origin,
    required this.kind,
    required this.title,
    required this.preview,
    required this.content,
    required this.tags,
    this.mode,
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
  final SharedChunkMode? mode;
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
    LocalChunkKind.text => SharedChunkKind.text,
    LocalChunkKind.list => SharedChunkKind.list,
    LocalChunkKind.table => SharedChunkKind.table,
    LocalChunkKind.flowchart => SharedChunkKind.flowchart,
  };
}

SharedChunkKind sharedKindFromNoteBlockType(NoteBlockType type) {
  return switch (type) {
    NoteBlockType.listItem => SharedChunkKind.list,
    NoteBlockType.table => SharedChunkKind.table,
    NoteBlockType.flowchart => SharedChunkKind.flowchart,
    NoteBlockType.heading || NoteBlockType.paragraph => SharedChunkKind.text,
  };
}
