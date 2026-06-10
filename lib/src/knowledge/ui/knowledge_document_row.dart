import 'package:flutter/material.dart';

import '../models/knowledge_document.dart';

class KnowledgeDocumentRow extends StatelessWidget {
  const KnowledgeDocumentRow({
    super.key,
    required this.document,
    required this.selectionMode,
    required this.selected,
    required this.processing,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.onProcess,
    required this.processTooltip,
    required this.onMenu,
  });

  final KnowledgeDocument document;
  final bool selectionMode;
  final bool selected;
  final bool processing;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback? onProcess;
  final String processTooltip;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selectionMode ? () => onSelectionChanged(!selected) : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (selectionMode) ...[
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelectionChanged(value ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.picture_as_pdf, color: Color(0xFFB91C1C)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      document.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _Badge(text: document.syncStatusLabel),
                        _Badge(text: _sizeLabel(document.sizeBytes)),
                        if (document.status.isReady) const _Badge(text: 'RAG'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _ProcessAction(
                processing: processing,
                tooltip: processTooltip,
                onPressed: onProcess,
              ),
              IconButton(
                key: Key('document-menu-${document.id}'),
                tooltip: 'PDF műveletek',
                visualDensity: VisualDensity.compact,
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} kB';
    }
    return '$bytes byte';
  }
}

class _ProcessAction extends StatelessWidget {
  const _ProcessAction({
    required this.processing,
    required this.tooltip,
    required this.onPressed,
  });

  final bool processing;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: const Icon(Icons.sync),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
