import 'package:flutter/material.dart';

import '../models/note_document.dart';

class NoteTagPills extends StatelessWidget {
  const NoteTagPills({
    super.key,
    required this.tags,
    this.prefix = 'note-global-tag-pill',
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.onDeleted,
    this.scrollable = true,
  });

  final List<NoteKnowledgeTag> tags;
  final String prefix;
  final EdgeInsetsGeometry padding;
  final ValueChanged<NoteKnowledgeTag>? onDeleted;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in tags)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              key: ValueKey('$prefix-${tag.label}'),
              padding: padding,
              decoration: BoxDecoration(
                color: Color(tag.resolvedColorValue),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (onDeleted != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      key: ValueKey('$prefix-remove-${tag.label}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDeleted!(tag),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
    if (!scrollable) {
      return row;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: row,
    );
  }
}

class NoteSelectionActionRail extends StatelessWidget {
  const NoteSelectionActionRail({
    super.key,
    required this.tags,
    required this.actions,
    this.label,
    this.pillPrefix = 'note-selection-rail-tag-pill',
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.bottomRowExpanded = true,
    this.onToggleBottomRow,
    this.onDeleteTag,
    this.roundedCard = false,
    this.transparentBackground = false,
  });

  final List<NoteKnowledgeTag> tags;
  final List<Widget> actions;
  final String? label;
  final String pillPrefix;
  final EdgeInsetsGeometry contentPadding;
  final bool bottomRowExpanded;
  final VoidCallback? onToggleBottomRow;
  final ValueChanged<NoteKnowledgeTag>? onDeleteTag;
  final bool roundedCard;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = transparentBackground ? Colors.transparent : Colors.white;
    final decoration = roundedCard
        ? BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          )
        : BoxDecoration(
            color: backgroundColor,
            border: const Border(
              top: BorderSide(color: Color(0xFFE5E7EB)),
              bottom: BorderSide(color: Color(0xFFE5E7EB)),
            ),
          );
    return Material(
      key: const ValueKey('note-selection-action-rail'),
      color: backgroundColor,
      elevation: 0,
      child: KeyedSubtree(
        key: ValueKey(
          roundedCard
              ? 'note-selection-action-rail-rounded'
              : 'note-selection-action-rail-separator',
        ),
        child: KeyedSubtree(
          key: ValueKey(
            transparentBackground
                ? 'note-selection-action-rail-transparent'
                : 'note-selection-action-rail-white',
          ),
          child: Container(
            decoration: decoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: contentPadding,
                  child: SingleChildScrollView(
                    key: const ValueKey('note-selection-action-row'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onToggleBottomRow != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton(
                              key: const ValueKey('note-selection-rail-toggle-tags'),
                              tooltip: bottomRowExpanded ? 'Tagek bezárása' : 'Tagek megnyitása',
                              onPressed: onToggleBottomRow,
                              icon: Icon(
                                bottomRowExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 20,
                              ),
                            ),
                          ),
                        for (final action in actions)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: action,
                          ),
                      ],
                    ),
                  ),
                ),
                if (bottomRowExpanded) ...[
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Padding(
                    padding: contentPadding,
                    child: SingleChildScrollView(
                      key: const ValueKey('note-selection-pill-row'),
                      scrollDirection: Axis.horizontal,
                      child: tags.isEmpty
                          ? Text(
                              'Nincs tag',
                              key: const ValueKey('note-selection-empty-tags'),
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : NoteTagPills(
                              tags: tags,
                              prefix: pillPrefix,
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              onDeleted: onDeleteTag,
                              scrollable: false,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoteSelectedTagTray extends StatelessWidget {
  const NoteSelectedTagTray({
    super.key,
    required this.tags,
    this.label = 'Kijelölt elem',
  });

  final List<NoteKnowledgeTag> tags;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Material(
      key: const ValueKey('note-selected-tag-tray'),
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: NoteTagPills(
                tags: tags,
                prefix: 'note-selected-tag-pill',
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
