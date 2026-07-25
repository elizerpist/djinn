import 'package:flutter/material.dart';

import '../../knowledge/models/local_extraction.dart';
import '../../notes/models/note_document.dart';
import 'shared_chunk.dart';

typedef ChunkCardKind = SharedChunkKind;

class ChunkCardViewModel {
  const ChunkCardViewModel({
    required this.id,
    required this.title,
    required this.preview,
    required this.kind,
    required this.auditState,
    required this.sourceLabel,
    required this.pipelineLabel,
    this.pageLabel,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String preview;
  final ChunkCardKind kind;
  final LocalAuditState auditState;
  final String sourceLabel;
  final String pipelineLabel;
  final String? pageLabel;
  final List<NoteKnowledgeTag> tags;
}

class ChunkCard extends StatelessWidget {
  const ChunkCard({
    super.key,
    required this.viewModel,
    this.onTap,
    this.onLongPress,
    this.onTag,
    this.tagButtonKey,
    this.expandedChild,
    this.metadata,
  });

  final ChunkCardViewModel viewModel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onTag;
  final Key? tagButtonKey;
  final Widget? expandedChild;
  final String? metadata;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(viewModel.kind);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        key: ValueKey('chunk-card-${viewModel.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(_iconFor(viewModel.kind), size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  viewModel.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (onTag != null)
                IconButton(
                  key: tagButtonKey,
                  tooltip: 'Chunk tagek',
                  visualDensity: VisualDensity.compact,
                  onPressed: onTag,
                  icon: const Icon(Icons.sell_outlined, size: 18),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              _AuditPill(state: viewModel.auditState),
              if (viewModel.tags.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in viewModel.tags) _TagPill(tag: tag),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                viewModel.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            ?expandedChild,
            if (metadata != null && metadata!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  metadata!,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(ChunkCardKind kind) {
    return switch (kind) {
      SharedChunkKind.noteChunk => Icons.article_outlined,
      SharedChunkKind.flowchartChunk => Icons.account_tree_outlined,
    };
  }

  static Color _colorFor(ChunkCardKind kind) {
    return switch (kind) {
      SharedChunkKind.noteChunk => const Color(0xFF2563EB),
      SharedChunkKind.flowchartChunk => const Color(0xFF9333EA),
    };
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final NoteKnowledgeTag tag;

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.resolvedColorValue);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          tag.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _AuditPill extends StatelessWidget {
  const _AuditPill({required this.state});

  final LocalAuditState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      LocalAuditState.accepted => const Color(0xFF047857),
      LocalAuditState.edited => const Color(0xFF2563EB),
      LocalAuditState.rejected => const Color(0xFFB91C1C),
      LocalAuditState.unreviewed => const Color(0xFFB45309),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state == LocalAuditState.unreviewed ? 'Review' : state.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
