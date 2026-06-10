import 'package:flutter/material.dart';

import '../models/knowledge_document.dart';

class KnowledgeDocumentRow extends StatelessWidget {
  const KnowledgeDocumentRow({
    super.key,
    required this.document,
    required this.selectionMode,
    required this.selected,
    required this.processing,
    this.progressLabel,
    this.progressValue,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionChanged,
  });

  final KnowledgeDocument document;
  final bool selectionMode;
  final bool selected;
  final bool processing;
  final String? progressLabel;
  final double? progressValue;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onSelectionChanged;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                            if (document.status.isReady)
                              const _Badge(text: 'RAG'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (progressLabel != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  key: Key('document-progress-${document.id}'),
                  value: progressValue,
                  minHeight: 3,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    progressLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
