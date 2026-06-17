import 'package:flutter/material.dart';

class NoteChunkEditorHeader extends StatelessWidget implements PreferredSizeWidget {
  const NoteChunkEditorHeader({
    super.key,
    required this.title,
    required this.fallbackTitle,
    required this.onTitleChanged,
    required this.onTagChunk,
    required this.onTagSelection,
    required this.onDeleteSelectedTag,
    required this.onDeleteChunk,
    this.canDeleteSelectedTag = false,
    this.trailingActions = const [],
    this.saveAction,
  });

  final String? title;
  final String fallbackTitle;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onTagChunk;
  final VoidCallback onTagSelection;
  final VoidCallback onDeleteSelectedTag;
  final VoidCallback onDeleteChunk;
  final bool canDeleteSelectedTag;
  final List<Widget> trailingActions;
  final Widget? saveAction;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 12,
      title: TextFormField(
        key: const ValueKey('note-chunk-title-field'),
        initialValue: title?.trim().isNotEmpty == true ? title!.trim() : fallbackTitle,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
        textInputAction: TextInputAction.done,
        onChanged: onTitleChanged,
      ),
      actions: [
        IconButton(
          key: const ValueKey('note-chunk-global-tag'),
          tooltip: 'Chunk tagelése',
          onPressed: onTagChunk,
          icon: const Icon(Icons.sell_outlined),
        ),
        ...trailingActions,
        PopupMenuButton<String>(
          key: const ValueKey('note-chunk-overflow-menu'),
          tooltip: 'További műveletek',
          onSelected: (value) {
            switch (value) {
              case 'tag-selection':
                onTagSelection();
                break;
              case 'delete-selected-tag':
                onDeleteSelectedTag();
                break;
              case 'delete-chunk':
                onDeleteChunk();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              key: ValueKey('note-chunk-menu-tag-selection'),
              value: 'tag-selection',
              child: Text('Kijelölt rész tagelése'),
            ),
            PopupMenuItem(
              key: const ValueKey('note-chunk-menu-delete-selected-tag'),
              value: 'delete-selected-tag',
              enabled: canDeleteSelectedTag,
              child: const Text('Kijelölt tag törlése'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              key: ValueKey('note-chunk-menu-delete-chunk'),
              value: 'delete-chunk',
              child: Text('Chunk törlése'),
            ),
          ],
        ),
        if (saveAction != null) saveAction!,
      ],
    );
  }
}
