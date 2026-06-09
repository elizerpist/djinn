import '../openai/openai_client.dart';
import '../settings/models/app_settings.dart';

class ProviderRoutingAiClient implements OpenAiClient {
  ProviderRoutingAiClient({
    required this.openAiClient,
    required this.googleClient,
    required this.loadSettings,
  });

  final OpenAiClient openAiClient;
  final OpenAiClient googleClient;
  final Future<AppSettings> Function() loadSettings;

  @override
  Future<void> testApiKey({required String apiKey}) async {
    final settings = await loadSettings();
    return _clientFor(settings).testApiKey(apiKey: apiKey);
  }

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) async {
    final settings = await loadSettings();
    return _clientFor(settings).createEmbedding(input: input, model: model);
  }

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    final settings = await loadSettings();
    return _clientFor(settings).extractDocument(pdfPath: pdfPath, model: model);
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  }) async {
    final settings = await loadSettings();
    return _clientFor(
      settings,
    ).generateAnswer(model: model, question: question, evidence: evidence);
  }

  @override
  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<OpenAiEvidence> evidence,
  }) async {
    final settings = await loadSettings();
    return _clientFor(
      settings,
    ).verifyGroundedness(model: model, answer: answer, evidence: evidence);
  }

  OpenAiClient _clientFor(AppSettings settings) {
    return settings.usesGoogle ? googleClient : openAiClient;
  }
}
