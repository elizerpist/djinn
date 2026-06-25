import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../models/note_document.dart';
import 'note_flowchart_editor_screen.dart';
import 'note_table_editor_screen.dart';

class NoteDocumentEditorResult {
  const NoteDocumentEditorResult({required this.title, required this.document});

  final String title;
  final NoteDocument document;
}

class NoteDocumentEditorScreen extends StatefulWidget {
  const NoteDocumentEditorScreen({
    super.key,
    required this.title,
    required this.document,
  });

  final String title;
  final NoteDocument document;

  @override
  State<NoteDocumentEditorScreen> createState() =>
      _NoteDocumentEditorScreenState();
}

class _NoteDocumentEditorScreenState extends State<NoteDocumentEditorScreen> {
  late final TextEditingController _titleController;
  late List<NoteBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _blocks = widget.document.blocks.isEmpty
        ? NoteDocument.empty().blocks.toList()
        : widget.document.blocks.toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _nextBlockId() {
    var index = _blocks.length + 1;
    while (_blocks.any((block) => block.id == 'block-$index')) {
      index += 1;
    }
    return 'block-$index';
  }

  void _replaceBlock(NoteBlock block) {
    setState(() {
      _blocks = [
        for (final current in _blocks)
          if (current.id == block.id) block else current,
      ];
    });
  }

  void _deleteBlock(NoteBlock block) {
    if (_blocks.length == 1) {
      _replaceBlock(
        block.copyWith(
          text: '',
          rows: const [],
          nodes: const [],
          edges: const [],
        ),
      );
      return;
    }
    setState(() => _blocks.removeWhere((item) => item.id == block.id));
  }

  void _moveBlock(NoteBlock block, int delta) {
    final index = _blocks.indexWhere((item) => item.id == block.id);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _blocks.length) {
      return;
    }
    setState(() {
      final next = [..._blocks];
      final item = next.removeAt(index);
      next.insert(target, item);
      _blocks = next;
    });
  }

  void _addTextBlock() {
    setState(() {
      _blocks.add(NoteBlock(id: _nextBlockId(), type: NoteBlockType.paragraph));
    });
  }

  void _addListBlock() {
    setState(() {
      _blocks.add(NoteBlock(id: _nextBlockId(), type: NoteBlockType.listItem));
    });
  }

  void _addMixedBlock() {
    setState(() {
      _blocks.add(
        NoteBlock(
          id: _nextBlockId(),
          type: NoteBlockType.mixed,
          mixedSections: const [
            NoteMixedSection(
              id: 'section-1',
              type: NoteMixedSectionType.paragraph,
              text: '',
            ),
          ],
        ),
      );
    });
  }

  Future<void> _addTableBlock() async {
    final block = NoteBlock(
      id: _nextBlockId(),
      type: NoteBlockType.table,
      rows: const [
        ['', ''],
      ],
    );
    final edited = await Navigator.of(context).push<NoteBlock>(
      MaterialPageRoute(builder: (_) => NoteTableEditorScreen(block: block)),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() => _blocks.add(edited));
  }

  Future<void> _addFlowchartBlock() async {
    final block = NoteBlock(
      id: _nextBlockId(),
      type: NoteBlockType.flowchart,
      title: 'Flowchart',
      nodes: const [
        NoteFlowchartNode(
          id: 'node-1',
          label: 'Kezdés',
          shape: AiFlowchartNodeShape.startEnd,
          order: 1,
        ),
        NoteFlowchartNode(
          id: 'node-2',
          label: 'Döntés?',
          shape: AiFlowchartNodeShape.decision,
          order: 2,
        ),
      ],
      edges: const [
        NoteFlowchartEdge(
          id: 'edge-1',
          fromNodeId: 'node-1',
          toNodeId: 'node-2',
          label: '',
          order: 1,
        ),
      ],
    );
    final edited = await Navigator.of(context).push<NoteBlock>(
      MaterialPageRoute(
        builder: (_) => NoteFlowchartEditorScreen(block: block),
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() => _blocks.add(edited));
  }

  Future<void> _editTableBlock(NoteBlock block) async {
    final edited = await Navigator.of(context).push<NoteBlock>(
      MaterialPageRoute(builder: (_) => NoteTableEditorScreen(block: block)),
    );
    if (edited != null && mounted) {
      _replaceBlock(edited);
    }
  }

  Future<void> _editFlowchartBlock(NoteBlock block) async {
    final edited = await Navigator.of(context).push<NoteBlock>(
      MaterialPageRoute(
        builder: (_) => NoteFlowchartEditorScreen(block: block),
      ),
    );
    if (edited != null && mounted) {
      _replaceBlock(edited);
    }
  }

  void _changeIndent(NoteBlock block, int delta) {
    final nextLevel = (block.level + delta).clamp(0, 4).toInt();
    _replaceBlock(block.copyWith(level: nextLevel));
  }

  void _save() {
    final normalizedBlocks = _blocks
        .where(
          (block) =>
              block.plainText.trim().isNotEmpty ||
              block.type == NoteBlockType.paragraph,
        )
        .toList(growable: false);
    Navigator.of(context).pop(
      NoteDocumentEditorResult(
        title: _titleController.text.trim(),
        document: NoteDocument(
          tags: widget.document.tags,
          blocks: normalizedBlocks.isEmpty
              ? NoteDocument.empty().blocks
              : normalizedBlocks,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jegyzet szerkesztő'),
        actions: [
          TextButton.icon(
            key: const ValueKey('note-document-save'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Mentés'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        children: [
          TextField(
            key: const ValueKey('note-document-title-field'),
            controller: _titleController,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              labelText: 'Cím',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          for (final block in _blocks) ...[
            _BlockEditorCard(
              block: block,
              inheritedTags: widget.document.tags,
              onChanged: _replaceBlock,
              onDelete: () => _deleteBlock(block),
              onMoveUp: () => _moveBlock(block, -1),
              onMoveDown: () => _moveBlock(block, 1),
              onIndent: () => _changeIndent(block, 1),
              onOutdent: () => _changeIndent(block, -1),
              onEditTable: () => _editTableBlock(block),
              onEditFlowchart: () => _editFlowchartBlock(block),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          elevation: 8,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('note-document-add-text'),
                  onPressed: _addTextBlock,
                  icon: const Icon(Icons.subject),
                  label: const Text('Szöveg'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('note-document-add-list'),
                  onPressed: _addListBlock,
                  icon: const Icon(Icons.format_list_bulleted),
                  label: const Text('Lista'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('note-document-add-table'),
                  onPressed: _addTableBlock,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Táblázat'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('note-document-add-flowchart'),
                  onPressed: _addFlowchartBlock,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Flowchart'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('note-document-add-mixed'),
                  onPressed: _addMixedBlock,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Kevert'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockEditorCard extends StatefulWidget {
  const _BlockEditorCard({
    required this.block,
    required this.inheritedTags,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onIndent,
    required this.onOutdent,
    required this.onEditTable,
    required this.onEditFlowchart,
  });

  final NoteBlock block;
  final List<NoteKnowledgeTag> inheritedTags;
  final ValueChanged<NoteBlock> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final VoidCallback onEditTable;
  final VoidCallback onEditFlowchart;

  @override
  State<_BlockEditorCard> createState() => _BlockEditorCardState();
}

class _BlockEditorCardState extends State<_BlockEditorCard> {
  final TextEditingController _tagLabelController = TextEditingController();
  String _selectedTagType = NoteKnowledgeTagTypes.topic;

  NoteBlock get block => widget.block;

  ValueChanged<NoteBlock> get onChanged => widget.onChanged;
  VoidCallback get onDelete => widget.onDelete;
  VoidCallback get onMoveUp => widget.onMoveUp;
  VoidCallback get onMoveDown => widget.onMoveDown;
  VoidCallback get onIndent => widget.onIndent;
  VoidCallback get onOutdent => widget.onOutdent;
  VoidCallback get onEditTable => widget.onEditTable;
  VoidCallback get onEditFlowchart => widget.onEditFlowchart;

  @override
  void dispose() {
    _tagLabelController.dispose();
    super.dispose();
  }

  void _addTypedTag() {
    final label = _tagLabelController.text.trim();
    if (label.isEmpty) {
      return;
    }
    final tagSeed = NoteKnowledgeTag(type: _selectedTagType, label: label);
    final tag = NoteKnowledgeTag(
      type: _selectedTagType,
      label: label,
      colorValue: tagSeed.resolvedColorValue,
    );
    onChanged(block.copyWith(tags: [...block.tags, tag], clearIndex: true));
    _tagLabelController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.only(left: block.level * 18.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(_iconFor(block.type), color: const Color(0xFF155EEF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _labelFor(block.type),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kihúzás',
                    onPressed: onOutdent,
                    icon: const Icon(Icons.format_indent_decrease),
                  ),
                  IconButton(
                    tooltip: 'Behúzás',
                    onPressed: onIndent,
                    icon: const Icon(Icons.format_indent_increase),
                  ),
                  IconButton(
                    tooltip: 'Fel',
                    onPressed: onMoveUp,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Le',
                    onPressed: onMoveDown,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    tooltip: 'Törlés',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _body(context),
              const SizedBox(height: 10),
              _searchMetadataFields(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (block.type) {
      case NoteBlockType.heading:
      case NoteBlockType.paragraph:
      case NoteBlockType.listItem:
        return TextFormField(
          key: ValueKey('note-document-block-${block.id}'),
          initialValue: block.text,
          minLines: block.type == NoteBlockType.paragraph ? 3 : 1,
          maxLines: block.type == NoteBlockType.paragraph ? 8 : 3,
          decoration: InputDecoration(
            prefixText: block.type == NoteBlockType.listItem ? '• ' : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) =>
              onChanged(block.copyWith(text: value, clearIndex: true)),
        );
      case NoteBlockType.mixed:
        return _StructuredPreview(text: block.plainText);
      case NoteBlockType.table:
        return _StructuredPreview(
          text: block.plainText,
          buttonLabel: 'Táblázat szerkesztése',
          onPressed: onEditTable,
        );
      case NoteBlockType.flowchart:
        return _StructuredPreview(
          text: block.plainText,
          buttonLabel: 'Flowchart szerkesztése',
          onPressed: onEditFlowchart,
        );
    }
  }

  Widget _searchMetadataFields(BuildContext context) {
    final warning = _searchWarning();
    final contextField = TextFormField(
      key: ValueKey('note-block-search-context-${block.id}'),
      initialValue: block.searchContext ?? '',
      decoration: const InputDecoration(
        labelText: 'Keresési kontextus',
        hintText: 'pl. légzési elégtelenség',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => onChanged(
        block.copyWith(searchContext: value.trim(), clearIndex: true),
      ),
    );
    final roleField = DropdownButtonFormField<String>(
      key: ValueKey('note-block-search-role-${block.id}'),
      initialValue: NoteSearchRoles.normalize(block.searchRole),
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tudástípus',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final role in NoteSearchRoles.values)
          DropdownMenuItem(
            value: role,
            child: Text(NoteSearchRoles.label(role)),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(block.copyWith(searchRole: value, clearIndex: true));
        }
      },
    );
    final searchBasics = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [contextField, const SizedBox(height: 8), roleField],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: contextField),
            const SizedBox(width: 8),
            SizedBox(width: 240, child: roleField),
          ],
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchMetadataTagSummary(context),
        const SizedBox(height: 8),
        searchBasics,
        const SizedBox(height: 8),
        _typedTagEditor(),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('note-block-search-aliases-${block.id}'),
          initialValue: block.searchAliases.join(', '),
          decoration: const InputDecoration(
            labelText: 'Tagek / aliasok / szimbólumok',
            hintText: 'pl. légzési elégtelenség, terápia, DO2, VO2',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => onChanged(
            block.copyWith(
              searchAliases: value
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false),
              clearIndex: true,
            ),
          ),
        ),
        if (warning != null) ...[
          const SizedBox(height: 8),
          Text(
            warning,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF92400E)),
          ),
        ],
      ],
    );
  }

  Widget _searchMetadataTagSummary(BuildContext context) {
    final chips = <Widget>[];
    final contextValue = block.searchContext?.trim();
    if (contextValue != null && contextValue.isNotEmpty) {
      chips.add(_metadataChip('Kontextus: $contextValue'));
    }
    final role = NoteSearchRoles.normalize(block.searchRole);
    if (role != NoteSearchRoles.none && role != NoteSearchRoles.ignore) {
      chips.add(_metadataChip('Tudástípus: ${NoteSearchRoles.label(role)}'));
    }
    for (final alias in block.searchAliases) {
      final tag = alias.trim();
      if (tag.isNotEmpty) {
        chips.add(_metadataChip('Tag: $tag'));
      }
    }
    for (final tag in block.tags) {
      final label = tag.label.trim();
      if (label.isNotEmpty) {
        chips.add(
          _metadataChip(
            'Tag: ${NoteKnowledgeTagTypes.normalize(tag.type)} $label',
            color: Color(tag.resolvedColorValue),
          ),
        );
      }
    }
    final directTagKeys = {
      for (final tag in block.tags)
        '${NoteKnowledgeTagTypes.normalize(tag.type)}:${tag.label.trim().toLowerCase()}',
    };
    for (final tag in widget.inheritedTags) {
      final label = tag.label.trim();
      final key =
          '${NoteKnowledgeTagTypes.normalize(tag.type)}:${label.toLowerCase()}';
      if (label.isNotEmpty && !directTagKeys.contains(key)) {
        chips.add(
          _metadataChip(
            'Örökölt tag: ${NoteKnowledgeTagTypes.normalize(tag.type)} $label',
            color: Color(tag.resolvedColorValue),
          ),
        );
      }
    }
    if (chips.isEmpty) {
      chips.add(_metadataChip('Nincs keresési metadata'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keresési metadata / tagek',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  Widget _typedTagEditor() {
    final typeField = DropdownButtonFormField<String>(
      key: ValueKey('note-block-tag-type-${block.id}'),
      initialValue: _selectedTagType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tag típus',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final type in NoteKnowledgeTagTypes.values)
          DropdownMenuItem(value: type, child: Text(type)),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedTagType = value);
        }
      },
    );
    final labelField = TextField(
      key: ValueKey('note-block-tag-label-${block.id}'),
      controller: _tagLabelController,
      decoration: const InputDecoration(
        labelText: 'Tag',
        hintText: 'pl. súlyos, terápia, oxygen',
        border: OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _addTypedTag(),
    );
    final addButton = IconButton.filledTonal(
      key: ValueKey('note-block-tag-add-${block.id}'),
      tooltip: 'Tag hozzáadása',
      onPressed: _addTypedTag,
      icon: const Icon(Icons.add),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: typeField),
              const SizedBox(height: 8),
              labelField,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: addButton),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 176, child: typeField),
            const SizedBox(width: 8),
            Expanded(child: labelField),
            const SizedBox(width: 8),
            addButton,
          ],
        );
      },
    );
  }

  Widget _metadataChip(String label, {Color? color}) {
    final chipColor = color ?? const Color(0xFF64748B);
    return Chip(
      label: Text(label),
      backgroundColor: chipColor.withValues(alpha: 0.11),
      labelStyle: TextStyle(color: chipColor, fontWeight: FontWeight.w700),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String? _searchWarning() {
    final title = block.title?.trim().toLowerCase();
    const genericTitles = {
      'magyarázat',
      'magyarazat',
      'jegyzet',
      'szöveg',
      'szoveg',
      'lista',
      'táblázat',
      'tablazat',
      'flowchart',
    };
    if (title != null &&
        title.isNotEmpty &&
        genericTitles.contains(title) &&
        (block.searchContext == null || block.searchContext!.trim().isEmpty)) {
      return 'A cím kereséshez túl általános. Adj keresési kontextust.';
    }
    final normalized = block.plainText.toLowerCase();
    final mixedSignals = [
      normalized.contains('do2') || normalized.contains('vo2'),
      normalized.contains('bolognai'),
      normalized.contains('légzési') || normalized.contains('legzesi'),
    ].where((item) => item).length;
    if (mixedSignals >= 2 &&
        (block.searchContext == null || block.searchContext!.trim().isEmpty)) {
      return 'Ez a blokk több témát keverhet. Offline kereséshez bontsd külön blokkokra vagy adj kontextust.';
    }
    return null;
  }

  IconData _iconFor(NoteBlockType type) {
    return switch (type) {
      NoteBlockType.heading => Icons.title,
      NoteBlockType.paragraph => Icons.subject,
      NoteBlockType.mixed => Icons.subject,
      NoteBlockType.listItem => Icons.format_list_bulleted,
      NoteBlockType.table => Icons.table_chart_outlined,
      NoteBlockType.flowchart => Icons.account_tree_outlined,
    };
  }

  String _labelFor(NoteBlockType type) {
    return switch (type) {
      NoteBlockType.heading => 'Cím',
      NoteBlockType.paragraph => 'Szöveg',
      NoteBlockType.mixed => 'Szöveg',
      NoteBlockType.listItem => 'Vázlatpont',
      NoteBlockType.table => 'Táblázat',
      NoteBlockType.flowchart => 'Flowchart',
    };
  }
}

class _StructuredPreview extends StatelessWidget {
  const _StructuredPreview({
    required this.text,
    this.buttonLabel,
    this.onPressed,
  });

  final String text;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              text.trim().isEmpty ? 'Nincs tartalom' : text,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (buttonLabel != null && onPressed != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.open_in_full),
            label: Text(buttonLabel!),
          ),
        ],
      ],
    );
  }
}
