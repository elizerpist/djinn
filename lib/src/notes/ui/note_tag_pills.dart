import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
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
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
  }
}

class NoteSelectionActionRail extends StatefulWidget {
  const NoteSelectionActionRail({
    super.key,
    required this.tags,
    required this.actions,
    this.label,
    this.pillPrefix = 'note-selection-rail-tag-pill',
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 8,
    ),
    this.bottomRowExpanded = true,
    this.onToggleBottomRow,
    this.onDeleteTag,
    this.roundedCard = false,
    this.transparentBackground = false,
    this.showBorder = true,
    this.showBottomBorder = true,
    this.stickyViewportLeft,
    this.stickyViewportWidth,
    this.debugLogPrefix = 'SelectionRail',
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
  final bool showBorder;
  final bool showBottomBorder;
  final double? stickyViewportLeft;
  final double? stickyViewportWidth;
  final String debugLogPrefix;

  @override
  State<NoteSelectionActionRail> createState() =>
      _NoteSelectionActionRailState();
}

class _NoteSelectionActionRailState extends State<NoteSelectionActionRail> {
  final ScrollController _actionController = ScrollController();
  final ScrollController _pillController = ScrollController();
  final Map<String, double> _lastLoggedRowOffsets = <String, double>{};

  @override
  void dispose() {
    _actionController.dispose();
    _pillController.dispose();
    super.dispose();
  }

  void _scrollRailRow(
    ScrollController controller,
    double delta,
    String rowName,
  ) {
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    final nextOffset = (position.pixels - delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (nextOffset == position.pixels) {
      return;
    }
    final lastLoggedOffset = _lastLoggedRowOffsets[rowName];
    final atBoundary =
        nextOffset == position.minScrollExtent ||
        nextOffset == position.maxScrollExtent;
    final shouldLog =
        lastLoggedOffset == null ||
        (nextOffset - lastLoggedOffset).abs() >= 160 ||
        (atBoundary && nextOffset != lastLoggedOffset);
    if (shouldLog) {
      _lastLoggedRowOffsets[rowName] = nextOffset;
      DebugConsole.log(
        '[${widget.debugLogPrefix}] row scroll row=$rowName '
        'from=${position.pixels.toStringAsFixed(1)} '
        'to=${nextOffset.toStringAsFixed(1)} '
        'max=${position.maxScrollExtent.toStringAsFixed(1)}',
      );
    }
    controller.jumpTo(nextOffset);
  }

  Widget _stickyViewport({required double height, required Widget child}) {
    final left = widget.stickyViewportLeft;
    final width = widget.stickyViewportWidth;
    if (left == null || width == null) {
      return child;
    }
    return SizedBox(
      height: height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: left,
              width: width,
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.transparentBackground
        ? Colors.transparent
        : Colors.white;
    final decoration = widget.roundedCard
        ? BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: widget.showBorder
                ? Border.all(color: const Color(0xFFE5E7EB))
                : null,
          )
        : BoxDecoration(
            color: backgroundColor,
            border: widget.showBorder
                ? Border(
                    top: const BorderSide(color: Color(0xFFE5E7EB)),
                    bottom: widget.showBottomBorder
                        ? const BorderSide(color: Color(0xFFE5E7EB))
                        : BorderSide.none,
                  )
                : null,
          );
    return Material(
      key: const ValueKey('note-selection-action-rail'),
      color: backgroundColor,
      elevation: 0,
      child: KeyedSubtree(
        key: ValueKey(
          widget.roundedCard
              ? 'note-selection-action-rail-rounded'
              : 'note-selection-action-rail-separator',
        ),
        child: KeyedSubtree(
          key: ValueKey(
            widget.transparentBackground
                ? 'note-selection-action-rail-transparent'
                : 'note-selection-action-rail-white',
          ),
          child: KeyedSubtree(
            key: ValueKey(
              widget.showBorder
                  ? 'note-selection-action-rail-border'
                  : 'note-selection-action-rail-borderless',
            ),
            child: KeyedSubtree(
              key: ValueKey(
                widget.showBottomBorder
                    ? 'note-selection-action-rail-bottom-border'
                    : 'note-selection-action-rail-bottom-borderless',
              ),
              child: Container(
                decoration: decoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _stickyViewport(
                      height: 64,
                      child: Padding(
                        padding: widget.contentPadding,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) => _scrollRailRow(
                            _actionController,
                            details.delta.dx,
                            'actions',
                          ),
                          child: SingleChildScrollView(
                            key: const ValueKey('note-selection-action-row'),
                            controller: _actionController,
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.onToggleBottomRow != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: IconButton(
                                      key: const ValueKey(
                                        'note-selection-rail-toggle-tags',
                                      ),
                                      tooltip: widget.bottomRowExpanded
                                          ? 'Tagek bezárása'
                                          : 'Tagek megnyitása',
                                      onPressed: widget.onToggleBottomRow,
                                      icon: Icon(
                                        widget.bottomRowExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                for (final action in widget.actions)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: action,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.bottomRowExpanded) ...[
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      _stickyViewport(
                        height: 48,
                        child: Padding(
                          padding: widget.contentPadding,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) => _scrollRailRow(
                              _pillController,
                              details.delta.dx,
                              'tags',
                            ),
                            child: SingleChildScrollView(
                              key: const ValueKey('note-selection-pill-row'),
                              controller: _pillController,
                              primary: false,
                              physics: const NeverScrollableScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              child: widget.tags.isEmpty
                                  ? Text(
                                      'Nincs tag',
                                      key: const ValueKey(
                                        'note-selection-empty-tags',
                                      ),
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : NoteTagPills(
                                      tags: widget.tags,
                                      prefix: widget.pillPrefix,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      onDeleted: widget.onDeleteTag,
                                      scrollable: false,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
