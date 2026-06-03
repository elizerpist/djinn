import 'backend_chat_client.dart';
import 'local_chat_repository.dart';

class ChatService {
  ChatService({required this.repository, required this.backend});

  final LocalChatRepository repository;
  final BackendChatClient backend;

  Future<void> sendMessage(String conversationId, String text) async {
    final userMessage = await repository.appendUserMessage(
      conversationId,
      text,
    );
    try {
      final response = await backend.sendMessage(
        message: userMessage.text,
        conversationId: conversationId,
      );
      await repository.appendAssistantMessage(
        conversationId,
        text: response.answer,
        status: response.status,
        refusalReason: response.refusalReason,
        citations: response.citations,
      );
    } on BackendChatException {
      await repository.appendAssistantMessage(
        conversationId,
        text:
            'Backend nem erheto el. A kerdes megmaradt a chatben, probald ujra kesobb.',
        status: 'backend_unavailable',
        refusalReason: 'backend_unavailable',
      );
    }
  }
}
