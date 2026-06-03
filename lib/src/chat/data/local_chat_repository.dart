import '../../core/storage/json_file_store.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

class LocalChatRepository {
  LocalChatRepository({DateTime Function()? clock, JsonFileStore? store})
    : _clock = clock ?? DateTime.now,
      _store = store;

  final DateTime Function() _clock;
  final JsonFileStore? _store;
  final List<ChatConversation> _conversations = [];
  int _nextConversationId = 1;
  int _nextMessageId = 1;

  Future<void> load() async {
    final store = _store;
    if (store == null) {
      return;
    }
    final items = await store.readList();
    _conversations
      ..clear()
      ..addAll(items.map(ChatConversation.fromJson));
    _nextConversationId =
        _nextNumericSuffix(
          _conversations.map((item) => item.id),
          'conversation-',
        ) +
        1;
    _nextMessageId =
        _nextNumericSuffix(
          _conversations
              .expand((conversation) => conversation.messages)
              .map((item) => item.id),
          'message-',
        ) +
        1;
  }

  Future<List<ChatConversation>> listConversations() async {
    return List.unmodifiable(_conversations);
  }

  Future<ChatConversation> createConversation({
    String title = 'Uj chat',
  }) async {
    final now = _clock();
    final conversation = ChatConversation(
      id: 'conversation-${_nextConversationId++}',
      title: title,
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
    _conversations.insert(0, conversation);
    await _persist();
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
      text:
          'A tudasbazisban nincs elegendo hitelesitett forras ehhez a valaszhoz. Csak az alkalmazas dokumentumai alapjan tudok valaszolni.',
      createdAt: now,
      status: 'insufficient_evidence',
    );

    final messages = [...conversation.messages, userMessage, assistantMessage];
    final updated = conversation.copyWith(
      title: conversation.title == 'Uj chat'
          ? _titleFrom(trimmed)
          : conversation.title,
      updatedAt: now,
      messages: messages,
    );
    final index = _conversations.indexWhere(
      (item) => item.id == conversationId,
    );
    _conversations[index] = updated;
    await _persist();
    return assistantMessage;
  }

  ChatConversation _findConversation(String conversationId) {
    return _conversations.firstWhere(
      (conversation) => conversation.id == conversationId,
      orElse: () => throw StateError('conversation not found: $conversationId'),
    );
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.writeList(_conversations.map((item) => item.toJson()).toList());
  }

  int _nextNumericSuffix(Iterable<String> ids, String prefix) {
    var max = 0;
    for (final id in ids) {
      if (!id.startsWith(prefix)) {
        continue;
      }
      final value = int.tryParse(id.substring(prefix.length));
      if (value != null && value > max) {
        max = value;
      }
    }
    return max;
  }

  String _titleFrom(String text) {
    if (text.length <= 48) {
      return text;
    }
    return '${text.substring(0, 48)}...';
  }
}
