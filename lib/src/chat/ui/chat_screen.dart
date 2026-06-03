import 'package:flutter/material.dart';

import '../data/local_chat_repository.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'chat_bubble.dart';
import 'message_composer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repository,
    required this.conversation,
  });

  final LocalChatRepository repository;
  final ChatConversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await widget.repository.getMessages(widget.conversation.id);
    if (!mounted) {
      return;
    }
    setState(() => _messages = messages);
  }

  Future<void> _send(String text) async {
    setState(() => _sending = true);
    try {
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
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Ird be az elso kerdest'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => ChatBubble(message: _messages[index]),
                  ),
          ),
          MessageComposer(onSend: _send, sending: _sending),
        ],
      ),
    );
  }
}
