import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tag_repository.dart';
import '../models/note_document.dart';
import '../models/note_tag_registry.dart';

const _allFolderFilter = '__all__';
const _unfiledFolderFilter = '__unfiled__';

Future<List<NoteKnowledgeTag>?> showTagManagerSheet(
  BuildContext context, {
  required List<NoteKnowledgeTag> initialTags,
  TagRepository? tagRepository,
  ValueChanged<List<NoteKnowledgeTag>>? onChanged,
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
      tagRepository: tagRepository ?? MemoryTagRepository(),
      onChanged: onChanged,
      singleSelection: singleSelection,
      title: title,
    ),
  );
}

class _TagManagerSheet extends StatefulWidget {
  const _TagManagerSheet({
    required this.initialTags,
    required this.availableTags,
    required this.tagRepository,
    required this.onChanged,
    required this.singleSelection,
    required this.title,
  });

  final List<NoteKnowledgeTag> initialTags;
  final List<NoteKnowledgeTag> availableTags;
  final TagRepository tagRepository;
  final ValueChanged<List<NoteKnowledgeTag>>? onChanged;
  final bool singleSelection;
  final String title;

  @override
  State<_TagManagerSheet> createState() => _TagManagerSheetState();
}

class _TagManagerSheetState extends State<_TagManagerSheet> {
  late final TextEditingController _labelController;
  List<NoteKnowledgeTag> _selectedTags = const [];
  List<NoteTagDefinition> _registryTags = const [];
  List<NoteTagFolder> _folders = const [];
  String _folderFilter = _allFolderFilter;
  int _colorSlotId = 0;
  String? _editingTagId;
  bool _creatingFolder = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    unawaited(_load());
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await widget.tagRepository.rememberEmbeddedTags(widget.availableTags);
    final selected = await widget.tagRepository.rememberEmbeddedTags(
      widget.initialTags,
    );
    final tags = await widget.tagRepository.listTags();
    final folders = await widget.tagRepository.listFolders();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTags = selected;
      _registryTags = tags;
      _folders = folders;
      _colorSlotId = _nextUnusedColorSlotId();
      _loading = false;
    });
  }

  Future<void> _refreshRegistry() async {
    final tags = await widget.tagRepository.listTags();
    final folders = await widget.tagRepository.listFolders();
    if (!mounted) {
      return;
    }
    setState(() {
      _registryTags = tags;
      _folders = folders;
      if (_folderFilter != _allFolderFilter &&
          _folderFilter != _unfiledFolderFilter &&
          !_folders.any((folder) => folder.id == _folderFilter)) {
        _folderFilter = _allFolderFilter;
      }
    });
  }

  void _emitSelection() {
    widget.onChanged?.call(List.unmodifiable(_selectedTags));
  }

  bool _isSelected(NoteTagDefinition tag) {
    return _selectedTags.any((selected) => _sameTag(selected, tag));
  }

  bool _sameTag(NoteKnowledgeTag selected, NoteTagDefinition tag) {
    final selectedId = selected.id?.trim();
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId == tag.id;
    }
    return normalizeNoteTagLabel(selected.label) == tag.normalizedLabel;
  }

  void _toggleTag(NoteTagDefinition tag) {
    final selected = _isSelected(tag);
    setState(() {
      if (selected) {
        _selectedTags = _selectedTags
            .where((existing) => !_sameTag(existing, tag))
            .toList(growable: false);
      } else if (widget.singleSelection) {
        _selectedTags = [tag.toKnowledgeTag()];
      } else {
        _selectedTags = [
          ..._selectedTags.where((existing) => !_sameTag(existing, tag)),
          tag.toKnowledgeTag(),
        ];
      }
    });
    _emitSelection();
  }

  Future<void> _addOrUpdateTag() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      return;
    }
    if (_creatingFolder) {
      final folder = await widget.tagRepository.createFolder(label);
      await _refreshRegistry();
      if (!mounted) {
        return;
      }
      setState(() {
        _folderFilter = folder.id;
        _creatingFolder = false;
        _labelController.clear();
      });
      return;
    }
    final folderId = _newTagFolderId;
    final definition = await widget.tagRepository.upsertTag(
      id: _editingTagId,
      label: label,
      colorSlotId: _colorSlotId,
      folderId: folderId,
    );
    await _refreshRegistry();
    if (!mounted) {
      return;
    }
    setState(() {
      final asTag = definition.toKnowledgeTag();
      if (widget.singleSelection) {
        _selectedTags = [asTag];
      } else {
        _selectedTags = [
          ..._selectedTags.where((existing) => !_sameTag(existing, definition)),
          asTag,
        ];
      }
      _labelController.clear();
      _editingTagId = null;
      _creatingFolder = false;
      _colorSlotId = _nextUnusedColorSlotId();
    });
    _emitSelection();
  }

  String? get _newTagFolderId {
    if (_folderFilter == _allFolderFilter ||
        _folderFilter == _unfiledFolderFilter) {
      return null;
    }
    return _folderFilter;
  }

  void _editTag(NoteTagDefinition tag) {
    setState(() {
      _creatingFolder = false;
      _editingTagId = tag.id;
      _labelController.text = tag.label;
      _labelController.selection = TextSelection.collapsed(
        offset: _labelController.text.length,
      );
      _colorSlotId = tag.colorSlotId;
    });
  }

  Future<void> _deleteTag(NoteTagDefinition tag) async {
    await widget.tagRepository.deleteTag(tag.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTags = _selectedTags
          .where((selected) => !_sameTag(selected, tag))
          .toList(growable: false);
      if (_editingTagId == tag.id) {
        _editingTagId = null;
        _labelController.clear();
      }
    });
    _emitSelection();
    await _refreshRegistry();
  }

  Future<void> _createFolder() async {
    setState(() {
      _creatingFolder = true;
      _editingTagId = null;
      _labelController.clear();
    });
  }

  Future<void> _moveTagToFolder(NoteTagDefinition tag, String? folderId) async {
    final updated = await widget.tagRepository.setTagFolder(tag.id, folderId);
    await _refreshRegistry();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedTags = [
        for (final selected in _selectedTags)
          if (_sameTag(selected, tag)) updated.toKnowledgeTag() else selected,
      ];
    });
    _emitSelection();
  }

  int _nextUnusedColorSlotId() {
    final used = {
      for (final tag in _registryTags) tag.colorSlotId,
      for (final tag in _selectedTags)
        tag.colorSlotId ??
            noteTagColorSlotIdForValue(tag.colorValue, fallback: 0),
    };
    for (var index = 0; index < noteTagColorSlots.length; index += 1) {
      if (!used.contains(index)) {
        return index;
      }
    }
    return _registryTags.length % noteTagColorSlots.length;
  }

  List<NoteTagDefinition> get _filteredTags {
    return _registryTags
        .where((tag) {
          if (_folderFilter == _allFolderFilter) {
            return true;
          }
          if (_folderFilter == _unfiledFolderFilter) {
            return tag.folderId == null || tag.folderId!.trim().isEmpty;
          }
          return tag.folderId == _folderFilter;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final sheetMaxHeight = mediaQuery.size.height - mediaQuery.padding.top - 8;
    final visibleHeight = sheetMaxHeight - mediaQuery.viewInsets.bottom;
    final minHeight = sheetMaxHeight < 120 ? sheetMaxHeight : 120.0;
    final maxHeight = visibleHeight.clamp(minHeight, sheetMaxHeight).toDouble();
    final pillMaxHeight = (maxHeight - 260).clamp(72.0, maxHeight).toDouble();
    return Padding(
      key: const ValueKey('tag-manager-sheet'),
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('tag-manager-close'),
                      onPressed: () => Navigator.of(context).pop(_selectedTags),
                      icon: const Icon(Icons.close),
                      tooltip: 'Bezárás',
                    ),
                  ],
                ),
              ),
              _FolderBar(
                folders: _folders,
                selectedFilter: _folderFilter,
                onSelected: (value) => setState(() => _folderFilter = value),
                onCreateFolder: _createFolder,
                onMoveTag: _moveTagToFolder,
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: pillMaxHeight),
                child: _loading
                    ? const SizedBox(
                        height: 96,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SingleChildScrollView(
                        key: const ValueKey('tag-manager-pill-scroll'),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Wrap(
                          key: const ValueKey('tag-manager-pill-area'),
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in _filteredTags)
                              _TagPill(
                                key: ValueKey('tag-pill-${tag.id}'),
                                tag: tag,
                                selected: _isSelected(tag),
                                onSelected: () => _toggleTag(tag),
                                onEdit: () => _editTag(tag),
                                onDelete: () => unawaited(_deleteTag(tag)),
                              ),
                          ],
                        ),
                      ),
              ),
              const Divider(height: 1),
              _TagEditor(
                labelController: _labelController,
                colorSlotId: _colorSlotId,
                editing: _editingTagId != null,
                creatingFolder: _creatingFolder,
                onColorChanged: (value) => setState(() => _colorSlotId = value),
                onSubmit: _addOrUpdateTag,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({
    required this.folders,
    required this.selectedFilter,
    required this.onSelected,
    required this.onCreateFolder,
    required this.onMoveTag,
  });

  final List<NoteTagFolder> folders;
  final String selectedFilter;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreateFolder;
  final Future<void> Function(NoteTagDefinition tag, String? folderId)
  onMoveTag;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('tag-folder-bar'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          _FolderChip(
            key: const ValueKey('tag-folder-all'),
            label: 'Összes',
            selected: selectedFilter == _allFolderFilter,
            onTap: () => onSelected(_allFolderFilter),
          ),
          const SizedBox(width: 8),
          _FolderChip(
            key: const ValueKey('tag-folder-none'),
            label: 'Mappa nélkül',
            selected: selectedFilter == _unfiledFolderFilter,
            onTap: () => onSelected(_unfiledFolderFilter),
            onAcceptTag: (tag) => onMoveTag(tag, null),
          ),
          const SizedBox(width: 8),
          _FolderChip(
            key: const ValueKey('tag-folder-add'),
            label: 'Új mappa',
            selected: false,
            icon: Icons.add,
            onTap: onCreateFolder,
          ),
          for (final folder in folders) ...[
            const SizedBox(width: 8),
            _FolderChip(
              key: ValueKey('tag-folder-${folder.id}'),
              label: folder.label,
              selected: selectedFilter == folder.id,
              onTap: () => onSelected(folder.id),
              onAcceptTag: (tag) => onMoveTag(tag, folder.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onAcceptTag,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Future<void> Function(NoteTagDefinition tag)? onAcceptTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = ActionChip(
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
      ),
      onPressed: onTap,
    );
    final accept = onAcceptTag;
    if (accept == null) {
      return chip;
    }
    return DragTarget<NoteTagDefinition>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => unawaited(accept(details.data)),
      builder: (context, candidateData, rejectedData) {
        if (candidateData.isEmpty) {
          return chip;
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: chip,
        );
      },
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    super.key,
    required this.tag,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final NoteTagDefinition tag;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.colorValue);
    final opacity = selected ? 1.0 : 0.42;
    final pill = Opacity(
      opacity: opacity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    tag.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _PillIconButton(
                  key: ValueKey('tag-pill-edit-${tag.id}'),
                  icon: Icons.edit,
                  tooltip: 'Szerkesztés',
                  onTap: onEdit,
                ),
                _PillIconButton(
                  key: ValueKey('tag-pill-delete-${tag.id}'),
                  icon: Icons.close,
                  tooltip: 'Törlés',
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return LongPressDraggable<NoteTagDefinition>(
      data: tag,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.04, child: pill),
      ),
      childWhenDragging: Opacity(opacity: 0.2, child: pill),
      child: pill,
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 14,
        onTap: onTap,
        child: Icon(icon, size: 15, color: Colors.white),
      ),
    );
  }
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.labelController,
    required this.colorSlotId,
    required this.editing,
    required this.creatingFolder,
    required this.onColorChanged,
    required this.onSubmit,
  });

  final TextEditingController labelController;
  final int colorSlotId;
  final bool editing;
  final bool creatingFolder;
  final ValueChanged<int> onColorChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(
        creatingFolder ? 'tag-folder-create-mode' : 'tag-manager-editor',
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('tag-manager-name'),
            controller: labelController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: creatingFolder ? 'Mappa neve' : 'Név',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => unawaited(onSubmit()),
          ),
          const SizedBox(height: 10),
          if (!creatingFolder) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var index = 0; index < noteTagColorSlots.length; index++)
                  _ColorSlotButton(
                    key: ValueKey('tag-color-slot-$index'),
                    colorValue: noteTagColorSlots[index],
                    selected: colorSlotId == index,
                    onTap: () => onColorChanged(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const ValueKey('tag-manager-add'),
            onPressed: () => unawaited(onSubmit()),
            icon: Icon(editing || creatingFolder ? Icons.check : Icons.add),
            label: Text(
              creatingFolder
                  ? 'Mappa létrehozása'
                  : editing
                  ? 'Tag frissítése'
                  : 'Új tag hozzáadása',
            ),
          ),
        ],
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
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
