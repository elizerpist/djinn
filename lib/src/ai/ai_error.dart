import 'ai_provider.dart';

enum AiFailureCode {
  missingApiKey,
  keyTestFailed,
  quotaOrBilling,
  highDemand,
  networkAbort,
  invalidJson,
  invalidStructuredResponse,
  unsupportedEmbedding,
  unknown,
}

class AiFailure {
  const AiFailure({
    required this.provider,
    required this.code,
    required this.message,
    required this.userMessage,
    required this.retryable,
  });

  final AiProvider provider;
  final AiFailureCode code;
  final String message;
  final String userMessage;
  final bool retryable;

  factory AiFailure.missingApiKey(AiProvider provider) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.missingApiKey,
      message: '${provider.label} API key is missing',
      userMessage: '${provider.label} API kulcs nincs beallitva.',
      retryable: false,
    );
  }

  factory AiFailure.keyTestFailed(AiProvider provider, String message) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.keyTestFailed,
      message: message,
      userMessage: '${provider.label} API kulcs teszt sikertelen.',
      retryable: false,
    );
  }

  factory AiFailure.quota(AiProvider provider, String message) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.quotaOrBilling,
      message: message,
      userMessage: '${provider.label} kvota vagy billing hiba.',
      retryable: false,
    );
  }

  factory AiFailure.highDemand(AiProvider provider, String message) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.highDemand,
      message: message,
      userMessage: '${provider.label} modell tulterhelt. Probald ujra kesobb.',
      retryable: true,
    );
  }

  factory AiFailure.networkAbort(AiProvider provider, String message) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.networkAbort,
      message: message,
      userMessage: 'Halozati kapcsolat megszakadt. Ujraprobalhato.',
      retryable: true,
    );
  }

  factory AiFailure.invalidJson(AiProvider provider, String message) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.invalidJson,
      message: message,
      userMessage: '${provider.label} hibas JSON valaszt adott.',
      retryable: true,
    );
  }

  factory AiFailure.invalidStructuredResponse(
    AiProvider provider,
    String message,
  ) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.invalidStructuredResponse,
      message: message,
      userMessage: '${provider.label} hibas strukturalt valaszt adott.',
      retryable: true,
    );
  }

  factory AiFailure.unsupportedEmbedding(AiProvider provider, String model) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.unsupportedEmbedding,
      message: 'Unsupported embedding model: $model',
      userMessage: '${provider.label} embedding modell nem tamogatott: $model',
      retryable: false,
    );
  }

  factory AiFailure.unknown(AiProvider provider, String message) {
    return AiFailure(
      provider: provider,
      code: AiFailureCode.unknown,
      message: message,
      userMessage: '${provider.label} ismeretlen AI hiba.',
      retryable: false,
    );
  }
}

class AiProviderException implements Exception {
  const AiProviderException(this.failure);

  final AiFailure failure;

  @override
  String toString() => '${failure.provider.label}: ${failure.message}';
}
