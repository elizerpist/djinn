import '../../openai/openai_client.dart';
import 'local_answer_service.dart';
import 'local_chat_repository.dart';

class ChatService {
  ChatService({required this.repository, required this.answerService});

  final LocalChatRepository repository;
  final AnswerService answerService;

  Future<void> sendMessage(String conversationId, String text) async {
    final userMessage = await repository.appendUserMessage(
      conversationId,
      text,
    );
    try {
      final response = await answerService.answer(userMessage.text);
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
}
