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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
      SharedChunkKind.text => const Color(0xFF2563EB),
      SharedChunkKind.list => const Color(0xFF059669),
      SharedChunkKind.table => const Color(0xFFEA580C),
      SharedChunkKind.flowchart => const Color(0xFF9333EA),
    };
  }

  IconData _iconFor(SharedChunkKind kind) {
    return switch (kind) {
      SharedChunkKind.text => Icons.notes_outlined,
      SharedChunkKind.list => Icons.checklist_outlined,
      SharedChunkKind.table => Icons.table_chart_outlined,
      SharedChunkKind.flowchart => Icons.account_tree_outlined,
    };
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
