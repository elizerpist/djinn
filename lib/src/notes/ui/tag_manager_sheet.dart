import 'package:flutter/material.dart';

import '../models/note_document.dart';

Future<List<NoteKnowledgeTag>?> showTagManagerSheet(
  BuildContext context, {
  required List<NoteKnowledgeTag> initialTags,
  List<NoteKnowledgeTag> availableTags = const [],
  bool singleSelection = false,
  String title = 'Tagek',
}) {
  return showModalBottomSheet<List<NoteKnowledgeTag>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TagManagerSheet(
      initialTags: initialTags,
      availableTags: availableTags,
      singleSelection: singleSelection,
      title: title,
    ),
  );
}

class _TagManagerSheet extends StatefulWidget {
  const _TagManagerSheet({
    required this.initialTags,
    required this.availableTags,
    required this.singleSelection,
    required this.title,
  });

  final List<NoteKnowledgeTag> initialTags;
  final List<NoteKnowledgeTag> availableTags;
  final bool singleSelection;
  final String title;

  @override
  State<_TagManagerSheet> createState() => _TagManagerSheetState();
}

class _TagManagerSheetState extends State<_TagManagerSheet> {
  static final Map<String, NoteKnowledgeTag> _registry = <String, NoteKnowledgeTag>{};

  late List<NoteKnowledgeTag> _tags;
  late List<NoteKnowledgeTag> _availableTags;
  late final TextEditingController _labelController;
  String _type = NoteKnowledgeTagTypes.topic;
  int _colorValue = noteTagColorSlots.first;
  String? _editingKey;

  @override
  void initState() {
    super.initState();
    _tags = [...widget.initialTags];
    for (final tag in [...widget.availableTags, ...widget.initialTags]) {
      _rememberTag(tag);
    }
    _availableTags = _sortedRegisteredTags();
    _labelController = TextEditingController();
    if (_tags.isNotEmpty) {
      _type = NoteKnowledgeTagTypes.normalize(_tags.last.type);
      _colorValue = _tags.last.resolvedColorValue;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _addTag() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      return;
    }
    final tag = NoteKnowledgeTag(
      type: _type,
      label: label,
      colorValue: _colorValue,
    );
    final editedKey = _editingKey;
    if (editedKey != null) {
      _registry.remove(editedKey);
    }
    _rememberTag(tag);
    setState(() {
      _availableTags = _sortedRegisteredTags();
      if (widget.singleSelection) {
        _tags = [tag];
      } else {
        _tags = [
          ..._tags.where((existing) => existing.metadataText != tag.metadataText && existing.metadataText != editedKey),
          tag,
        ];
      }
      _labelController.clear();
      _editingKey = null;
    });
  }

  void _removeTag(NoteKnowledgeTag tag) {
    setState(() {
      _tags = _tags
          .where((existing) => existing.metadataText != tag.metadataText)
          .toList(growable: false);
    });
  }

  void _toggleAvailableTag(NoteKnowledgeTag tag, bool selected) {
    setState(() {
      if (widget.singleSelection) {
        _tags = selected ? [tag] : const [];
        return;
      }
      if (selected) {
        _tags = [
          ..._tags.where((existing) => existing.metadataText != tag.metadataText),
          tag,
        ];
      } else {
        _tags = _tags.where((existing) => existing.metadataText != tag.metadataText).toList(growable: false);
      }
    });
  }

  void _editTag(NoteKnowledgeTag tag) {
    setState(() {
      _editingKey = tag.metadataText;
      _type = NoteKnowledgeTagTypes.normalize(tag.type);
      _colorValue = tag.resolvedColorValue;
      _labelController.text = tag.label;
      _labelController.selection = TextSelection.collapsed(offset: _labelController.text.length);
    });
  }

  void _deleteAvailableTag(NoteKnowledgeTag tag) {
    setState(() {
      _registry.remove(tag.metadataText);
      _availableTags = _sortedRegisteredTags();
      _tags = _tags.where((existing) => existing.metadataText != tag.metadataText).toList(growable: false);
      if (_editingKey == tag.metadataText) {
        _editingKey = null;
        _labelController.clear();
      }
    });
  }

  bool _isSelected(NoteKnowledgeTag tag) {
    return _tags.any((selected) => selected.metadataText == tag.metadataText);
  }

  static void _rememberTag(NoteKnowledgeTag tag) {
    if (tag.metadataText.isEmpty) {
      return;
    }
    _registry[tag.metadataText] = tag;
  }

  static List<NoteKnowledgeTag> _sortedRegisteredTags() {
    final tags = _registry.values.toList(growable: false);
    tags.sort((a, b) => a.metadataText.compareTo(b.metadataText));
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      key: const ValueKey('tag-manager-sheet'),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Bezárás',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _tags)
                  InputChip(
                    key: ValueKey('tag-chip-${tag.metadataText}'),
                    avatar: CircleAvatar(backgroundColor: Color(tag.resolvedColorValue)),
                    label: Text(tag.metadataText),
                    onDeleted: () => _removeTag(tag),
                  ),
              ],
            ),
            if (_availableTags.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Mentett tagek',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _availableTags)
                    _SavedTagChip(
                      key: ValueKey('tag-saved-chip-${tag.metadataText}'),
                      tag: tag,
                      selected: _isSelected(tag),
                      onSelected: (selected) => _toggleAvailableTag(tag, selected),
                      onEdit: () => _editTag(tag),
                      onDelete: () => _deleteAvailableTag(tag),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('tag-manager-type'),
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Típus',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final type in NoteKnowledgeTagTypes.values)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = NoteKnowledgeTagTypes.normalize(value));
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('tag-manager-name'),
              controller: _labelController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Név',
                hintText: 'pl. légzési elégtelenség, súlyos, terápia',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addTag(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var index = 0; index < noteTagColorSlots.length; index++)
                  _ColorSlotButton(
                    key: ValueKey('tag-color-slot-$index'),
                    colorValue: noteTagColorSlots[index],
                    selected: _colorValue == noteTagColorSlots[index],
                    onTap: () => setState(() => _colorValue = noteTagColorSlots[index]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('tag-manager-add'),
                    onPressed: _addTag,
                    icon: const Icon(Icons.add),
                    label: Text(_editingKey == null ? 'Hozzáadás' : 'Frissítés'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('tag-manager-save'),
                    onPressed: () => Navigator.of(context).pop(_tags),
                    icon: const Icon(Icons.check),
                    label: const Text('Mentés'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSlotButton extends StatelessWidget {
  const _ColorSlotButton({
    super.key,
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
      ),
    );
  }
}

class _SavedTagChip extends StatelessWidget {
  const _SavedTagChip({
    super.key,
    required this.tag,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final NoteKnowledgeTag tag;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? Color(tag.resolvedColorValue).withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilterChip(
            avatar: CircleAvatar(backgroundColor: Color(tag.resolvedColorValue)),
            label: Text(tag.metadataText),
            selected: selected,
            onSelected: onSelected,
          ),
          IconButton(
            tooltip: 'Tag szerkesztése',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
          ),
          IconButton(
            tooltip: 'Tag törlése',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }
}
