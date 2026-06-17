import 'package:flutter/material.dart';

import '../models/note_document.dart';

class NoteTagPills extends StatelessWidget {
  const NoteTagPills({
    super.key,
    required this.tags,
    this.prefix = 'note-global-tag-pill',
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final List<NoteKnowledgeTag> tags;
  final String prefix;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          Container(
            key: ValueKey('$prefix-${tag.label}'),
            padding: padding,
            decoration: BoxDecoration(
              color: Color(tag.resolvedColorValue),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
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
  });

  final List<NoteKnowledgeTag> tags;
  final List<Widget> actions;
  final String? label;
  final String pillPrefix;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('note-selection-action-rail'),
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x0F111827), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: tags.isEmpty
                  ? Text(
                      label ?? '',
                      overflow: TextOverflow.ellipsis,
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
                    ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              children: actions,
            ),
          ],
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
