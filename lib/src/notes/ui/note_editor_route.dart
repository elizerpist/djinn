import 'dart:async' show FutureOr;
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../../chunks/models/chunk.dart';
import '../../debug/debug_console.dart';
import '../../knowledge/models/chunk_package.dart';
import '../../shared/chunks/chunk_export_sheet.dart';
import '../../shared/chunks/shared_chunk_drag_handle.dart';
import '../data/note_repository.dart';
import '../data/tag_repository.dart';
import '../models/note_document.dart';
import '../models/note_item.dart';
import '../pdf/note_pdf_export_models.dart';
import '../pdf/note_pdf_export_service.dart';
import 'note_chunk_card.dart';
import 'note_chunk_fab.dart';
import 'note_flowchart_editor_screen.dart';
import 'note_mixed_text_chunk_editor_screen.dart';
import 'note_pdf_preview_screen.dart';
import 'tag_manager_sheet.dart';

typedef NoteEditorPdfPreviewOpener =
    FutureOr<void> Function(
      BuildContext context,
      NotePdfPreviewFile file,
      NotePdfExportService service,
      WidgetBuilder? viewerBuilder,
    );
typedef NoteEditorChunkExportSaver =
    FutureOr<String?> Function(ChunkPackage package);

class NoteEditorRoute extends StatefulWidget {
  const NoteEditorRoute({
    super.key,
    required this.repository,
    required this.initialNote,
    this.tagRepository,
    this.pdfExportService,
    this.pdfPreviewViewerBuilder,
    this.pdfPreviewOpener,
    this.chunkExportSaver,
    this.useRootNavigatorForChunkEditors = false,
  });

  final NoteRepository repository;
  final NoteItem initialNote;
  final TagRepository? tagRepository;
  final NotePdfExportService? pdfExportService;
  final WidgetBuilder? pdfPreviewViewerBuilder;
  final NoteEditorPdfPreviewOpener? pdfPreviewOpener;
  final NoteEditorChunkExportSaver? chunkExportSaver;
  final bool useRootNavigatorForChunkEditors;

  @override
  State<NoteEditorRoute> createState() => _NoteEditorRouteState();
}

class _NoteEditorRouteState extends State<NoteEditorRoute> {
  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();
  NotePdfExportService get _pdfExportService =>
      widget.pdfExportService ?? const NotePdfExportService();
  late NoteItem _note;
  late NoteDocument _document;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  final Set<String> _expandedBlockIds = <String>{};
  bool _editingTitle = false;
  bool _persisting = false;
  bool _persistAgain = false;
  int _documentRevision = 0;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
    _document = _note.document;
    _titleController = TextEditingController(text: _note.title);
    _titleFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (_persisting) {
      _persistAgain = true;
      return;
    }
    _persisting = true;
    try {
      do {
        _persistAgain = false;
        final submittedDocument = _document;
        final submittedRevision = _documentRevision;
        final updated = await widget.repository.updateNoteDocument(
          _note.id,
          title: _normalizedTitle,
          document: submittedDocument,
        );
        if (!mounted) {
          return;
        }
        final canonicalIds = _canonicalBlockIdMap(
          submittedDocument,
          updated.document,
        );
        setState(() {
          _note = updated;
          _document = submittedRevision == _documentRevision
              ? updated.document
              : _remapBlockIds(_document, canonicalIds);
          if (canonicalIds.isNotEmpty) {
            final remappedExpandedIds = {
              for (final id in _expandedBlockIds) canonicalIds[id] ?? id,
            };
            _expandedBlockIds
              ..clear()
              ..addAll(remappedExpandedIds);
          }
        });
      } while (_persistAgain);
    } finally {
      _persisting = false;
    }
  }

  String get _normalizedTitle {
    final trimmed = _titleController.text.trim();
    return trimmed.isEmpty ? 'Névtelen jegyzet' : trimmed;
  }

  void _setDocument(NoteDocument document) {
    setState(() {
      _document = document;
      _documentRevision += 1;
    });
    unawaited(_persist());
  }

  Map<String, String> _canonicalBlockIdMap(
    NoteDocument submitted,
    NoteDocument canonical,
  ) {
    final count = submitted.blocks.length < canonical.blocks.length
        ? submitted.blocks.length
        : canonical.blocks.length;
    return {
      for (var index = 0; index < count; index += 1)
        if (submitted.blocks[index].id != canonical.blocks[index].id)
          submitted.blocks[index].id: canonical.blocks[index].id,
    };
  }

  NoteDocument _remapBlockIds(
    NoteDocument document,
    Map<String, String> canonicalIds,
  ) {
    if (canonicalIds.isEmpty) {
      return document;
    }
    return document.copyWith(
      blocks: [
        for (final block in document.blocks)
          block.copyWith(id: canonicalIds[block.id] ?? block.id),
      ],
    );
  }

  void _replaceBlock(NoteBlock block) {
    _setDocument(
      _document.copyWith(
        blocks: [
          for (final existing in _document.blocks)
            if (existing.id == block.id) block else existing,
        ],
      ),
    );
  }

  void _addNoteChunk() {
    final block = _newNoteChunk();
    _setDocument(_document.copyWith(blocks: [..._document.blocks, block]));
    setState(() => _expandedBlockIds.add(block.id));
  }

  void _addFlowchartChunk() {
    final block = _newFlowchartChunk();
    _setDocument(_document.copyWith(blocks: [..._document.blocks, block]));
    setState(() => _expandedBlockIds.add(block.id));
  }

  NoteBlock _newNoteChunk() {
    final id = _newCanonicalChunkId();
    return NoteBlock(
      id: id,
      type: NoteBlockType.mixed,
      mixedSections: const [
        NoteMixedSection(
          id: 'section-1',
          type: NoteMixedSectionType.paragraph,
          text: '',
        ),
      ],
    );
  }

  NoteBlock _newFlowchartChunk() {
    final id = _newCanonicalChunkId();
    return NoteBlock(
      id: id,
      type: NoteBlockType.flowchart,
      title: 'Flowchart',
      nodes: const [
        NoteFlowchartNode(
          id: 'node-1',
          label: 'Kezdés',
          shape: AiFlowchartNodeShape.startEnd,
          order: 1,
        ),
      ],
    );
  }

  String _newCanonicalChunkId() {
    return '${_note.id}:chunk:${DateTime.now().microsecondsSinceEpoch}';
  }

  void _deleteBlock(NoteBlock block) {
    final index = _document.blocks.indexWhere(
      (candidate) => candidate.id == block.id,
    );
    if (index == -1) {
      return;
    }
    final nextBlocks = [..._document.blocks]..removeAt(index);
    setState(() {
      _document = _document.copyWith(blocks: nextBlocks);
      _expandedBlockIds.remove(block.id);
    });
    unawaited(_persist());
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chunk törölve'),
        action: SnackBarAction(
          label: 'Visszavonás',
          onPressed: () => _restoreDeletedBlock(block, index),
        ),
      ),
    );
  }

  void _restoreDeletedBlock(NoteBlock block, int index) {
    final nextBlocks = [..._document.blocks];
    final targetIndex = index.clamp(0, nextBlocks.length).toInt();
    nextBlocks.insert(targetIndex, block);
    setState(() => _document = _document.copyWith(blocks: nextBlocks));
    unawaited(_persist());
  }

  void _reorderBlocks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final nextBlocks = [..._document.blocks];
    final moved = nextBlocks.removeAt(oldIndex);
    nextBlocks.insert(newIndex, moved);
    _setDocument(_document.copyWith(blocks: nextBlocks));
  }

  Future<void> _handleMenu(String value) async {
    if (value == 'index') {
      final ids = _document.blocks
          .where((block) => block.hasContent)
          .map((block) => block.id)
          .toList();
      if (ids.isEmpty) {
        return;
      }
      final updated = await widget.repository.markNoteBlocksIndexed(
        _note.id,
        ids,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _note = updated;
        _document = updated.document;
      });
      return;
    }
    if (value == 'chunks') {
      setState(
        () =>
            _expandedBlockIds.addAll(_document.blocks.map((block) => block.id)),
      );
      return;
    }
    if (value == 'tags') {
      await _showDocumentTagDialog();
      return;
    }
    if (value == 'export-pdf') {
      await _exportCurrentNoteAsPdf();
      return;
    }
    if (value == 'export-chunks') {
      await _exportCurrentNoteChunks();
      return;
    }
    if (value == 'delete') {
      await widget.repository.deleteNotes([_note.id]);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  NoteItem get _currentExportNote {
    return _note.copyWithDocument(title: _normalizedTitle, document: _document);
  }

  Future<void> _exportCurrentNoteAsPdf() async {
    final note = _currentExportNote;
    try {
      final previewFile = await _pdfExportService.createPreviewFileForNotes([
        note,
      ]);
      if (!mounted) {
        return;
      }
      DebugConsole.log(
        '[NotePdfExport] preview open note=${note.id} source=note-editor '
        'path=${previewFile.path}',
      );
      final opener = widget.pdfPreviewOpener ?? _openPdfPreview;
      unawaited(
        Future<void>.sync(
          () => opener(
            context,
            previewFile,
            _pdfExportService,
            widget.pdfPreviewViewerBuilder,
          ),
        ),
      );
    } on NotePdfExportException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      DebugConsole.log(
        '[NotePdfExport] preview failed source=note-editor error=$error',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export sikertelen: $error')));
    }
  }

  Future<void> _exportCurrentNoteChunks() async {
    final canonicalKinds = [
      for (final block in _document.blocks)
        block.type == NoteBlockType.flowchart
            ? ChunkKind.flowchartChunk
            : ChunkKind.noteChunk,
    ];
    final selection = await showChunkExportSheet(
      context,
      chunks: canonicalKinds,
      scopes: const [ChunkExportScope.currentNote],
      initialScope: ChunkExportScope.currentNote,
    );
    if (selection == null || !mounted) {
      return;
    }
    final storedPackage = await widget.repository.exportChunkPackageForNote(
      _note.id,
      includeSourceMetadata: selection.includeSourceMetadata,
    );
    final storedById = {for (final item in storedPackage.chunks) item.id: item};
    final package = ChunkPackage(
      schemaVersion: 2,
      documentHash: storedPackage.documentHash,
      filename: _normalizedTitle,
      provider: storedPackage.provider,
      extractionModel: storedPackage.extractionModel,
      embeddingModel: storedPackage.embeddingModel,
      embeddingDimension: storedPackage.embeddingDimension,
      chunks: [
        for (final block in _document.blocks)
          _packageItemFromNoteBlock(
            block,
            includeSourceMetadata: selection.includeSourceMetadata,
            stored: storedById[block.id],
          ),
      ],
    );
    final saver = widget.chunkExportSaver;
    final path = saver != null
        ? await saver(package)
        : await FilePicker.saveFile(
            dialogTitle: 'Chunk export',
            fileName: '${_safeChunkExportBaseName(_normalizedTitle)}.json',
            type: FileType.custom,
            allowedExtensions: const ['json'],
            bytes: Uint8List.fromList(
              utf8.encode(
                const JsonEncoder.withIndent('  ').convert(package.toJson()),
              ),
            ),
          );
    if (!mounted || path == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${package.chunks.length} chunk exportálva')),
    );
  }

  ChunkPackageItem _packageItemFromNoteBlock(
    NoteBlock block, {
    required bool includeSourceMetadata,
    ChunkPackageItem? stored,
  }) {
    final kind = block.type == NoteBlockType.flowchart
        ? ChunkKind.flowchartChunk
        : ChunkKind.noteChunk;
    final content = kind == ChunkKind.flowchartChunk
        ? block
        : normalizeLegacyNoteBlock(block);
    return ChunkPackageItem(
      id: block.id,
      text: content.plainText,
      pageNumber: includeSourceMetadata ? stored?.pageNumber ?? 0 : 0,
      sectionTitle: content.title,
      embedding: stored?.embedding ?? const [],
      kind: kind,
      creationMethod:
          stored?.creationMethod ?? ChunkCreationMethod.manualSelection,
      validationState: stored?.validationState ?? _note.auditState,
      source: includeSourceMetadata
          ? stored?.source ??
                ChunkSource(
                  sourceType: ChunkSourceType.note,
                  sourceId: _note.id,
                  originalText: block.plainText,
                )
          : const ChunkSource(),
      content: content,
      embeddingRecords: stored?.embeddingRecords ?? const [],
    );
  }

  String _safeChunkExportBaseName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return safe.isEmpty ? 'djinn-note-chunks' : '$safe-chunks';
  }

  Future<void> _openPdfPreview(
    BuildContext context,
    NotePdfPreviewFile file,
    NotePdfExportService service,
    WidgetBuilder? viewerBuilder,
  ) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => NotePdfPreviewScreen(
          file: file,
          exportService: service,
          viewerBuilder: viewerBuilder,
        ),
      ),
    );
  }

  void _startTitleEdit() {
    setState(() => _editingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocusNode.requestFocus();
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
    });
  }

  void _finishTitleEdit() {
    if (!_editingTitle) {
      return;
    }
    setState(() => _editingTitle = false);
    unawaited(_persist());
  }

  Widget _buildHeaderTitle(BuildContext context) {
    if (_editingTitle) {
      return TextField(
        key: const ValueKey('note-editor-title-field'),
        controller: _titleController,
        focusNode: _titleFocusNode,
        autofocus: true,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Jegyzet címe',
        ),
        onChanged: (_) => unawaited(_persist()),
        onSubmitted: (_) => _finishTitleEdit(),
        onTapOutside: (_) => _finishTitleEdit(),
      );
    }
    return InkWell(
      key: const ValueKey('note-editor-title-display'),
      borderRadius: BorderRadius.circular(6),
      onTap: _startTitleEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(
          _normalizedTitle,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _openBlockEditor(NoteBlock block) async {
    final editorBlock = block.type == NoteBlockType.flowchart
        ? block
        : normalizeLegacyNoteBlock(block);
    final availableTags = _document.knownTags;
    DebugConsole.log(
      '[NoteEditor] open chunk type=${block.type.wireName} '
      'blocks=${_document.blocks.length} knownTags=${availableTags.length}',
    );
    Widget editorFor(NoteBlock current) {
      if (current.type != NoteBlockType.flowchart) {
        return NoteMixedTextChunkEditorScreen(
          block: current,
          availableTags: availableTags,
          tagRepository: _tagRepository,
          onChanged: _replaceBlock,
          onDelete: () => _deleteBlock(current),
        );
      }
      return NoteFlowchartEditorScreen(
        block: current,
        availableTags: availableTags,
        tagRepository: _tagRepository,
        onChanged: _replaceBlock,
        onDelete: () => _deleteBlock(current),
      );
    }

    final result =
        await Navigator.of(
          context,
          rootNavigator: widget.useRootNavigatorForChunkEditors,
        ).push<NoteBlock>(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                editorFor(editorBlock),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
          ),
        );
    if (result != null && mounted) {
      _replaceBlock(result);
    }
  }

  Future<void> _showBlockTagDialog(NoteBlock block) async {
    await showTagManagerSheet(
      context,
      initialTags: block.tags,
      tagRepository: _tagRepository,
      onChanged: (tags) =>
          _replaceBlock(block.copyWith(tags: tags, clearIndex: true)),
      availableTags: _document.knownTags,
      title: 'Chunk tagek',
    );
  }

  Future<void> _showDocumentTagDialog() async {
    await showTagManagerSheet(
      context,
      initialTags: _document.tags,
      tagRepository: _tagRepository,
      onChanged: (tags) => _setDocument(_document.copyWith(tags: tags)),
      availableTags: _document.knownTags,
      title: 'Jegyzet tagek',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('note-editor-route'),
      appBar: AppBar(
        title: _buildHeaderTitle(context),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('note-editor-menu'),
            tooltip: 'Jegyzet menü',
            onSelected: (value) => unawaited(_handleMenu(value)),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'index',
                child: Text('Indexelés / újraindexelés'),
              ),
              PopupMenuItem(value: 'tags', child: Text('Tagek')),
              PopupMenuItem(value: 'chunks', child: Text('Chunkok kinyitása')),
              PopupMenuItem(
                value: 'export-chunks',
                child: Text('Chunk export (JSON)'),
              ),
              PopupMenuItem(value: 'export-pdf', child: Text('Export as PDF')),
              PopupMenuItem(value: 'delete', child: Text('Törlés')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
              itemCount: _document.blocks.length,
              // ignore: deprecated_member_use
              onReorder: _reorderBlocks,
              itemBuilder: (context, index) {
                final block = _document.blocks[index];
                return Padding(
                  key: ValueKey('note-chunk-row-${block.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NoteChunkCard(
                    block: block,
                    expanded: _expandedBlockIds.contains(block.id),
                    inheritedTags: _document.tags,
                    dragHandle: SharedChunkDragHandle(
                      chunkId: block.id,
                      index: index,
                    ),
                    onToggleExpanded: () {
                      setState(() {
                        if (!_expandedBlockIds.add(block.id)) {
                          _expandedBlockIds.remove(block.id);
                        }
                      });
                    },
                    onOpenEditor: () => unawaited(_openBlockEditor(block)),
                    onEditTags: () => unawaited(_showBlockTagDialog(block)),
                    onDelete: () => _deleteBlock(block),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: NoteChunkFab(
        onAddNoteChunk: _addNoteChunk,
        onAddFlowchart: _addFlowchartChunk,
      ),
    );
  }
}

void unawaited(Future<void> future) {}
