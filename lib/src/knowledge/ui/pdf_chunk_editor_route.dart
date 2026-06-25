import 'package:flutter/material.dart';

import '../../notes/data/tag_repository.dart';
import '../../notes/models/note_document.dart';
import '../../notes/ui/note_flowchart_editor_screen.dart';
import '../../notes/ui/note_list_chunk_editor_screen.dart';
import '../../notes/ui/note_table_editor_screen.dart';
import '../../notes/ui/note_text_chunk_editor_screen.dart';
import '../data/knowledge_document_repository.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';
import 'pdf_chunk_note_block_adapter.dart';

class PdfChunkEditorRoute extends StatefulWidget {
  const PdfChunkEditorRoute({
    super.key,
    required this.repository,
    required this.documentId,
    required this.item,
  });

  final KnowledgeDocumentRepository repository;
  final String documentId;
  final ExtractedKnowledgeItem item;

  @override
  State<PdfChunkEditorRoute> createState() => _PdfChunkEditorRouteState();
}

class _PdfChunkEditorRouteState extends State<PdfChunkEditorRoute> {
  late NoteBlock _block = noteBlockFromPdfChunk(widget.item);
  final TagRepository _tagRepository = MemoryTagRepository();

  Future<void> _handleChanged(NoteBlock block) async {
    setState(() => _block = block);
    await widget.repository.updateExtractedKnowledgeItem(
      widget.documentId,
      widget.item.id,
      text: pdfChunkTextFromNoteBlock(block),
      sectionTitle: block.title,
      chunkKind: localChunkKindFromNoteBlock(block),
      auditState: LocalAuditState.edited,
      tags: block.tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_block.type) {
      NoteBlockType.listItem => NoteListChunkEditorScreen(
        block: _block,
        tagRepository: _tagRepository,
        onChanged: (block) => unawaited(_handleChanged(block)),
      ),
      NoteBlockType.table => NoteTableEditorScreen(
        block: _block,
        tagRepository: _tagRepository,
        onChanged: (block) => unawaited(_handleChanged(block)),
      ),
      NoteBlockType.flowchart => NoteFlowchartEditorScreen(
        block: _block,
        tagRepository: _tagRepository,
        onChanged: (block) => unawaited(_handleChanged(block)),
      ),
      NoteBlockType.heading ||
      NoteBlockType.paragraph => NoteTextChunkEditorScreen(
        block: _block,
        tagRepository: _tagRepository,
        onChanged: (block) => unawaited(_handleChanged(block)),
      ),
    };
  }
}

void unawaited(Future<void> future) {}
