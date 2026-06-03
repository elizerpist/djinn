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

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender.name,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    return ChatMessage(
      id: json['id']! as String,
      conversationId: json['conversationId']! as String,
      sender: ChatSender.values.byName(json['sender']! as String),
      text: json['text']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      status: json['status'] as String?,
    );
  }
}
