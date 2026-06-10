import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/voice/speech_adapter.dart';

void main() {
  test(
    'reuses initialization while routing callbacks to current listen stream',
    () async {
      final engine = _FakeSpeechRecognitionEngine();
      final adapter = SpeechToTextAdapter(engine: engine);

      final first = <SpeechEvent>[];
      final firstSubscription = adapter
          .listen(locale: 'hu-HU')
          .listen(first.add);
      await Future<void>.delayed(Duration.zero);
      engine.emitError('error_speech_timeout');
      await Future<void>.delayed(Duration.zero);
      await firstSubscription.cancel();

      final second = <SpeechEvent>[];
      final secondSubscription = adapter
          .listen(locale: 'hu-HU')
          .listen(second.add);
      await Future<void>.delayed(Duration.zero);
      engine.emitError('error_speech_timeout');
      await Future<void>.delayed(Duration.zero);
      await secondSubscription.cancel();

      expect(engine.initializeCount, 1);
      expect(
        first.whereType<SpeechErrorEvent>().single.code,
        'error_speech_timeout',
      );
      expect(
        second.whereType<SpeechErrorEvent>().single.code,
        'error_speech_timeout',
      );
    },
  );
}

class _FakeSpeechRecognitionEngine implements SpeechRecognitionEngine {
  SpeechStatusCallback? _onStatus;
  SpeechErrorCallback? _onError;
  SpeechResultCallback? _onResult;
  var initializeCount = 0;

  @override
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  }) async {
    initializeCount += 1;
    _onStatus = onStatus;
    _onError = onError;
    return true;
  }

  @override
  Future<void> listen({
    required String locale,
    required SpeechResultCallback onResult,
  }) async {
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {}

  void emitError(String code) => _onError?.call(code);

  // Keeps the fake API complete for future adapter tests.
  void emitStatus(String status) => _onStatus?.call(status);

  void emitResult(String text, bool finalResult) =>
      _onResult?.call(text, finalResult);
}
