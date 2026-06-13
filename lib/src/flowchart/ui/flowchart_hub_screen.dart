import 'package:flutter/material.dart';

import '../../branding/djinn_brand_mark.dart';
import '../../debug/debug_header_button.dart';
import '../../local_store/entities.dart';
import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/models/knowledge_document.dart';
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
                            'Flowchart',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
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
                              onSelected: (_) => setState(() => _selected = tab),
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
      _FlowchartHubTab.validation => _ValidationPane(
        repository: widget.validationRepository,
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
      _FlowchartHubTab.validation => 'Validálás',
      _FlowchartHubTab.extracted => 'Kinyert',
      _FlowchartHubTab.builder => 'Építő',
      _FlowchartHubTab.templates => 'Sablonok',
    };
  }
}

class _ValidationPane extends StatelessWidget {
  const _ValidationPane({required this.repository});

  final FlowchartValidationRepository? repository;

  @override
  Widget build(BuildContext context) {
    final resolved = repository;
    if (resolved == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Flowchart validáció nem elérhető ebben a környezetben.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    return FlowchartValidationScreen(repository: resolved, showAppBar: false);
  }
}

class _ExtractedPane extends StatefulWidget {
  const _ExtractedPane({required this.repository});

  final KnowledgeDocumentRepository? repository;

  @override
  State<_ExtractedPane> createState() => _ExtractedPaneState();
}

class _ExtractedPaneState extends State<_ExtractedPane> {
  Future<List<_FlowchartDocumentSummary>>? _summariesFuture;
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
    return FutureBuilder<List<_FlowchartDocumentSummary>>(
      future: _summariesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <_FlowchartDocumentSummary>[];
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nincs kinyert flowchart a tudástárban.',
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
                subtitle: Text('${item.flowchartCount} kinyert flowchart elem'),
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

  Future<List<_FlowchartDocumentSummary>> _loadSummaries(
    KnowledgeDocumentRepository repository,
  ) async {
    final documents = await repository.listDocuments();
    final summaries = <_FlowchartDocumentSummary>[];
    for (final document in documents) {
      final items = await repository.listExtractedKnowledgeItems(document.id);
      final count = items.where((item) {
        return item.sourceType == EvidenceSourceType.flowchartNode ||
            item.sourceType == EvidenceSourceType.flowchartEdge;
      }).length;
      if (count > 0) {
        summaries.add(
          _FlowchartDocumentSummary(document: document, flowchartCount: count),
        );
      }
    }
    return summaries;
  }
}

class _FlowchartDocumentSummary {
  const _FlowchartDocumentSummary({
    required this.document,
    required this.flowchartCount,
  });

  final KnowledgeDocument document;
  final int flowchartCount;
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
