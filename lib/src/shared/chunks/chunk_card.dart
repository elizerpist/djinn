import 'package:flutter/material.dart';

import '../../knowledge/models/local_extraction.dart';

enum ChunkCardKind { text, list, table, score, flowchart, imageRegion, visualFact }

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
  });

  final String id;
  final String title;
  final String preview;
  final ChunkCardKind kind;
  final LocalAuditState auditState;
  final String sourceLabel;
  final String pipelineLabel;
  final String? pageLabel;
}

class ChunkCard extends StatelessWidget {
  const ChunkCard({
    super.key,
    required this.viewModel,
    this.onTap,
    this.onLongPress,
    this.expandedChild,
    this.metadata,
  });

  final ChunkCardViewModel viewModel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
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
          title: Text(
            viewModel.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              _AuditPill(state: viewModel.auditState),
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
            if (expandedChild != null) expandedChild!,
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
      ChunkCardKind.text => Icons.subject,
      ChunkCardKind.list => Icons.format_list_bulleted,
      ChunkCardKind.table => Icons.table_chart_outlined,
      ChunkCardKind.score => Icons.format_list_numbered,
      ChunkCardKind.flowchart => Icons.account_tree_outlined,
      ChunkCardKind.imageRegion => Icons.crop_free,
      ChunkCardKind.visualFact => Icons.visibility_outlined,
    };
  }

  static Color _colorFor(ChunkCardKind kind) {
    return switch (kind) {
      ChunkCardKind.text || ChunkCardKind.list => const Color(0xFF2563EB),
      ChunkCardKind.table => const Color(0xFF047857),
      ChunkCardKind.score => const Color(0xFFB45309),
      ChunkCardKind.flowchart => const Color(0xFF7C3AED),
      ChunkCardKind.imageRegion || ChunkCardKind.visualFact => const Color(0xFF0891B2),
    };
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
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
