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
              if (message.status != null) ...[
                const SizedBox(height: 6),
                Text(
                  message.status!,
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
}
