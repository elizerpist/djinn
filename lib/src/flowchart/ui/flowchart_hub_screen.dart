import 'package:flutter/material.dart';

import '../../branding/djinn_brand_mark.dart';
import '../../debug/debug_header_button.dart';
import '../../local_store/entities.dart';
import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/models/extracted_knowledge_item.dart';
import '../../knowledge/models/knowledge_document.dart';
import '../../knowledge/models/local_extraction.dart';
import '../../knowledge/ui/extracted_knowledge_screen.dart';
import '../data/flowchart_validation_repository.dart';
import 'flowchart_builder_screen.dart';
import 'flowchart_validation_screen.dart';

class FlowchartHubScreen extends StatefulWidget {
  const FlowchartHubScreen({
    super.key,
    required this.validationRepository,
    this.knowledgeRepository,
  });

  final FlowchartValidationRepository? validationRepository;
  final KnowledgeDocumentRepository? knowledgeRepository;

  @override
  State<FlowchartHubScreen> createState() => _FlowchartHubScreenState();
}

class _FlowchartHubScreenState extends State<FlowchartHubScreen> {
  _FlowchartHubTab _selected = _FlowchartHubTab.validation;
  FlowchartBuilderTemplate? _builderTemplate;

  void _selectTemplate(FlowchartBuilderTemplate template) {
    setState(() {
      _builderTemplate = template;
      _selected = _FlowchartHubTab.builder;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const DjinnBrandMark(size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Audit',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const DebugHeaderButton(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tab in _FlowchartHubTab.values) ...[
                            ChoiceChip(
                              label: Text(tab.label),
                              selected: tab == _selected,
                              onSelected: (_) =>
                                  setState(() => _selected = tab),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _bodyFor(_selected)),
        ],
      ),
    );
  }

  Widget _bodyFor(_FlowchartHubTab tab) {
    return switch (tab) {
      _FlowchartHubTab.validation => _AuditPane(
        repository: widget.knowledgeRepository,
        fallbackRepository: widget.validationRepository,
      ),
      _FlowchartHubTab.extracted => _ExtractedPane(
        repository: widget.knowledgeRepository,
      ),
      _FlowchartHubTab.builder => FlowchartBuilderScreen(
        key: ValueKey(_builderTemplate?.id ?? 'blank-flowchart-builder'),
        template: _builderTemplate,
      ),
      _FlowchartHubTab.templates => _TemplatePane(onSelect: _selectTemplate),
    };
  }
}

enum _FlowchartHubTab { validation, extracted, builder, templates }

extension on _FlowchartHubTab {
  String get label {
    return switch (this) {
      _FlowchartHubTab.validation => 'Audit',
      _FlowchartHubTab.extracted => 'Kinyert tartalom',
      _FlowchartHubTab.builder => 'Építő',
      _FlowchartHubTab.templates => 'Sablonok',
    };
  }
}

class _AuditPane extends StatefulWidget {
  const _AuditPane({
    required this.repository,
    required this.fallbackRepository,
  });

  final KnowledgeDocumentRepository? repository;
  final FlowchartValidationRepository? fallbackRepository;

  @override
  State<_AuditPane> createState() => _AuditPaneState();
}

class _AuditPaneState extends State<_AuditPane> {
  _AuditFilter _filter = _AuditFilter.all;
  Future<List<_AuditItemView>>? _itemsFuture;
  KnowledgeDocumentRepository? _loadedRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant _AuditPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureFuture();
  }

  void _ensureFuture() {
    final repository = widget.repository;
    if (repository == null) {
      _itemsFuture = null;
      _loadedRepository = null;
      return;
    }
    if (!identical(_loadedRepository, repository)) {
      _loadedRepository = repository;
      _itemsFuture = _loadItems(repository);
    }
  }

  Future<List<_AuditItemView>> _loadItems(
    KnowledgeDocumentRepository repository,
  ) async {
    final documents = await repository.listDocuments();
    final items = <_AuditItemView>[];
    for (final document in documents) {
      final extracted = await repository.listExtractedKnowledgeItems(
        document.id,
      );
      for (final item in extracted) {
        items.add(_AuditItemView(document: document, item: item));
      }
    }
    items.sort((a, b) {
      final state = a.item.auditState.index.compareTo(b.item.auditState.index);
      if (state != 0) {
        return state;
      }
      final document = a.document.filename.compareTo(b.document.filename);
      if (document != 0) {
        return document;
      }
      return (a.item.pageNumber ?? 0).compareTo(b.item.pageNumber ?? 0);
    });
    return items;
  }

  Future<void> _setAuditState(
    _AuditItemView view,
    LocalAuditState state, {
    String? text,
  }) async {
    final repository = widget.repository;
    if (repository == null) {
      return;
    }
    await repository.updateExtractedKnowledgeAuditState(
      view.document.id,
      view.item.id,
      state,
      text: text,
    );
    setState(() {
      _itemsFuture = _loadItems(repository);
    });
  }

  Future<void> _editItem(_AuditItemView view) async {
    final controller = TextEditingController(text: view.item.text);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kinyert tartalom szerkesztése'),
        content: TextField(
          controller: controller,
          key: const ValueKey('audit-edit-field'),
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (edited == null || edited.isEmpty) {
      return;
    }
    await _setAuditState(view, LocalAuditState.edited, text: edited);
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    if (repository == null) {
      final fallback = widget.fallbackRepository;
      if (fallback != null) {
        return FlowchartValidationScreen(
          repository: fallback,
          showAppBar: false,
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Kinyert tartalom audit nem elérhető ebben a környezetben.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    _ensureFuture();
    return FutureBuilder<List<_AuditItemView>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final allItems = snapshot.data ?? const <_AuditItemView>[];
        final filtered = allItems
            .where(_filter.matches)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  for (final filter in _AuditFilter.values) ...[
                    ChoiceChip(
                      label: Text(filter.label),
                      selected: filter == _filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nincs a szűrésnek megfelelő audit elem.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _AuditItemCard(
                        view: filtered[index],
                        onAccept: () => _setAuditState(
                          filtered[index],
                          LocalAuditState.accepted,
                        ),
                        onEdit: () => _editItem(filtered[index]),
                        onReject: () => _setAuditState(
                          filtered[index],
                          LocalAuditState.rejected,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

enum _AuditFilter { all, text, table, flowchart, image, uncertain, accepted }

extension on _AuditFilter {
  String get label {
    return switch (this) {
      _AuditFilter.all => 'Mind',
      _AuditFilter.text => 'Szöveg',
      _AuditFilter.table => 'Táblázat',
      _AuditFilter.flowchart => 'Flowchart',
      _AuditFilter.image => 'Kép',
      _AuditFilter.uncertain => 'Bizonytalan',
      _AuditFilter.accepted => 'Elfogadott',
    };
  }

  bool matches(_AuditItemView view) {
    final item = view.item;
    return switch (this) {
      _AuditFilter.all => true,
      _AuditFilter.text => item.sourceType == EvidenceSourceType.textChunk,
      _AuditFilter.table =>
        item.sourceType == EvidenceSourceType.tableChunk ||
            item.sourceType == EvidenceSourceType.scoreChunk ||
            item.chunkKind == LocalChunkKind.table,
      _AuditFilter.flowchart =>
        item.sourceType == EvidenceSourceType.flowchartNode ||
            item.sourceType == EvidenceSourceType.flowchartEdge ||
            item.chunkKind == LocalChunkKind.flowchart,
      _AuditFilter.image => false,
      _AuditFilter.uncertain => item.auditState == LocalAuditState.unreviewed,
      _AuditFilter.accepted =>
        item.auditState == LocalAuditState.accepted ||
            item.auditState == LocalAuditState.edited,
    };
  }
}

class _AuditItemView {
  const _AuditItemView({required this.document, required this.item});

  final KnowledgeDocument document;
  final ExtractedKnowledgeItem item;
}

class _AuditItemCard extends StatelessWidget {
  const _AuditItemCard({
    required this.view,
    required this.onAccept,
    required this.onEdit,
    required this.onReject,
  });

  final _AuditItemView view;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = view.item;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconFor(item),
                  color: _colorFor(item.auditState),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    view.document.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _AuditStatePill(state: item.auditState),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                item.typeLabel,
                item.pipelineLabel,
                if (item.pageNumber != null) '${item.pageNumber}. oldal',
              ].join(' · '),
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            if ((item.sectionTitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.sectionTitle!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 8),
            SelectableText(item.text, style: const TextStyle(height: 1.28)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Elfogad'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Szerkeszt'),
                ),
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Elvet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ExtractedKnowledgeItem item) {
    return switch (item.sourceType) {
      EvidenceSourceType.tableChunk ||
      EvidenceSourceType.scoreChunk => Icons.table_chart_outlined,
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => Icons.account_tree_outlined,
      EvidenceSourceType.textChunk => Icons.subject,
    };
  }

  Color _colorFor(LocalAuditState state) {
    return switch (state) {
      LocalAuditState.accepted => const Color(0xFF059669),
      LocalAuditState.edited => const Color(0xFF2563EB),
      LocalAuditState.rejected => const Color(0xFFDC2626),
      LocalAuditState.unreviewed => const Color(0xFFF59E0B),
    };
  }
}

class _AuditStatePill extends StatelessWidget {
  const _AuditStatePill({required this.state});

  final LocalAuditState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      LocalAuditState.accepted => const Color(0xFF059669),
      LocalAuditState.edited => const Color(0xFF2563EB),
      LocalAuditState.rejected => const Color(0xFFDC2626),
      LocalAuditState.unreviewed => const Color(0xFFF59E0B),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          state.label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ExtractedPane extends StatefulWidget {
  const _ExtractedPane({required this.repository});

  final KnowledgeDocumentRepository? repository;

  @override
  State<_ExtractedPane> createState() => _ExtractedPaneState();
}

class _ExtractedPaneState extends State<_ExtractedPane> {
  Future<List<_AuditDocumentSummary>>? _summariesFuture;
  KnowledgeDocumentRepository? _loadedRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant _ExtractedPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureFuture();
  }

  void _ensureFuture() {
    final repository = widget.repository;
    if (repository == null) {
      _summariesFuture = null;
      _loadedRepository = null;
      return;
    }
    if (!identical(_loadedRepository, repository)) {
      _loadedRepository = repository;
      _summariesFuture = _loadSummaries(repository);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.repository;
    if (resolved == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nincs csatlakoztatott tudástár ehhez a nézethez.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    _ensureFuture();
    return FutureBuilder<List<_AuditDocumentSummary>>(
      future: _summariesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <_AuditDocumentSummary>[];
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nincs auditálható kinyert tartalom a tudástárban.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          );
        }
        return ListView.separated(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(item.document.filename),
                subtitle: Text('${item.itemCount} kinyert elem auditálható'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExtractedKnowledgeScreen(
                      repository: resolved,
                      document: item.document,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_AuditDocumentSummary>> _loadSummaries(
    KnowledgeDocumentRepository repository,
  ) async {
    final documents = await repository.listDocuments();
    final summaries = <_AuditDocumentSummary>[];
    for (final document in documents) {
      final items = await repository.listExtractedKnowledgeItems(document.id);
      final count = items.length;
      if (count > 0) {
        summaries.add(
          _AuditDocumentSummary(document: document, itemCount: count),
        );
      }
    }
    return summaries;
  }
}

class _AuditDocumentSummary {
  const _AuditDocumentSummary({
    required this.document,
    required this.itemCount,
  });

  final KnowledgeDocument document;
  final int itemCount;
}

class _TemplatePane extends StatelessWidget {
  const _TemplatePane({required this.onSelect});

  final ValueChanged<FlowchartBuilderTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final templates = FlowchartBuilderTemplates.all;
    return ListView.separated(
      key: const ValueKey('flowchart-template-list'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: templates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = templates[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_mosaic_outlined),
            title: Text(item.title),
            subtitle: Text(item.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelect(item),
          ),
        );
      },
    );
  }
}
