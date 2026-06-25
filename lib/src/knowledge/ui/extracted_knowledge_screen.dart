import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../data/knowledge_document_repository.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/flowchart_hierarchy.dart';
import '../models/knowledge_document.dart';
import '../models/local_extraction.dart';
import '../../shared/chunks/chunk_card.dart';
import '../../shared/chunks/chunk_validation_card.dart';
import '../../shared/ui/draggable_bottom_card.dart';
import '../../flowchart/ui/interactive_flowchart_editor_screen.dart';
import '../../flowchart/ui/mobile_flowchart_viewer.dart';
import '../../notes/ui/tag_manager_sheet.dart';
import 'pdf_shared_chunk_adapter.dart';

class ExtractedKnowledgeScreen extends StatefulWidget {
  const ExtractedKnowledgeScreen({
    super.key,
    required this.repository,
    required this.document,
  });

  final KnowledgeDocumentRepository repository;
  final KnowledgeDocument document;

  @override
  State<ExtractedKnowledgeScreen> createState() =>
      _ExtractedKnowledgeScreenState();
}

class _ExtractedKnowledgeScreenState extends State<ExtractedKnowledgeScreen> {
  late Future<_ExtractedKnowledgeData> _dataFuture;
  _PdfChunkMode _mode = _PdfChunkMode.ai;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ExtractedKnowledgeData> _loadData() async {
    final allItems = await widget.repository.listExtractedKnowledgeItems(
      widget.document.id,
    );
    final aiItems = allItems
        .where((item) => item.pipeline == LocalExtractionPipeline.ai)
        .toList(growable: false);
    final manualItems = allItems
        .where((item) => item.pipeline != LocalExtractionPipeline.ai)
        .toList(growable: false);
    DebugConsole.log(
      '[PDFChunks] load document=${widget.document.id} '
      'ai=${aiItems.length} manual=${manualItems.length}',
    );
    return _ExtractedKnowledgeData(aiItems: aiItems, manualItems: manualItems);
  }

  void _reloadData() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _openValidationCard(ExtractedKnowledgeItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableBottomCard(
        onDismiss: () => Navigator.of(context).pop(),
        child: ChunkValidationCard(
          title: item.sectionTitle?.trim().isNotEmpty == true
              ? item.sectionTitle!.trim()
              : item.pageLabel,
          initialText: item.text,
          initialAuditState: item.auditState,
          onCancel: () => Navigator.of(context).pop(),
          onSave: (result) async {
            await widget.repository.updateExtractedKnowledgeAuditState(
              widget.document.id,
              item.id,
              result.auditState,
              text: result.text,
              reason: result.reason,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            _reloadData();
          },
        ),
      ),
    );
  }

  Future<void> _openFlowchartEditor(String flowchartId) async {
    final changed = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => InteractiveFlowchartEditorScreen(
          repository: widget.repository,
          documentId: widget.document.id,
          flowchartId: flowchartId,
        ),
      ),
    );
    if (changed == true) {
      _reloadData();
    }
  }

  Future<void> _openTagSheet(ExtractedKnowledgeItem item) async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: item.tags,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode.title),
        actions: [
          PopupMenuButton<_PdfChunkMode>(
            key: const Key('pdf-chunk-mode-menu'),
            tooltip: 'Chunk mód',
            initialValue: _mode,
            onSelected: (value) {
              DebugConsole.log(
                '[PDFChunks] mode changed document=${widget.document.id} '
                'mode=${value.name}',
              );
              setState(() => _mode = value);
            },
            itemBuilder: (context) => [
              for (final mode in _PdfChunkMode.values)
                PopupMenuItem(value: mode, child: Text(mode.title)),
            ],
          ),
        ],
      ),
      body: FutureBuilder<_ExtractedKnowledgeData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null ||
              (data.aiItems.isEmpty && data.manualItems.isEmpty)) {
            return _EmptyExtractedKnowledge(filename: widget.document.filename);
          }
          final items = _mode == _PdfChunkMode.ai
              ? data.aiItems
              : data.manualItems;
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
                  onValidate: _openValidationCard,
                  onEditFlowchart: _openFlowchartEditor,
                  onTag: _openTagSheet,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _PdfChunkMode { ai, manual }

extension _PdfChunkModeLabel on _PdfChunkMode {
  String get title {
    return switch (this) {
      _PdfChunkMode.ai => 'AI chunkok',
      _PdfChunkMode.manual => 'Manuális chunkok',
    };
  }
}

class _ExtractedKnowledgeData {
  const _ExtractedKnowledgeData({
    required this.aiItems,
    required this.manualItems,
  });

  final List<ExtractedKnowledgeItem> aiItems;
  final List<ExtractedKnowledgeItem> manualItems;
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

class _ExtractedKnowledgeList extends StatelessWidget {
  const _ExtractedKnowledgeList({
    required this.items,
    required this.onValidate,
    required this.onEditFlowchart,
    required this.onTag,
  });

  final List<ExtractedKnowledgeItem> items;
  final ValueChanged<ExtractedKnowledgeItem> onValidate;
  final ValueChanged<String> onEditFlowchart;
  final ValueChanged<ExtractedKnowledgeItem> onTag;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Nincs ilyen típusú kinyert tartalom',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    final flowchartItems = items
        .where(
          (item) =>
              item.sourceType == EvidenceSourceType.flowchartNode ||
              item.sourceType == EvidenceSourceType.flowchartEdge,
        )
        .toList(growable: false);
    if (flowchartItems.length == items.length) {
      return _FlowchartHierarchyList(
        items: flowchartItems,
        onEditFlowchart: onEditFlowchart,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ExtractedKnowledgeTile(
        item: items[index],
        onValidate: () => onValidate(items[index]),
        onTag: () => onTag(items[index]),
      ),
    );
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
    required this.onValidate,
    required this.onTag,
  });

  final ExtractedKnowledgeItem item;
  final VoidCallback onValidate;
  final VoidCallback onTag;

  @override
  Widget build(BuildContext context) {
    return ChunkCard(
      viewModel: ChunkCardViewModel(
        id: item.id,
        title: item.pageLabel,
        preview: item.text,
        kind: _cardKindFor(item),
        auditState: item.auditState,
        sourceLabel: item.typeLabel,
        pipelineLabel: item.pipelineLabel,
        pageLabel: item.pageLabel,
        tags: item.tags,
      ),
      onLongPress: onValidate,
      onTag: onTag,
      tagButtonKey: ValueKey('pdf-chunk-tags-${item.id}'),
      expandedChild: _ExtractedKnowledgeBody(item: item),
      metadata: _metadata(item),
    );
  }

  static String _metadata(ExtractedKnowledgeItem item) {
    final parts = <String>[
      'id: ${item.id}',
      'típus: ${item.sourceType.wireName}',
      'pipeline: ${item.pipeline.wireName}',
      'audit: ${item.auditState.wireName}',
    ];
    final model = item.embeddingModel;
    if (model != null && model.isNotEmpty) {
      parts.add('embedding: $model');
    }
    return parts.join('  •  ');
  }

  static ChunkCardKind _cardKindFor(ExtractedKnowledgeItem item) {
    final shared = sharedChunkFromExtractedItem(
      item,
      filename: '',
      isImage: false,
    );
    return shared.kind;
  }
}

class _ExtractedKnowledgeBody extends StatelessWidget {
  const _ExtractedKnowledgeBody({required this.item});

  final ExtractedKnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.sourceType) {
      EvidenceSourceType.tableChunk ||
      EvidenceSourceType.scoreChunk => _StructuredTableBlock(item: item),
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => _FlowchartBlock(item: item),
      EvidenceSourceType.textChunk => Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(item.text),
      ),
    };
  }
}

class _StructuredTableBlock extends StatelessWidget {
  const _StructuredTableBlock({required this.item});

  final ExtractedKnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    final rows = _rows(item.text);
    if (rows.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(item.text),
      );
    }
    final columns = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {
          for (var i = 0; i < columns; i += 1) i: const FlexColumnWidth(),
        },
        children: [
          for (var index = 0; index < rows.length; index += 1)
            TableRow(
              decoration: BoxDecoration(
                color: index == 0 ? const Color(0xFFF8FAFC) : Colors.white,
              ),
              children: [
                for (var column = 0; column < columns; column += 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: SelectableText(
                      column < rows[index].length ? rows[index][column] : '',
                      style: TextStyle(
                        color: const Color(0xFF111827),
                        fontSize: 12,
                        fontWeight: index == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<List<String>> _rows(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return [
      for (final line in lines)
        line
            .split(line.contains('|') ? '|' : ';')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false),
    ].where((row) => row.isNotEmpty).toList(growable: false);
  }
}

class _FlowchartBlock extends StatelessWidget {
  const _FlowchartBlock({required this.item});

  final ExtractedKnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    final isEdge = item.sourceType == EvidenceSourceType.flowchartEdge;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEdge ? Icons.arrow_forward : Icons.radio_button_unchecked,
            size: 18,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              item.text,
              style: const TextStyle(
                color: Color(0xFF4C1D95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
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
