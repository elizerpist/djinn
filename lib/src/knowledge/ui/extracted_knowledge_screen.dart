import 'package:flutter/material.dart';

import '../../local_store/entities.dart';
import '../data/knowledge_document_repository.dart';
import '../models/extracted_knowledge_item.dart';
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
  State<ExtractedKnowledgeScreen> createState() => _ExtractedKnowledgeScreenState();
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
                      _ExtractedKnowledgeList(
                        items: items
                            .where(
                              (item) =>
                                  item.sourceType == EvidenceSourceType.flowchartNode ||
                                  item.sourceType == EvidenceSourceType.flowchartEdge,
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
      itemBuilder: (context, index) => _ExtractedKnowledgeTile(
        item: items[index],
      ),
    );
  }
}

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
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(item.text),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _metadata(item),
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _metadata(ExtractedKnowledgeItem item) {
    final parts = <String>['id: ${item.id}', 'típus: ${item.sourceType.wireName}'];
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
      EvidenceSourceType.flowchartNode || EvidenceSourceType.flowchartEdge =>
        Icons.account_tree_outlined,
    };
  }

  static Color _colorFor(EvidenceSourceType type) {
    return switch (type) {
      EvidenceSourceType.textChunk => const Color(0xFF2563EB),
      EvidenceSourceType.tableChunk => const Color(0xFF047857),
      EvidenceSourceType.scoreChunk => const Color(0xFFB45309),
      EvidenceSourceType.flowchartNode || EvidenceSourceType.flowchartEdge =>
        const Color(0xFF7C3AED),
    };
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
            const Icon(Icons.find_in_page_outlined, size: 42, color: Color(0xFF9CA3AF)),
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
