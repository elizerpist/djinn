import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_error.dart';
import 'package:djinn/src/ai/ai_provider.dart';

void main() {
  group('AiFailure', () {
    test('classifies quota and high demand retry policy by provider', () {
      final quota = AiFailure.quota(
        AiProvider.gemini,
        'billing account is not enabled',
      );
      final highDemand = AiFailure.highDemand(
        AiProvider.openAi,
        'service overloaded',
      );
      final keyFailure = AiFailure.keyTestFailed(
        AiProvider.gemini,
        'API key not valid',
      );

      expect(quota.provider, AiProvider.gemini);
      expect(quota.code, AiFailureCode.quotaOrBilling);
      expect(quota.retryable, isFalse);
      expect(highDemand.provider, AiProvider.openAi);
      expect(highDemand.code, AiFailureCode.highDemand);
      expect(highDemand.retryable, isTrue);
      expect(keyFailure.code, AiFailureCode.keyTestFailed);
      expect(keyFailure.retryable, isFalse);
    });

    test('uses required Gemini structured response message', () {
      final failure = AiFailure.invalidStructuredResponse(
        AiProvider.gemini,
        'missing chunks',
      );

      expect(
        failure.userMessage,
        contains('Gemini hibas strukturalt valaszt adott'),
      );
    });
  });
}
