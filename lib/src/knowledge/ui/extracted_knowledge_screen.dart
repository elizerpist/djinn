import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../chunks/models/chunk.dart';
import '../../debug/debug_console.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/data/tag_repository.dart';
import '../../notes/models/note_item.dart';
import '../../notes/ui/note_chunk_card.dart';
import '../data/knowledge_document_repository.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/flowchart_hierarchy.dart';
import '../models/knowledge_document.dart';
import '../models/local_extraction.dart';
import '../../flowchart/ui/mobile_flowchart_viewer.dart';
import '../../shared/chunks/shared_chunk_card.dart';
import '../../shared/chunks/shared_chunk_drag_handle.dart';
import '../../shared/chunks/chunk_export_sheet.dart';
import '../../notes/ui/tag_manager_sheet.dart';
import '../models/chunk_package.dart';
import 'pdf_chunk_editor_route.dart';
import 'pdf_chunk_note_block_adapter.dart';
import 'pdf_shared_chunk_adapter.dart';

class ExtractedKnowledgeScreen extends StatefulWidget {
  const ExtractedKnowledgeScreen({
    super.key,
    required this.repository,
    required this.document,
    this.noteRepository,
    this.tagRepository,
    this.chunkExportSaver,
  });

  final KnowledgeDocumentRepository repository;
  final KnowledgeDocument document;
  final NoteRepository? noteRepository;
  final TagRepository? tagRepository;
  final Future<String?> Function(ChunkPackage package)? chunkExportSaver;

  @override
  State<ExtractedKnowledgeScreen> createState() =>
      _ExtractedKnowledgeScreenState();
}

class _ExtractedKnowledgeScreenState extends State<ExtractedKnowledgeScreen> {
  late Future<List<ExtractedKnowledgeItem>> _dataFuture;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<List<ExtractedKnowledgeItem>> _loadData() async {
    final items = await widget.repository.listExtractedKnowledgeItems(
      widget.document.id,
    );
    final hydratedItems = await _hydrateCreationMethods(items);
    DebugConsole.log(
      '[PDFChunks] load document=${widget.document.id} '
      'items=${hydratedItems.length}',
    );
    return hydratedItems;
  }

  Future<List<ExtractedKnowledgeItem>> _hydrateCreationMethods(
    List<ExtractedKnowledgeItem> items,
  ) async {
    if (items.isEmpty) {
      return items;
    }
    try {
      final package = await widget.repository.exportChunkPackage(
        widget.document.id,
      );
      final creationMethodById = {
        for (final chunk in package.chunks) chunk.id: chunk.creationMethod,
      };
      return [
        for (final item in items)
          item.copyWith(creationMethod: creationMethodById[item.id]),
      ];
    } catch (error) {
      DebugConsole.log(
        '[PDFChunks] provenance unavailable document=${widget.document.id} '
        'error=$error',
      );
      return items;
    }
  }

  void _reloadData() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _openTagSheet(ExtractedKnowledgeItem item) async {
    final block = noteBlockFromPdfChunk(item);
    final tags = await showTagManagerSheet(
      context,
      initialTags: block.tags,
      availableTags: block.knownTags,
      tagRepository: widget.tagRepository,
      title: 'Chunk tagjei',
    );
    if (tags == null) {
      return;
    }
    await widget.repository.updateExtractedKnowledgeTags(
      widget.document.id,
      item.id,
      tags,
    );
    _reloadData();
  }

  Future<void> _openPdfChunkEditor(ExtractedKnowledgeItem item) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => PdfChunkEditorRoute(
          repository: widget.repository,
          documentId: widget.document.id,
          item: item,
          tagRepository: widget.tagRepository,
        ),
      ),
    );
    _reloadData();
  }

  Future<void> _reorderPdfChunks(List<String> orderedIds) async {
    await widget.repository.reorderExtractedKnowledgeItems(
      widget.document.id,
      orderedIds,
    );
    if (!mounted) {
      return;
    }
    _reloadData();
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (!_selectedIds.add(itemId)) {
        _selectedIds.remove(itemId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) {
      return;
    }
    setState(_selectedIds.clear);
  }

  String _globalChunkId(String itemId) {
    final prefix = '${widget.document.id}:';
    return itemId.startsWith(prefix) ? itemId : '$prefix$itemId';
  }

  Future<void> _sendSelectedToNote(List<ExtractedKnowledgeItem> items) async {
    final repository = widget.noteRepository;
    if (repository == null || _selectedIds.isEmpty) {
      return;
    }
    final notes = await repository.listNotes(type: NoteItemType.document);
    if (!mounted) {
      return;
    }
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Előbb hozz létre egy Jegyzetet')),
      );
      return;
    }
    final note = await showDialog<NoteItem>(
      context: context,
      builder: (context) => _SendToNoteDialog(notes: notes),
    );
    if (note == null) {
      return;
    }
    final selectedItemIds = {
      for (final item in items)
        if (_selectedIds.contains(item.id)) _globalChunkId(item.id),
    };
    final result = await repository.linkChunksToNote(note.id, selectedItemIds);
    if (!mounted) {
      return;
    }
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.addedCount == 0
              ? 'A kijelölt chunkok már a Jegyzetben vannak'
              : '${result.addedCount} chunk bekerült: ${note.title}',
        ),
      ),
    );
  }

  Future<void> _exportChunks(List<ExtractedKnowledgeItem> items) async {
    final selectedItems = _selectedIds.isEmpty
        ? items
        : items
              .where((item) => _selectedIds.contains(item.id))
              .toList(growable: false);
    final scope = switch (_selectedIds.length) {
      0 => ChunkExportScope.currentPdf,
      1 => ChunkExportScope.currentChunk,
      _ => ChunkExportScope.selectedChunks,
    };
    final selection = await showChunkExportSheet(
      context,
      chunks: [
        for (final item in selectedItems)
          item.chunkKind == LocalChunkKind.flowchart
              ? ChunkKind.flowchartChunk
              : ChunkKind.noteChunk,
      ],
      scopes: [scope],
      initialScope: scope,
    );
    if (selection == null || !mounted) {
      return;
    }
    final complete = await widget.repository.exportChunkPackage(
      widget.document.id,
    );
    final selectedIds = selectedItems.map((item) => item.id).toSet();
    final exportsSubset =
        selection.scope == ChunkExportScope.currentChunk ||
        selection.scope == ChunkExportScope.selectedChunks;
    final scopedChunks = exportsSubset
        ? complete.chunks
              .where((chunk) => selectedIds.contains(chunk.id))
              .toList(growable: false)
        : complete.chunks;
    final exportPackage = ChunkPackage(
      schemaVersion: 2,
      documentHash: complete.documentHash,
      filename: complete.filename,
      provider: complete.provider,
      extractionModel: complete.extractionModel,
      embeddingModel: complete.embeddingModel,
      embeddingDimension: complete.embeddingDimension,
      chunks: [
        for (final chunk in scopedChunks)
          selection.includeSourceMetadata
              ? chunk
              : chunk.copyWith(pageNumber: 0, source: const ChunkSource()),
      ],
    );
    final saver = widget.chunkExportSaver;
    final path = saver != null
        ? await saver(exportPackage)
        : await FilePicker.saveFile(
            dialogTitle: 'Chunk export',
            fileName: '${_safeExportBaseName(widget.document.filename)}.json',
            type: FileType.custom,
            allowedExtensions: const ['json'],
            bytes: Uint8List.fromList(
              utf8.encode(
                const JsonEncoder.withIndent(
                  '  ',
                ).convert(exportPackage.toJson()),
              ),
            ),
          );
    if (!mounted || path == null) {
      return;
    }
    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${exportPackage.chunks.length} chunk exportálva'),
      ),
    );
  }

  String _safeExportBaseName(String filename) {
    final withoutExtension = filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final safe = withoutExtension
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return safe.isEmpty ? 'djinn-chunks' : '$safe-chunks';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectedIds.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('pdf-chunk-selection-close'),
                tooltip: 'Kijelölés megszüntetése',
                onPressed: _clearSelection,
                icon: const Icon(Icons.close),
              ),
        title: Text(
          _selectedIds.isEmpty
              ? 'PDF chunkok'
              : '${_selectedIds.length} kijelölve',
        ),
        actions: [
          if (_selectedIds.isEmpty)
            IconButton(
              key: const ValueKey('pdf-chunk-export-action'),
              tooltip: 'Chunk export',
              onPressed: () => unawaited(_dataFuture.then(_exportChunks)),
              icon: const Icon(Icons.ios_share_outlined),
            ),
          if (_selectedIds.isNotEmpty)
            PopupMenuButton<_PdfSelectionAction>(
              key: const ValueKey('pdf-chunk-selection-menu'),
              tooltip: 'Kijelölt chunkok műveletei',
              onSelected: (value) {
                if (value == _PdfSelectionAction.sendToNote) {
                  unawaited(_dataFuture.then(_sendSelectedToNote));
                } else if (value == _PdfSelectionAction.export) {
                  unawaited(_dataFuture.then(_exportChunks));
                }
              },
              itemBuilder: (context) => [
                if (widget.noteRepository != null)
                  const PopupMenuItem(
                    value: _PdfSelectionAction.sendToNote,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.drive_file_move_outline),
                      title: Text('Jegyzetbe küldés'),
                    ),
                  ),
                const PopupMenuItem(
                  value: _PdfSelectionAction.export,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.ios_share_outlined),
                    title: Text('Chunk export'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<List<ExtractedKnowledgeItem>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data;
          if (items == null || items.isEmpty) {
            return _EmptyExtractedKnowledge(filename: widget.document.filename);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _DocumentSummary(
                  filename: widget.document.filename,
                  count: items.length,
                ),
              ),
              Expanded(
                child: _ExtractedKnowledgeList(
                  items: items,
                  selectedIds: _selectedIds,
                  onOpenEditor: _openPdfChunkEditor,
                  onTag: _openTagSheet,
                  onToggleSelection: _toggleSelection,
                  onReorder: (ids) {
                    _reorderPdfChunks(ids);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _PdfSelectionAction { sendToNote, export }

class _SendToNoteDialog extends StatelessWidget {
  const _SendToNoteDialog({required this.notes});

  final List<NoteItem> notes;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('send-chunks-to-note-dialog'),
      title: const Text('Jegyzetbe küldés'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: notes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notes[index];
              return ListTile(
                key: ValueKey('send-chunks-to-note-${note.id}'),
                leading: const Icon(Icons.note_outlined),
                title: Text(note.title),
                subtitle: Text(
                  '${note.document.blocks.length} chunk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(note),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
      ],
    );
  }
}

class _DocumentSummary extends StatelessWidget {
  const _DocumentSummary({required this.filename, required this.count});

  final String filename;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          filename,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count kinyert elem',
          style: theme.textTheme.bodySmall?.copyWith(
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _ExtractedKnowledgeList extends StatefulWidget {
  const _ExtractedKnowledgeList({
    required this.items,
    required this.selectedIds,
    required this.onOpenEditor,
    required this.onTag,
    required this.onToggleSelection,
    required this.onReorder,
  });

  final List<ExtractedKnowledgeItem> items;
  final Set<String> selectedIds;
  final ValueChanged<ExtractedKnowledgeItem> onOpenEditor;
  final ValueChanged<ExtractedKnowledgeItem> onTag;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<List<String>> onReorder;

  @override
  State<_ExtractedKnowledgeList> createState() =>
      _ExtractedKnowledgeListState();
}

class _ExtractedKnowledgeListState extends State<_ExtractedKnowledgeList> {
  final Set<String> _expandedIds = {};
  late List<ExtractedKnowledgeItem> _orderedItems = List.of(widget.items);

  @override
  void didUpdateWidget(covariant _ExtractedKnowledgeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = _orderedItems.map((item) => item.id).join('|');
    final newIds = widget.items.map((item) => item.id).join('|');
    if (oldIds != newIds) {
      _orderedItems = List.of(widget.items);
      return;
    }
    final incomingById = {for (final item in widget.items) item.id: item};
    _orderedItems = [
      for (final item in _orderedItems) incomingById[item.id] ?? item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text(
          'Nincs ilyen típusú kinyert tartalom',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _orderedItems.length,
      // ignore: deprecated_member_use
      onReorder: _reorder,
      itemBuilder: (context, index) {
        final item = _orderedItems[index];
        return Padding(
          key: ValueKey('pdf-chunk-row-${item.id}'),
          padding: const EdgeInsets.only(bottom: 8),
          child: _ExtractedKnowledgeTile(
            item: item,
            leading: widget.selectedIds.isEmpty
                ? SharedChunkDragHandle(chunkId: item.id, index: index)
                : Icon(
                    widget.selectedIds.contains(item.id)
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: widget.selectedIds.contains(item.id)
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                  ),
            selected: widget.selectedIds.contains(item.id),
            expanded: _expandedIds.contains(item.id),
            onToggleExpanded: () {
              setState(() {
                if (!_expandedIds.add(item.id)) {
                  _expandedIds.remove(item.id);
                }
              });
            },
            onOpenEditor: () {
              if (widget.selectedIds.isNotEmpty) {
                widget.onToggleSelection(item.id);
                return;
              }
              widget.onOpenEditor(item);
            },
            onLongPress: () => widget.onToggleSelection(item.id),
            onTag: () => widget.onTag(item),
          ),
        );
      },
    );
  }

  void _reorder(int oldIndex, int newIndex) {
    if (oldIndex >= _orderedItems.length || newIndex > _orderedItems.length) {
      return;
    }
    final updated = List<ExtractedKnowledgeItem>.of(_orderedItems);
    final item = updated.removeAt(oldIndex);
    final insertIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    updated.insert(insertIndex, item);
    setState(() => _orderedItems = updated);
    widget.onReorder([for (final item in updated) item.id]);
  }
}

class _FlowchartHierarchyList extends StatefulWidget {
  const _FlowchartHierarchyList({
    required this.items,
    required this.onEditFlowchart,
  });

  final List<ExtractedKnowledgeItem> items;
  final ValueChanged<String> onEditFlowchart;

  @override
  State<_FlowchartHierarchyList> createState() =>
      _FlowchartHierarchyListState();
}

class _FlowchartHierarchyListState extends State<_FlowchartHierarchyList> {
  final Map<String, String> _renamedTitles = {};

  Future<void> _renameGroup(FlowchartHierarchyGroup group) async {
    final controller = TextEditingController(
      text: _renamedTitles[group.id] ?? group.title,
    );
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flowchart átnevezése'),
        content: TextField(
          key: const ValueKey('flowchart-title-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Flowchart neve',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }
    setState(() => _renamedTitles[group.id] = trimmed);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(
        child: Text(
          'Nincs ilyen típusú kinyert tartalom',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    final groups = const FlowchartHierarchyBuilder().build(widget.items);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _FlowchartGroupCard(
          group: group,
          title: _renamedTitles[group.id] ?? group.title,
          onRename: () => _renameGroup(group),
          onEdit: () => widget.onEditFlowchart(group.id),
        );
      },
    );
  }
}

class _FlowchartGroupCard extends StatelessWidget {
  const _FlowchartGroupCard({
    required this.group,
    required this.title,
    required this.onRename,
    required this.onEdit,
  });

  final FlowchartHierarchyGroup group;
  final String title;
  final VoidCallback onRename;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final data = _mobileFlowchartDataFromGroup(group, title: title);
    return Material(
      key: ValueKey('flowchart-group-${group.id}'),
      color: const Color(0xFFFAF5FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE9D5FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('flowchart-edit-${group.id}'),
                  tooltip: 'Flowchart szerkesztése',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                ),
                IconButton(
                  key: ValueKey('flowchart-rename-${group.id}'),
                  tooltip: 'Flowchart átnevezése',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                Text(
                  '${data.nodes.length} lépés',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MobileFlowchartViewer(data: data),
          ],
        ),
      ),
    );
  }
}

MobileFlowchartData _mobileFlowchartDataFromGroup(
  FlowchartHierarchyGroup group, {
  required String title,
}) {
  final nodeMap = <String, MobileFlowchartNode>{};
  final edges = <MobileFlowchartEdge>[];
  for (final row in group.rows) {
    final item = row.item;
    if (row.isEdge) {
      final from = item.flowchartFromId;
      final to = item.flowchartToId;
      if (from == null || from.isEmpty || to == null || to.isEmpty) {
        continue;
      }
      edges.add(
        MobileFlowchartEdge(
          id: item.id,
          fromNodeId: from,
          toNodeId: to,
          label: item.flowchartEdgeLabel?.trim().isNotEmpty == true
              ? item.flowchartEdgeLabel!.trim()
              : item.text.trim(),
        ),
      );
    } else {
      final id = item.flowchartElementId ?? item.id;
      nodeMap[id] = MobileFlowchartNode(
        id: id,
        label: item.text,
        shape: item.flowchartShape ?? 'process',
      );
    }
  }
  return MobileFlowchartData(
    id: group.id,
    title: title,
    sourceSummary: '${nodeMap.length} lépés',
    nodes: nodeMap.values.toList(growable: false),
    edges: edges,
  );
}

class _ExtractedKnowledgeTile extends StatelessWidget {
  const _ExtractedKnowledgeTile({
    required this.item,
    required this.leading,
    required this.selected,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenEditor,
    required this.onLongPress,
    required this.onTag,
  });

  final ExtractedKnowledgeItem item;
  final Widget leading;
  final bool selected;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onOpenEditor;
  final VoidCallback onLongPress;
  final VoidCallback onTag;

  @override
  Widget build(BuildContext context) {
    final shared = sharedChunkFromExtractedItem(
      item,
      filename: '',
      isImage: false,
    );
    final structuredTags = noteBlockFromPdfChunk(item).knownTags;
    return SharedChunkCard(
      id: item.id,
      keyPrefix: 'chunk-card',
      expandKeyPrefix: 'pdf-chunk',
      kind: shared.kind,
      title: shared.title,
      expanded: expanded,
      selected: selected,
      statusChips: _statusChips(item),
      tagCount: structuredTags.length,
      tagBadgeColor: structuredTags.isEmpty
          ? null
          : Color(structuredTags.first.resolvedColorValue),
      leading: leading,
      onOpenEditor: onOpenEditor,
      onLongPress: onLongPress,
      onToggleExpanded: onToggleExpanded,
      actions: [
        IconButton(
          key: ValueKey('pdf-chunk-tags-${item.id}'),
          tooltip: 'Chunk tagek',
          onPressed: onTag,
          icon: const Icon(Icons.sell_outlined),
        ),
      ],
      expandedBodyKey: ValueKey('pdf-chunk-expanded-body-${item.id}'),
      expandedPadding: item.chunkKind == LocalChunkKind.flowchart
          ? const EdgeInsets.fromLTRB(8, 10, 8, 2)
          : const EdgeInsets.fromLTRB(46, 10, 8, 2),
      expandedBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NoteChunkBody(block: noteBlockFromPdfChunk(item)),
          const SizedBox(height: 12),
          Text(
            _metadata(item),
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ],
      ),
    );
  }

  static List<SharedChunkStatusChip> _statusChips(ExtractedKnowledgeItem item) {
    final chips = <SharedChunkStatusChip>[
      SharedChunkStatusChip(
        label: item.auditState == LocalAuditState.unreviewed
            ? 'Review'
            : item.auditState.label,
        color: _auditColor(item.auditState),
      ),
      SharedChunkStatusChip(
        label: item.typeLabel,
        color: const Color(0xFF0F766E),
      ),
      SharedChunkStatusChip(
        label: item.pipelineLabel,
        color: const Color(0xFF475569),
      ),
    ];
    return chips;
  }

  static Color _auditColor(LocalAuditState state) {
    return switch (state) {
      LocalAuditState.accepted => const Color(0xFF047857),
      LocalAuditState.edited => const Color(0xFF2563EB),
      LocalAuditState.rejected => const Color(0xFFB91C1C),
      LocalAuditState.unreviewed => const Color(0xFFB45309),
    };
  }

  static String _metadata(ExtractedKnowledgeItem item) {
    final parts = <String>[
      'id: ${item.id}',
      'típus: ${item.typeLabel}',
      'létrehozás: ${item.pipelineLabel}',
      'állapot: ${item.auditState.label}',
    ];
    final model = item.embeddingModel;
    if (model != null && model.isNotEmpty) {
      parts.add('embedding: $model');
    }
    return parts.join('  -  ');
  }
}

class _EmptyExtractedKnowledge extends StatelessWidget {
  const _EmptyExtractedKnowledge({required this.filename});

  final String filename;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.find_in_page_outlined,
              size: 42,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              filename,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nincs kinyert tartalom ehhez a dokumentumhoz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
