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
    required this.onOpenSource,
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
  final VoidCallback onOpenSource;
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
                  InkResponse(
                    key: ValueKey('knowledge-document-source-${document.id}'),
                    onTap: selectionMode ? null : onOpenSource,
                    radius: 22,
                    child: Icon(_documentIcon, color: _documentIconColor),
                  ),
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
                            _Badge(
                              text: document.syncStatusLabel,
                              style: _BadgeStyle.forStatus(document.status),
                            ),
                            _Badge(text: _sizeLabel(document.sizeBytes)),
                            if (document.status ==
                                KnowledgeDocumentStatus.needsReview) ...[
                              const _Badge(
                                text: 'Kinyerve',
                                style: _BadgeStyle.review,
                              ),
                              const _Badge(
                                text: 'Audit kell',
                                style: _BadgeStyle.review,
                              ),
                            ],
                            if (document.status.isReady) ...[
                              const _Badge(
                                text: 'Indexelve',
                                style: _BadgeStyle.ready,
                              ),
                              const _Badge(text: 'RAG', style: _BadgeStyle.rag),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!selectionMode) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  ],
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

  IconData get _documentIcon {
    return document.filename.toLowerCase().endsWith('.png')
        ? Icons.image_outlined
        : Icons.picture_as_pdf;
  }

  Color get _documentIconColor {
    return document.filename.toLowerCase().endsWith('.png')
        ? const Color(0xFF2563EB)
        : const Color(0xFFB91C1C);
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
  const _Badge({required this.text, this.style = _BadgeStyle.neutral});

  final String text;
  final _BadgeStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: style.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: TextStyle(
            color: style.foreground,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static const neutral = _BadgeStyle(
    background: Color(0xFFF3F4F6),
    foreground: Color(0xFF374151),
    border: Color(0xFFE5E7EB),
  );

  static const ready = _BadgeStyle(
    background: Color(0xFFDCFCE7),
    foreground: Color(0xFF166534),
    border: Color(0xFFBBF7D0),
  );

  static const rag = _BadgeStyle(
    background: Color(0xFFE0F2FE),
    foreground: Color(0xFF075985),
    border: Color(0xFFBAE6FD),
  );

  static const working = _BadgeStyle(
    background: Color(0xFFDBEAFE),
    foreground: Color(0xFF1D4ED8),
    border: Color(0xFFBFDBFE),
  );

  static const review = _BadgeStyle(
    background: Color(0xFFFEF3C7),
    foreground: Color(0xFF92400E),
    border: Color(0xFFFDE68A),
  );

  static const danger = _BadgeStyle(
    background: Color(0xFFFEE2E2),
    foreground: Color(0xFF991B1B),
    border: Color(0xFFFECACA),
  );

  static _BadgeStyle forStatus(KnowledgeDocumentStatus status) {
    return switch (status) {
      KnowledgeDocumentStatus.imported ||
      KnowledgeDocumentStatus.pendingIngest => neutral,
      KnowledgeDocumentStatus.uploading ||
      KnowledgeDocumentStatus.processing ||
      KnowledgeDocumentStatus.embedded => working,
      KnowledgeDocumentStatus.ready ||
      KnowledgeDocumentStatus.processed => ready,
      KnowledgeDocumentStatus.needsReview => review,
      KnowledgeDocumentStatus.blockedMissingApiKey ||
      KnowledgeDocumentStatus.blockedOffline ||
      KnowledgeDocumentStatus.failed => danger,
    };
  }
}
