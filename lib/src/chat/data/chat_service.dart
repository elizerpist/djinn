import '../../openai/openai_client.dart';
import 'local_answer_service.dart';
import 'local_chat_repository.dart';
import '../models/chat_message.dart';

class ChatService {
  ChatService({required this.repository, required this.answerService});

  final LocalChatRepository repository;
  final AnswerService answerService;

  Future<void> sendMessage(String conversationId, String text) async {
    final context = _recentContext(await repository.getMessages(conversationId));
    final userMessage = await repository.appendUserMessage(
      conversationId,
      text,
    );
    try {
      final response = await answerService.answer(
        userMessage.text,
        context: context,
      );
      await repository.appendAssistantMessage(
        conversationId,
        text: response.text,
        status: response.status,
        refusalReason: response.refusalReason,
        citations: response.citations,
        hasValidationWarning: response.hasValidationWarning,
        warningText: response.warningText,
      );
    } on OpenAiException {
      await repository.appendAssistantMessage(
        conversationId,
        text:
            'OpenAI hiba történt. A kérdés megmaradt a chatben, próbáld újra később.',
        status: 'openai_error',
        refusalReason: 'openai_error',
      );
    }
  }

  List<ChatMessage> _recentContext(List<ChatMessage> messages) {
    const maxContextMessages = 6;
    return messages
        .where((message) => message.text.trim().isNotEmpty)
        .toList(growable: false)
        .reversed
        .take(maxContextMessages)
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }
}
