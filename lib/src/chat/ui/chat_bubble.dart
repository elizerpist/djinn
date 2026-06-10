import 'package:flutter/material.dart';

import '../models/chat_citation.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.onPlay,
    this.onCitationTap,
  });

  final ChatMessage message;
  final ValueChanged<ChatMessage>? onPlay;
  final ValueChanged<ChatCitation>? onCitationTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatSender.user;
    final color = isUser ? const Color(0xFF155EEF) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF1F2937);
    final statusLabel = _statusLabel(message);

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
              if (!isUser && onPlay != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _MessageText(text: message.text, color: textColor),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      key: ValueKey('assistant-play-${message.id}'),
                      tooltip: 'Válasz felolvasása',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      onPressed: () => onPlay!(message),
                      icon: const Icon(Icons.volume_up_outlined, size: 18),
                    ),
                  ],
                )
              else
                _MessageText(text: message.text, color: textColor),
              if (!isUser && message.citations.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final citation in message.citations)
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
}

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
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
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        key: ValueKey('citation-$sourceKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (citation.sourceLabel case final label?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                titleText,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
