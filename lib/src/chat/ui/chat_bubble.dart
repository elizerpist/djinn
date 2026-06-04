import 'package:flutter/material.dart';

import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

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
              Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
              ),
              if (!isUser && message.citations.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final citation in message.citations)
                  Text(
                    '${citation.title}${citation.page == null ? '' : ' p.${citation.page}'}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
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
