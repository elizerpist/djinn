import 'package:flutter/material.dart';

import '../../knowledge/data/knowledge_sync_service.dart';
import '../../knowledge/models/knowledge_document.dart';
import '../data/local_chat_repository.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'chat_bubble.dart';
import 'message_composer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repository,
    required this.knowledgeSyncService,
    required this.conversation,
  });

  final LocalChatRepository repository;
  final KnowledgeSyncService knowledgeSyncService;
  final ChatConversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = const [];
  KnowledgeBaseState _knowledgeState = KnowledgeBaseState.fromDocuments(
    const [],
  );
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadKnowledgeState();
  }

  Future<void> _loadMessages() async {
    final messages = await widget.repository.getMessages(
      widget.conversation.id,
    );
    if (!mounted) {
      return;
    }
    setState(() => _messages = messages);
  }

  Future<void> _loadKnowledgeState() async {
    final state = await widget.knowledgeSyncService.refreshReadiness();
    if (!mounted) {
      return;
    }
    setState(() => _knowledgeState = state);
  }

  Future<void> _send(String text) async {
    setState(() => _sending = true);
    try {
      await _loadKnowledgeState();
      await widget.repository.sendMessage(widget.conversation.id, text);
      await _loadMessages();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          KnowledgeStatusBanner(state: _knowledgeState),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Ird be az elso kerdest'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        ChatBubble(message: _messages[index]),
                  ),
          ),
          MessageComposer(onSend: _send, sending: _sending),
        ],
      ),
    );
  }
}

class KnowledgeStatusBanner extends StatelessWidget {
  const KnowledgeStatusBanner({super.key, required this.state});

  final KnowledgeBaseState state;

  @override
  Widget build(BuildContext context) {
    final (text, icon, color) = switch (state.readiness) {
      KnowledgeBaseReadiness.empty => (
        'Nincs betoltott tudastar',
        Icons.folder_off,
        const Color(0xFF6B7280),
      ),
      KnowledgeBaseReadiness.pendingIngest => (
        'PDF-ek feldolgozasra varnak',
        Icons.hourglass_top,
        const Color(0xFF9A3412),
      ),
      KnowledgeBaseReadiness.ready => (
        'Tudastar kesz: ${state.processedCount} PDF',
        Icons.verified,
        const Color(0xFF166534),
      ),
      KnowledgeBaseReadiness.failed => (
        'Tudastar hiba',
        Icons.error_outline,
        const Color(0xFF991B1B),
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
