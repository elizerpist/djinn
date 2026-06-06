import '../../core/storage/json_file_store.dart';
import '../models/chat_citation.dart';
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

  Future<ChatMessage> appendUserMessage(
    String conversationId,
    String text,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('message text must not be blank');
    }
    final message = ChatMessage(
      id: 'message-${_nextMessageId++}',
      conversationId: conversationId,
      sender: ChatSender.user,
      text: trimmed,
      createdAt: _clock(),
    );
    await _appendMessage(conversationId, message, titleSeed: trimmed);
    return message;
  }

  Future<ChatMessage> appendAssistantMessage(
    String conversationId, {
    required String text,
    required String status,
    String? refusalReason,
    List<ChatCitation> citations = const [],
    bool hasValidationWarning = false,
    String? warningText,
  }) async {
    final message = ChatMessage(
      id: 'message-${_nextMessageId++}',
      conversationId: conversationId,
      sender: ChatSender.assistant,
      text: text,
      createdAt: _clock(),
      status: status,
      refusalReason: refusalReason,
      citations: citations,
      hasValidationWarning: hasValidationWarning,
      warningText: warningText,
    );
    await _appendMessage(conversationId, message);
    return message;
  }

  Future<ChatMessage> sendMessage(String conversationId, String text) async {
    await appendUserMessage(conversationId, text);
    return appendAssistantMessage(
      conversationId,
      text:
          'A tudasbazisban nincs elegendo hitelesitett forras ehhez a valaszhoz. Csak az alkalmazas dokumentumai alapjan tudok valaszolni.',
      status: 'insufficient_evidence',
      refusalReason: 'insufficient_evidence',
    );
  }

  ChatConversation _findConversation(String conversationId) {
    return _conversations.firstWhere(
      (conversation) => conversation.id == conversationId,
      orElse: () => throw StateError('conversation not found: $conversationId'),
    );
  }

  Future<void> _appendMessage(
    String conversationId,
    ChatMessage message, {
    String? titleSeed,
  }) async {
    final conversation = _findConversation(conversationId);
    final messages = [...conversation.messages, message];
    final updated = conversation.copyWith(
      title: titleSeed != null && conversation.title == 'Uj chat'
          ? _titleFrom(titleSeed)
          : conversation.title,
      updatedAt: message.createdAt,
      messages: messages,
    );
    final index = _conversations.indexWhere(
      (item) => item.id == conversationId,
    );
    _conversations[index] = updated;
    await _persist();
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
