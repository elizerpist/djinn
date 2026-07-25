import 'dart:convert';

import 'package:flutter/material.dart';

import '../../chunks/models/chunk.dart';
import '../../notes/data/tag_repository.dart';
import '../../notes/models/note_document.dart';
import '../../notes/ui/note_flowchart_editor_screen.dart';
import '../../notes/ui/note_mixed_text_chunk_editor_screen.dart';
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
    this.tagRepository,
  });

  final KnowledgeDocumentRepository repository;
  final String documentId;
  final ExtractedKnowledgeItem item;
  final TagRepository? tagRepository;

  @override
  State<PdfChunkEditorRoute> createState() => _PdfChunkEditorRouteState();
}

class _PdfChunkEditorRouteState extends State<PdfChunkEditorRoute> {
  late NoteBlock _block = _normalizedBlock(widget.item);
  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();

  NoteBlock _normalizedBlock(ExtractedKnowledgeItem item) {
    final block = noteBlockFromPdfChunk(item);
    return block.type == NoteBlockType.flowchart
        ? block
        : normalizeLegacyNoteBlock(block);
  }

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
      structuredContentJson: jsonEncode(block.toJson()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_block.type == NoteBlockType.flowchart) {
      return NoteFlowchartEditorScreen(
        block: _block,
        tagRepository: _tagRepository,
        onChanged: (block) => unawaited(_handleChanged(block)),
      );
    }
    return NoteMixedTextChunkEditorScreen(
      block: _block,
      tagRepository: _tagRepository,
      onChanged: (block) => unawaited(_handleChanged(block)),
    );
  }
}

void unawaited(Future<void> future) {}
