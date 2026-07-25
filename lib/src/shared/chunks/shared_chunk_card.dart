import 'package:flutter/material.dart';

import 'shared_chunk.dart';

class SharedChunkStatusChip {
  const SharedChunkStatusChip({required this.label, required this.color});

  final String label;
  final Color color;
}

class SharedChunkCard extends StatelessWidget {
  const SharedChunkCard({
    super.key,
    required this.id,
    required this.keyPrefix,
    required this.kind,
    required this.title,
    required this.expanded,
    required this.statusChips,
    required this.onOpenEditor,
    required this.onToggleExpanded,
    required this.expandedBody,
    this.onLongPress,
    this.tagCount = 0,
    this.tagBadgeColor,
    this.selected = false,
    this.leading,
    this.actions = const [],
    this.expandedBodyKey,
    this.expandedPadding,
    this.expandKeyPrefix,
  });

  final String id;
  final String keyPrefix;
  final SharedChunkKind kind;
  final String title;
  final bool expanded;
  final List<SharedChunkStatusChip> statusChips;
  final VoidCallback onOpenEditor;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onLongPress;
  final int tagCount;
  final Color? tagBadgeColor;
  final bool selected;
  final Widget expandedBody;
  final Widget? leading;
  final List<Widget> actions;
  final Key? expandedBodyKey;
  final EdgeInsets? expandedPadding;
  final String? expandKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(kind);
    return DecoratedBox(
      key: ValueKey('$keyPrefix-$id'),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onOpenEditor,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 36,
                      child: Center(child: leading ?? const SizedBox.shrink()),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_iconFor(kind), color: accent, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              for (final chip in statusChips)
                                _StatusChip(
                                  label: chip.label,
                                  color: chip.color,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (tagCount > 0)
                      _TagCountBadge(
                        key: ValueKey('$keyPrefix-tag-count-$id'),
                        count: tagCount,
                        color: tagBadgeColor ?? accent,
                      ),
                    ...actions,
                    IconButton(
                      key: ValueKey(
                        '${expandKeyPrefix ?? keyPrefix}-expand-$id',
                      ),
                      tooltip: expanded ? 'Osszecsukas' : 'Kinyitas',
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    key: expandedBodyKey,
                    padding:
                        expandedPadding ??
                        const EdgeInsets.fromLTRB(46, 10, 8, 2),
                    child: expandedBody,
                  ),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 160),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _accentFor(SharedChunkKind kind) {
    return switch (kind) {
      SharedChunkKind.noteChunk => const Color(0xFF2563EB),
      SharedChunkKind.flowchartChunk => const Color(0xFF9333EA),
    };
  }

  IconData _iconFor(SharedChunkKind kind) {
    return switch (kind) {
      SharedChunkKind.noteChunk => Icons.article_outlined,
      SharedChunkKind.flowchartChunk => Icons.account_tree_outlined,
    };
  }
}

class _TagCountBadge extends StatelessWidget {
  const _TagCountBadge({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count tag',
      child: Container(
        constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
