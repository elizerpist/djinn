import 'package:flutter/material.dart';

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
  _ExtractedPipelineView _pipelineView = _ExtractedPipelineView.ai;
  _ExtractedTypeFilter _typeFilter = _ExtractedTypeFilter.all;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_ExtractedKnowledgeData> _loadData() async {
    final allItems = await widget.repository.listExtractedKnowledgeItems(
      widget.document.id,
    );
    final comparison = await widget.repository.compareExtractedChunks(
      widget.document.id,
    );
    return _ExtractedKnowledgeData(
      allItems: allItems,
      aiItems: allItems
          .where((item) => item.pipeline == LocalExtractionPipeline.ai)
          .toList(growable: false),
      localItems: allItems
          .where(
            (item) =>
                item.pipeline != LocalExtractionPipeline.ai &&
                item.pipeline != LocalExtractionPipeline.manual,
          )
          .toList(growable: false),
      manualItems: allItems
          .where((item) => item.pipeline == LocalExtractionPipeline.manual)
          .toList(growable: false),
      comparison: comparison,
    );
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
    final changed = await Navigator.of(context).push<bool>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pipelineView.title),
        actions: [
          PopupMenuButton<_ExtractedPipelineView>(
            key: const Key('extracted-pipeline-menu'),
            tooltip: 'Kinyert tartalom nézet',
            initialValue: _pipelineView,
            onSelected: (value) {
              setState(() {
                _pipelineView = value;
                _typeFilter = _ExtractedTypeFilter.all;
              });
            },
            itemBuilder: (context) => [
              for (final view in _ExtractedPipelineView.values)
                PopupMenuItem(value: view, child: Text(view.title)),
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
          if (data == null || data.allItems.isEmpty) {
            return _EmptyExtractedKnowledge(filename: widget.document.filename);
          }
          final sourceItems = _itemsFor(data);
          final filteredItems = _filterByType(sourceItems);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _DocumentSummary(
                  filename: widget.document.filename,
                  count: sourceItems.length,
                ),
              ),
              if (_pipelineView != _ExtractedPipelineView.comparison)
                _ContentTypeFilterBar(
                  selected: _typeFilter,
                  onSelected: (value) => setState(() => _typeFilter = value),
                ),
              Expanded(
                child: _pipelineView == _ExtractedPipelineView.comparison
                    ? _ChunkComparisonList(comparison: data.comparison)
                    : _ExtractedKnowledgeList(
                        items: filteredItems,
                        onValidate: _openValidationCard,
                        onEditFlowchart: _openFlowchartEditor,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ExtractedKnowledgeItem> _itemsFor(_ExtractedKnowledgeData data) {
    return switch (_pipelineView) {
      _ExtractedPipelineView.ai => data.aiItems,
      _ExtractedPipelineView.local => data.localItems,
      _ExtractedPipelineView.manual => data.manualItems,
      _ExtractedPipelineView.comparison => data.allItems,
    };
  }

  List<ExtractedKnowledgeItem> _filterByType(
    List<ExtractedKnowledgeItem> items,
  ) {
    if (_typeFilter == _ExtractedTypeFilter.all) {
      return items;
    }
    return items.where(_typeFilter.matches).toList(growable: false);
  }
}

enum _ExtractedPipelineView { ai, local, manual, comparison }

extension _ExtractedPipelineViewLabel on _ExtractedPipelineView {
  String get title {
    return switch (this) {
      _ExtractedPipelineView.ai => 'AI chunkok',
      _ExtractedPipelineView.local => 'Lokális chunkok',
      _ExtractedPipelineView.manual => 'Manuális chunkok',
      _ExtractedPipelineView.comparison => 'Összehasonlítás',
    };
  }
}

enum _ExtractedTypeFilter { all, text, list, table, flowchart }

extension _ExtractedTypeFilterLabel on _ExtractedTypeFilter {
  String get label {
    return switch (this) {
      _ExtractedTypeFilter.all => 'Összes',
      _ExtractedTypeFilter.text => 'Szöveg',
      _ExtractedTypeFilter.list => 'Felsorolás',
      _ExtractedTypeFilter.table => 'Táblázat',
      _ExtractedTypeFilter.flowchart => 'Flowchart',
    };
  }

  bool matches(ExtractedKnowledgeItem item) {
    return switch (this) {
      _ExtractedTypeFilter.all => true,
      _ExtractedTypeFilter.text =>
        item.chunkKind == LocalChunkKind.text ||
            item.sourceType == EvidenceSourceType.textChunk,
      _ExtractedTypeFilter.list => item.chunkKind == LocalChunkKind.list,
      _ExtractedTypeFilter.table =>
        item.chunkKind == LocalChunkKind.table ||
            item.sourceType == EvidenceSourceType.tableChunk ||
            item.sourceType == EvidenceSourceType.scoreChunk,
      _ExtractedTypeFilter.flowchart =>
        item.chunkKind == LocalChunkKind.flowchart ||
            item.sourceType == EvidenceSourceType.flowchartNode ||
            item.sourceType == EvidenceSourceType.flowchartEdge,
    };
  }
}

class _ContentTypeFilterBar extends StatelessWidget {
  const _ContentTypeFilterBar({
    required this.selected,
    required this.onSelected,
  });

  final _ExtractedTypeFilter selected;
  final ValueChanged<_ExtractedTypeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            for (final filter in _ExtractedTypeFilter.values) ...[
              ChoiceChip(
                key: ValueKey('extracted-type-${filter.name}'),
                label: Text(filter.label),
                selected: filter == selected,
                onSelected: (_) => onSelected(filter),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExtractedKnowledgeData {
  const _ExtractedKnowledgeData({
    required this.allItems,
    required this.aiItems,
    required this.localItems,
    required this.manualItems,
    required this.comparison,
  });

  final List<ExtractedKnowledgeItem> allItems;
  final List<ExtractedKnowledgeItem> aiItems;
  final List<ExtractedKnowledgeItem> localItems;
  final List<ExtractedKnowledgeItem> manualItems;
  final ChunkComparison comparison;
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
  });

  final List<ExtractedKnowledgeItem> items;
  final ValueChanged<ExtractedKnowledgeItem> onValidate;
  final ValueChanged<String> onEditFlowchart;

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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ExtractedKnowledgeTile(
        item: items[index],
        onValidate: () => onValidate(items[index]),
      ),
    );
  }
}

class _ChunkComparisonList extends StatelessWidget {
  const _ChunkComparisonList({required this.comparison});

  final ChunkComparison comparison;

  @override
  Widget build(BuildContext context) {
    final rows = comparison.rows;
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Nincs összehasonlítható chunk',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ChunkComparisonTile(row: rows[index]),
    );
  }
}

class _ChunkComparisonTile extends StatelessWidget {
  const _ChunkComparisonTile({required this.row});

  final ChunkComparisonRow row;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(row.status);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(_statusIcon(row.status), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusLabel(row.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  row.pageNumber == null ? '' : '${row.pageNumber}. oldal',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (row.sectionTitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                row.sectionTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ComparisonSide(
                    title: 'AI',
                    item: row.aiChunk,
                    emptyLabel: 'Nincs AI chunk',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ComparisonSide(
                    title: 'Lokális',
                    item: row.localChunk,
                    emptyLabel: 'Nincs lokális chunk',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(ChunkComparisonStatus status) {
    return switch (status) {
      ChunkComparisonStatus.matched => const Color(0xFF047857),
      ChunkComparisonStatus.aiOnly => const Color(0xFFB45309),
      ChunkComparisonStatus.localOnly => const Color(0xFF7C3AED),
    };
  }

  static IconData _statusIcon(ChunkComparisonStatus status) {
    return switch (status) {
      ChunkComparisonStatus.matched => Icons.link,
      ChunkComparisonStatus.aiOnly => Icons.cloud_outlined,
      ChunkComparisonStatus.localOnly => Icons.phone_android_outlined,
    };
  }

  static String _statusLabel(ChunkComparisonStatus status) {
    return switch (status) {
      ChunkComparisonStatus.matched => 'Egyező oldal/szekció',
      ChunkComparisonStatus.aiOnly => 'Csak AI chunk',
      ChunkComparisonStatus.localOnly => 'Csak lokális chunk',
    };
  }
}

class _ComparisonSide extends StatelessWidget {
  const _ComparisonSide({
    required this.title,
    required this.item,
    required this.emptyLabel,
  });

  final String title;
  final ChunkComparisonItem? item;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = item;
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: resolved == null
          ? Text(emptyLabel, style: const TextStyle(color: Color(0xFF9CA3AF)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title - ${resolved.typeLabel}',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  resolved.text,
                  style: const TextStyle(fontSize: 12, height: 1.25),
                ),
                const SizedBox(height: 8),
                Text(
                  '${resolved.pipelineLabel} - ${resolved.auditState.label}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
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
  const _ExtractedKnowledgeTile({required this.item, required this.onValidate});

  final ExtractedKnowledgeItem item;
  final VoidCallback onValidate;

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
      ),
      onLongPress: onValidate,
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
