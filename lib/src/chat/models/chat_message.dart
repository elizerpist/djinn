import 'chat_citation.dart';

enum ChatSender { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.status,
    this.refusalReason,
    this.citations = const [],
    this.hasValidationWarning = false,
    this.warningText,
  });

  final String id;
  final String conversationId;
  final ChatSender sender;
  final String text;
  final DateTime createdAt;
  final String? status;
  final String? refusalReason;
  final List<ChatCitation> citations;
  final bool hasValidationWarning;
  final String? warningText;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender.name,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'refusalReason': refusalReason,
      'citations': citations.map((citation) => citation.toJson()).toList(),
      'hasValidationWarning': hasValidationWarning,
      'warningText': warningText,
    };
  }

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final citationItems = (json['citations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ChatCitation.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
    return ChatMessage(
      id: json['id']! as String,
      conversationId: json['conversationId']! as String,
      sender: ChatSender.values.byName(json['sender']! as String),
      text: json['text']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      status: json['status'] as String?,
      refusalReason: json['refusalReason'] as String?,
      citations: citationItems,
      hasValidationWarning: json['hasValidationWarning'] as bool? ?? false,
      warningText: json['warningText'] as String?,
    );
  }
}
