import 'package:flutter/material.dart';

import '../models/chat_citation.dart';
import '../models/chat_message.dart';

enum BubbleTtsState { idle, speaking, paused }

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.ttsState = BubbleTtsState.idle,
    this.onPlay,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onCitationTap,
  });

  final ChatMessage message;
  final BubbleTtsState ttsState;
  final ValueChanged<ChatMessage>? onPlay;
  final ValueChanged<ChatMessage>? onPause;
  final ValueChanged<ChatMessage>? onResume;
  final ValueChanged<ChatMessage>? onStop;
  final ValueChanged<ChatCitation>? onCitationTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatSender.user;
    final color = isUser ? const Color(0xFF155EEF) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF1F2937);
    final statusLabel = _statusLabel(message);
    final citations = _groupCitations(message.citations);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser && message.hasValidationWarning) ...[
                _ValidationWarning(
                  text:
                      message.warningText ??
                      'A válasz nem validált flowchart elemet használ.',
                ),
                const SizedBox(height: 8),
              ],
              _MessageText(text: message.text, color: textColor),
              if (!isUser && citations.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final citation in citations)
                  _CitationRow(
                    citation: citation,
                    onTap: onCitationTap == null
                        ? null
                        : () => onCitationTap!(citation),
                  ),
              ],
              if (statusLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: isUser ? Colors.white70 : const Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
              ],
              if (!isUser) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: _BubbleTtsControls(
                    message: message,
                    state: ttsState,
                    onPlay: onPlay,
                    onPause: onPause,
                    onResume: onResume,
                    onStop: onStop,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _statusLabel(ChatMessage message) {
    final reason = message.refusalReason;
    if (reason != null) {
      return switch (reason) {
        'backend_unavailable' => 'Backend nem erheto el',
        'ai_backend_not_configured' => 'AI backend nincs beallitva',
        'vector_store_unavailable' => 'Tudastar kereso nem erheto el',
        'guardrails_unavailable' => 'Biztonsagi ellenorzes nem erheto el',
        'input_blocked' => 'Biztonsagi szabaly blokkolta',
        'insufficient_evidence' => 'Nincs elegendo forras',
        'knowledge_base_ingest_pending' => 'Feldolgozas folyamatban',
        'insufficient_retrieval_evidence' => 'Nincs elegendo forras',
        'retrieval_guard_blocked' => 'Forrasellenorzes blokkolta',
        'model_refused' => 'A modell nem adott forrasolt valaszt',
        'citation_verification_failed' => 'Hivatkozasellenorzes sikertelen',
        'groundedness_verification_failed' => 'Nem tamaszthato ala teljesen',
        'output_guard_blocked' => 'Valaszellenorzes blokkolta',
        'answer_pipeline_failed' => 'Valaszfolyamat hiba',
        _ => reason,
      };
    }
    return switch (message.status) {
      'grounded' => 'Forrasokkal ellenorizve',
      final status? => status,
      null => null,
    };
  }

  List<ChatCitation> _groupCitations(List<ChatCitation> citations) {
    final grouped = <String, List<ChatCitation>>{};
    for (final citation in citations) {
      grouped
          .putIfAbsent(_citationGroupKey(citation), () => <ChatCitation>[])
          .add(citation);
    }
    return grouped.entries
        .map((entry) {
          final items = entry.value;
          final first = items.first;
          if (items.length == 1) {
            return first;
          }
          return ChatCitation(
            documentId: first.documentId,
            title: _compactCitationTitle(first.title),
            page: first.page,
            section: first.section,
            excerpt: _mergedExcerpt(items),
            sourceId: entry.key,
            sourceType: _mergedSourceType(items),
            sourceLabel: first.sourceLabel == null
                ? _compactCitationTitle(first.title)
                : _compactCitationTitle(first.sourceLabel!),
            validationState: first.validationState,
            atomType: _mergedAtomType(items),
            reasons: _mergedReasons(items),
            fullChunkText: _mergedFullChunkText(items),
          );
        })
        .toList(growable: false);
  }

  String _citationGroupKey(ChatCitation citation) {
    final sourceId = citation.sourceId;
    if (sourceId != null && sourceId.isNotEmpty) {
      final parts = sourceId.split(':');
      if (parts.length >= 3 && parts.first == 'note') {
        return parts.take(3).join(':');
      }
      return sourceId.replaceFirst(
        RegExp(r':(?:part|item|row|node|edge)-[^:]+$'),
        '',
      );
    }
    return '${citation.documentId}:${citation.title}';
  }

  String _compactCitationTitle(String value) {
    final parts = value
        .split(' · ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 3) {
      return parts.take(3).join(' · ');
    }
    final colon = value.indexOf(':');
    return colon == -1 ? value.trim() : value.substring(0, colon).trim();
  }

  String _mergedExcerpt(List<ChatCitation> citations) {
    final seen = <String>{};
    final values = <String>[];
    for (final citation in citations) {
      final excerpt = citation.excerpt.trim();
      if (excerpt.isEmpty || !seen.add(excerpt.toLowerCase())) {
        continue;
      }
      values.add(excerpt);
      if (values.length >= 6) {
        break;
      }
    }
    return values.join('\n\n');
  }

  String? _mergedSourceType(List<ChatCitation> citations) {
    if (citations.any(
      (citation) =>
          citation.sourceType == 'flowchart_node' ||
          citation.sourceType == 'flowchart_edge',
    )) {
      return 'flowchart_edge';
    }
    if (citations.any((citation) => citation.sourceType == 'table_chunk')) {
      return 'table_chunk';
    }
    return citations.first.sourceType;
  }

  String? _mergedAtomType(List<ChatCitation> citations) {
    for (final citation in citations) {
      final atomType = citation.atomType;
      if (atomType != null && atomType.isNotEmpty) {
        return atomType;
      }
    }
    return null;
  }

  List<String> _mergedReasons(List<ChatCitation> citations) {
    final values = <String>{};
    for (final citation in citations) {
      values.addAll(citation.reasons.where((reason) => reason.isNotEmpty));
    }
    return values.toList(growable: false);
  }

  String? _mergedFullChunkText(List<ChatCitation> citations) {
    for (final citation in citations) {
      final text = citation.fullChunkText?.trim();
      if (text != null && text.isNotEmpty) {
        return citation.fullChunkText;
      }
    }
    return null;
  }
}

class _BubbleTtsControls extends StatelessWidget {
  const _BubbleTtsControls({
    required this.message,
    required this.state,
    this.onPlay,
    this.onPause,
    this.onResume,
    this.onStop,
  });

  final ChatMessage message;
  final BubbleTtsState state;
  final ValueChanged<ChatMessage>? onPlay;
  final ValueChanged<ChatMessage>? onPause;
  final ValueChanged<ChatMessage>? onResume;
  final ValueChanged<ChatMessage>? onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: switch (state) {
        BubbleTtsState.idle => [
          _smallButton(
            key: ValueKey('assistant-play-${message.id}'),
            tooltip: 'Válasz felolvasása',
            icon: Icons.volume_up_outlined,
            onPressed: onPlay == null ? null : () => onPlay!(message),
          ),
        ],
        BubbleTtsState.speaking => [
          _smallButton(
            key: ValueKey('assistant-pause-${message.id}'),
            tooltip: 'Felolvasás szüneteltetése',
            icon: Icons.pause_circle_outline,
            onPressed: onPause == null ? null : () => onPause!(message),
          ),
          _smallButton(
            key: ValueKey('assistant-stop-${message.id}'),
            tooltip: 'Felolvasás leállítása',
            icon: Icons.stop_circle_outlined,
            onPressed: onStop == null ? null : () => onStop!(message),
          ),
        ],
        BubbleTtsState.paused => [
          _smallButton(
            key: ValueKey('assistant-resume-${message.id}'),
            tooltip: 'Felolvasás folytatása',
            icon: Icons.play_circle_outline,
            onPressed: onResume == null ? null : () => onResume!(message),
          ),
          _smallButton(
            key: ValueKey('assistant-stop-${message.id}'),
            tooltip: 'Felolvasás leállítása',
            icon: Icons.stop_circle_outlined,
            onPressed: onStop == null ? null : () => onStop!(message),
          ),
        ],
      },
    );
  }

  Widget _smallButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: TextStyle(color: color, fontSize: 15, height: 1.35),
    );
  }
}

class _ValidationWarning extends StatelessWidget {
  const _ValidationWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF92400E),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    );
  }
}

class _CitationRow extends StatelessWidget {
  const _CitationRow({required this.citation, this.onTap});

  final ChatCitation citation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final page = citation.page;
    final titleText = '${citation.title}${page == null ? '' : ' p.$page'}';
    final sourceKey = citation.sourceId ?? citation.documentId;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        key: ValueKey('citation-$sourceKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _sourceIcon(citation.sourceType),
                    size: 16,
                    color: const Color(0xFF475569),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      citation.sourceLabel ?? titleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.open_in_full,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
              if (_chips(citation).isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final chip in _chips(citation)) _CitationChip(chip),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _chips(ChatCitation citation) {
    return [
      if (citation.atomType case final atomType?)
        if (atomType.trim().isNotEmpty) 'atom: ${atomType.trim()}',
      ...citation.reasons
          .map((reason) => reason.trim())
          .where((reason) => reason.isNotEmpty),
    ];
  }

  IconData _sourceIcon(String? sourceType) {
    return switch (sourceType) {
      'flowchart_node' || 'flowchart_edge' => Icons.account_tree_outlined,
      'table_chunk' || 'score_chunk' => Icons.table_chart_outlined,
      _ => Icons.article_outlined,
    };
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
