import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class LocalChatRepository {
  LocalChatRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final List<ChatConversation> _conversations = [];
  int _nextConversationId = 1;
  int _nextMessageId = 1;

  Future<List<ChatConversation>> listConversations() async {
    return List.unmodifiable(_conversations);
  }

  Future<ChatConversation> createConversation({String title = 'Uj chat'}) async {
    final now = _clock();
    final conversation = ChatConversation(
      id: 'conversation-${_nextConversationId++}',
      title: title,
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
    _conversations.insert(0, conversation);
    return conversation;
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final conversation = _findConversation(conversationId);
    return List.unmodifiable(conversation.messages);
  }

  Future<ChatMessage> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('message text must not be blank');
    }

    final conversation = _findConversation(conversationId);
    final now = _clock();
    final userMessage = ChatMessage(
      id: 'message-${_nextMessageId++}',
      conversationId: conversationId,
      sender: ChatSender.user,
      text: trimmed,
      createdAt: now,
    );
    final assistantMessage = ChatMessage(
      id: 'message-${_nextMessageId++}',
      conversationId: conversationId,
      sender: ChatSender.assistant,
      text: 'A tudasbazisban nincs elegendo hitelesitett forras ehhez a valaszhoz. Csak az alkalmazas dokumentumai alapjan tudok valaszolni.',
      createdAt: now,
      status: 'insufficient_evidence',
    );

    final messages = [...conversation.messages, userMessage, assistantMessage];
    final updated = conversation.copyWith(
      title: conversation.title == 'Uj chat' ? _titleFrom(trimmed) : conversation.title,
      updatedAt: now,
      messages: messages,
    );
    final index = _conversations.indexWhere((item) => item.id == conversationId);
    _conversations[index] = updated;
    return assistantMessage;
  }

  ChatConversation _findConversation(String conversationId) {
    return _conversations.firstWhere(
      (conversation) => conversation.id == conversationId,
      orElse: () => throw StateError('conversation not found: $conversationId'),
    );
  }

  String _titleFrom(String text) {
    if (text.length <= 48) {
      return text;
    }
    return '${text.substring(0, 48)}...';
  }
}
