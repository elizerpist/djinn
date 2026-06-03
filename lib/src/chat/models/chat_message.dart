enum ChatSender { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.status,
  });

  final String id;
  final String conversationId;
  final ChatSender sender;
  final String text;
  final DateTime createdAt;
  final String? status;
}
