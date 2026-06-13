import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../models/chat_citation.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'local_chat_repository.dart';

class ObjectBoxChatRepository extends LocalChatRepository {
  // ignore: use_super_parameters
  ObjectBoxChatRepository({
    required Store store,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _threadBox = store.box<ChatThreadEntity>(),
       _messageBox = store.box<ChatMessageEntity>(),
       _citationBox = store.box<CitationEntity>(),
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid(),
       super(clock: clock);

  final Box<ChatThreadEntity> _threadBox;
  final Box<ChatMessageEntity> _messageBox;
  final Box<CitationEntity> _citationBox;
  final DateTime Function() _clock;
  final Uuid _uuid;

  @override
  Future<void> load() async {}

  @override
  Future<List<ChatConversation>> listConversations() async {
    final threads = _threadBox.getAll()
      ..sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    return [
      for (final thread in threads)
        ChatConversation(
          id: thread.publicId,
          title: thread.title,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            thread.createdAtMillis,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            thread.updatedAtMillis,
          ),
          messages: await getMessages(thread.publicId),
        ),
    ];
  }

  @override
  Future<ChatConversation> createConversation({
    String title = 'Új chat',
  }) async {
    final now = _clock();
    final thread = ChatThreadEntity(
      publicId: _uuid.v4(),
      title: title,
      createdAtMillis: now.millisecondsSinceEpoch,
      updatedAtMillis: now.millisecondsSinceEpoch,
    );
    _threadBox.put(thread);
    return ChatConversation(
      id: thread.publicId,
      title: thread.title,
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final messages =
        _messageBox
            .getAll()
            .where((item) => item.threadPublicId == conversationId)
            .toList(growable: false)
          ..sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    return [for (final message in messages) _messageFromEntity(message)];
  }

  @override
  Future<ChatMessage> appendUserMessage(
    String conversationId,
    String text,
  ) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('message text must not be blank');
    }
    final message = ChatMessageEntity(
      publicId: _uuid.v4(),
      threadPublicId: conversationId,
      sender: ChatSender.user.name,
      text: trimmed,
      createdAtMillis: _clock().millisecondsSinceEpoch,
    );
    _messageBox.put(message);
    _touchThread(conversationId, message.createdAtMillis, titleSeed: trimmed);
    return _messageFromEntity(message);
  }

  @override
  Future<ChatMessage> appendAssistantMessage(
    String conversationId, {
    required String text,
    required String status,
    String? refusalReason,
    List<ChatCitation> citations = const [],
    bool hasValidationWarning = false,
    String? warningText,
  }) async {
    final message = ChatMessageEntity(
      publicId: _uuid.v4(),
      threadPublicId: conversationId,
      sender: ChatSender.assistant.name,
      text: text,
      createdAtMillis: _clock().millisecondsSinceEpoch,
      status: status,
      refusalReason: refusalReason,
      hasValidationWarning: hasValidationWarning,
      warningText: warningText,
    );
    _messageBox.put(message);
    for (final citation in citations) {
      _citationBox.put(
        CitationEntity(
          publicId: _uuid.v4(),
          messagePublicId: message.publicId,
          sourceId: citation.sourceId ?? citation.documentId,
          sourceType: citation.sourceType ?? 'text_chunk',
          sourceLabel: citation.sourceLabel ?? citation.title,
          documentPublicId: citation.documentId,
          pageNumber: citation.page,
          excerpt: citation.excerpt,
        ),
      );
    }
    _touchThread(conversationId, message.createdAtMillis);
    return _messageFromEntity(message);
  }

  ChatMessage _messageFromEntity(ChatMessageEntity entity) {
    final citations = _citationBox
        .getAll()
        .where((item) => item.messagePublicId == entity.publicId)
        .map(_citationFromEntity)
        .toList(growable: false);
    return ChatMessage(
      id: entity.publicId,
      conversationId: entity.threadPublicId,
      sender: ChatSender.values.byName(entity.sender),
      text: entity.text,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      status: entity.status,
      refusalReason: entity.refusalReason,
      citations: citations,
      hasValidationWarning: entity.hasValidationWarning,
      warningText: entity.warningText,
    );
  }

  ChatCitation _citationFromEntity(CitationEntity entity) {
    return ChatCitation(
      documentId: entity.documentPublicId ?? entity.sourceId,
      title: entity.documentPublicId ?? entity.sourceLabel,
      page: entity.pageNumber,
      section: null,
      excerpt: entity.excerpt ?? '',
      sourceId: entity.sourceId,
      sourceType: entity.sourceType,
      sourceLabel: entity.sourceLabel,
      validationState: null,
    );
  }

  void _touchThread(
    String conversationId,
    int updatedAtMillis, {
    String? titleSeed,
  }) {
    final thread = _findThread(conversationId);
    if (thread == null) {
      throw StateError('conversation not found: $conversationId');
    }
    if (titleSeed != null && thread.title == 'Új chat') {
      thread.title = _titleFrom(titleSeed);
    }
    thread.updatedAtMillis = updatedAtMillis;
    _threadBox.put(thread);
  }

  ChatThreadEntity? _findThread(String publicId) {
    for (final thread in _threadBox.getAll()) {
      if (thread.publicId == publicId) {
        return thread;
      }
    }
    return null;
  }

  String _titleFrom(String text) {
    if (text.length <= 48) {
      return text;
    }
    return '${text.substring(0, 48)}...';
  }
}
