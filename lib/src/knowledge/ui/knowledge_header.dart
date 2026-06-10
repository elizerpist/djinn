import 'package:flutter/material.dart';

class KnowledgeHeader extends StatelessWidget implements PreferredSizeWidget {
  const KnowledgeHeader({
    super.key,
    required this.selectionCount,
    required this.selectionSummary,
    required this.onExitSelection,
    required this.onSendSelected,
    this.onDeleteSelected,
    required this.onGeneralMenu,
    required this.onSelectionMenu,
  });

  final int selectionCount;
  final String selectionSummary;
  final VoidCallback onExitSelection;
  final VoidCallback onSendSelected;
  final VoidCallback? onDeleteSelected;
  final VoidCallback onGeneralMenu;
  final VoidCallback onSelectionMenu;

  bool get selectionMode => selectionCount > 0;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          tooltip: 'Kijelölés megszüntetése',
          onPressed: onExitSelection,
          icon: const Icon(Icons.close),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$selectionCount kijelölve'),
            Text(
              selectionSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('knowledge-send-selected'),
            tooltip: 'Küldés feldolgozásra',
            onPressed: onSendSelected,
            icon: const Icon(Icons.upload),
          ),
          IconButton(
            key: const Key('knowledge-delete-selected'),
            tooltip: 'Törlés',
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            key: const Key('knowledge-selection-menu'),
            tooltip: 'Kijelölt műveletek',
            onPressed: onSelectionMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('Tudástár'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(
          key: const Key('knowledge-general-menu'),
          tooltip: 'Tudástár menü',
          onPressed: onGeneralMenu,
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}
