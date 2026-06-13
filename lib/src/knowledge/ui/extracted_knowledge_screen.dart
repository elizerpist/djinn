import 'package:flutter/material.dart';

import '../../local_store/entities.dart';
import '../data/knowledge_document_repository.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/flowchart_hierarchy.dart';
import '../models/knowledge_document.dart';

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
  late final Future<List<ExtractedKnowledgeItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.repository.listExtractedKnowledgeItems(
      widget.document.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kinyert tartalom')),
      body: FutureBuilder<List<ExtractedKnowledgeItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return _EmptyExtractedKnowledge(filename: widget.document.filename);
          }
          return DefaultTabController(
            length: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _DocumentSummary(
                    filename: widget.document.filename,
                    count: items.length,
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Összes'),
                    Tab(text: 'Szöveg'),
                    Tab(text: 'Táblázat'),
                    Tab(text: 'Score'),
                    Tab(text: 'Flowchart'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ExtractedKnowledgeList(items: items),
                      _ExtractedKnowledgeList(
                        items: _filter(items, EvidenceSourceType.textChunk),
                      ),
                      _ExtractedKnowledgeList(
                        items: _filter(items, EvidenceSourceType.tableChunk),
                      ),
                      _ExtractedKnowledgeList(
                        items: _filter(items, EvidenceSourceType.scoreChunk),
                      ),
                      _FlowchartHierarchyList(
                        items: items
                            .where(
                              (item) =>
                                  item.sourceType ==
                                      EvidenceSourceType.flowchartNode ||
                                  item.sourceType ==
                                      EvidenceSourceType.flowchartEdge,
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static List<ExtractedKnowledgeItem> _filter(
    List<ExtractedKnowledgeItem> items,
    EvidenceSourceType sourceType,
  ) {
    return items
        .where((item) => item.sourceType == sourceType)
        .toList(growable: false);
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

class _ExtractedKnowledgeList extends StatelessWidget {
  const _ExtractedKnowledgeList({required this.items});

  final List<ExtractedKnowledgeItem> items;

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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _ExtractedKnowledgeTile(item: items[index]),
    );
  }
}

class _FlowchartHierarchyList extends StatefulWidget {
  const _FlowchartHierarchyList({required this.items});

  final List<ExtractedKnowledgeItem> items;

  @override
  State<_FlowchartHierarchyList> createState() =>
      _FlowchartHierarchyListState();
}

class _FlowchartHierarchyListState extends State<_FlowchartHierarchyList> {
  final Map<int, Color> _slotColors = {};

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
        final title = group.rows.isEmpty
            ? 'Flowchart'
            : group.rows.first.item.sectionTitle ?? 'Flowchart';
        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                    Text(
                      '${group.rows.length} elem',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final row in group.rows) ...[
                  _FlowchartHierarchyRowTile(
                    row: row,
                    colorForSlot: _colorForSlot,
                    onLongPress: row.isConnector
                        ? null
                        : () => _chooseColor(row),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _colorForSlot(int slot) {
    return _slotColors[slot] ??
        _tailwindColors[slot % _tailwindColors.length].color;
  }

  Future<void> _chooseColor(FlowchartHierarchyRow row) async {
    final slot = row.colorSlots.isEmpty ? 0 : row.colorSlots.last;
    final selected = await showModalBottomSheet<Color>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Színslot ${slot + 1}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in _tailwindColors)
                        Tooltip(
                          message: color.name,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).pop(color.color),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: color.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _slotColors[slot] = selected);
    }
  }
}

class _FlowchartHierarchyRowTile extends StatelessWidget {
  const _FlowchartHierarchyRowTile({
    required this.row,
    required this.colorForSlot,
    required this.onLongPress,
  });

  final FlowchartHierarchyRow row;
  final Color Function(int slot) colorForSlot;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    if (row.isConnector) {
      return Padding(
        padding: EdgeInsets.only(left: row.depth * 26.0),
        child: SizedBox(
          height: 26,
          child: Center(
            child: row.connectorLabel.isEmpty
                ? const SizedBox(width: 28, height: 8)
                : Container(
                    key: ValueKey('flow-connector-${item.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Text(
                      row.connectorLabel,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: row.depth * 26.0),
            for (final slot in row.colorSlots)
              Container(
                width: 4,
                height: 42,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: colorForSlot(slot),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 5),
            Icon(
              _shapeIcon(item.flowchartShape),
              size: 20,
              color: const Color(0xFF111827),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shapeLabel(item.flowchartShape),
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    item.text,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _shapeIcon(String? shape) {
    return switch (shape) {
      'start_end' => Icons.play_circle_outline,
      'decision' => Icons.change_history,
      'input_output' => Icons.input,
      'subprocess' => Icons.view_agenda_outlined,
      'data_store' => Icons.storage,
      'connector' => Icons.radio_button_unchecked,
      'process' => Icons.crop_square,
      _ => Icons.help_outline,
    };
  }

  static String _shapeLabel(String? shape) {
    return switch (shape) {
      'start_end' => 'Kezdés/Vége',
      'decision' => 'Döntés',
      'input_output' => 'Bemenet/Kimenet',
      'subprocess' => 'Alfolyamat',
      'data_store' => 'Adattárolás',
      'connector' => 'Kapcsoló',
      'process' => 'Folyamatlépés',
      _ => 'Ismeretlen elem',
    };
  }
}

class _NamedColor {
  const _NamedColor(this.name, this.color);

  final String name;
  final Color color;
}

const _tailwindColors = [
  _NamedColor('Slate', Color(0xFF64748B)),
  _NamedColor('Gray', Color(0xFF6B7280)),
  _NamedColor('Zinc', Color(0xFF71717A)),
  _NamedColor('Neutral', Color(0xFF737373)),
  _NamedColor('Stone', Color(0xFF78716C)),
  _NamedColor('Red', Color(0xFFEF4444)),
  _NamedColor('Orange', Color(0xFFF97316)),
  _NamedColor('Amber', Color(0xFFF59E0B)),
  _NamedColor('Yellow', Color(0xFFEAB308)),
  _NamedColor('Lime', Color(0xFF84CC16)),
  _NamedColor('Green', Color(0xFF22C55E)),
  _NamedColor('Emerald', Color(0xFF10B981)),
  _NamedColor('Teal', Color(0xFF14B8A6)),
  _NamedColor('Cyan', Color(0xFF06B6D4)),
  _NamedColor('Sky', Color(0xFF0EA5E9)),
  _NamedColor('Blue', Color(0xFF3B82F6)),
  _NamedColor('Indigo', Color(0xFF6366F1)),
  _NamedColor('Violet', Color(0xFF8B5CF6)),
  _NamedColor('Purple', Color(0xFFA855F7)),
  _NamedColor('Fuchsia', Color(0xFFD946EF)),
  _NamedColor('Pink', Color(0xFFEC4899)),
  _NamedColor('Rose', Color(0xFFF43F5E)),
];

class _ExtractedKnowledgeTile extends StatelessWidget {
  const _ExtractedKnowledgeTile({required this.item});

  final ExtractedKnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(item.sourceType);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(_iconFor(item.sourceType), size: 20),
        ),
        title: Text(
          item.pageLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((item.sectionTitle ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.sectionTitle!),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                item.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _ExtractedKnowledgeBody(item: item),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _metadata(item),
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static String _metadata(ExtractedKnowledgeItem item) {
    final parts = <String>[
      'id: ${item.id}',
      'típus: ${item.sourceType.wireName}',
    ];
    final model = item.embeddingModel;
    if (model != null && model.isNotEmpty) {
      parts.add('embedding: $model');
    }
    return parts.join('  •  ');
  }

  static IconData _iconFor(EvidenceSourceType type) {
    return switch (type) {
      EvidenceSourceType.textChunk => Icons.subject,
      EvidenceSourceType.tableChunk => Icons.table_chart_outlined,
      EvidenceSourceType.scoreChunk => Icons.format_list_numbered,
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => Icons.account_tree_outlined,
    };
  }

  static Color _colorFor(EvidenceSourceType type) {
    return switch (type) {
      EvidenceSourceType.textChunk => const Color(0xFF2563EB),
      EvidenceSourceType.tableChunk => const Color(0xFF047857),
      EvidenceSourceType.scoreChunk => const Color(0xFFB45309),
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => const Color(0xFF7C3AED),
    };
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
