import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech_to_text;

import 'package:djinn/src/voice/speech_adapter.dart';

void main() {
  test(
    'plugin engine uses Android default recognizer instead of intent lookup',
    () {
      expect(
        PluginSpeechRecognitionEngine.initializationOptions,
        contains(speech_to_text.SpeechToText.androidNoBluetooth),
      );
      expect(
        PluginSpeechRecognitionEngine.initializationOptions,
        isNot(contains(speech_to_text.SpeechToText.androidIntentLookup)),
      );
    },
  );

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

  test(
    'normalizes hyphenated Android locale to installed underscore locale',
    () async {
      final engine = _FakeSpeechRecognitionEngine(
        localeIds: const ['hu_HU', 'en_US'],
        systemLocaleId: 'en_US',
      );
      final adapter = SpeechToTextAdapter(engine: engine);

      final subscription = adapter.listen(locale: 'hu-HU').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(engine.listenLocales, ['hu_HU']);
    },
  );

  test(
    'falls back to system locale when requested locale is unavailable',
    () async {
      final engine = _FakeSpeechRecognitionEngine(
        localeIds: const ['en_US'],
        systemLocaleId: 'en_US',
      );
      final adapter = SpeechToTextAdapter(engine: engine);

      final subscription = adapter.listen(locale: 'hu-HU').listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(engine.listenLocales, ['en_US']);
    },
  );

  test('retries with system locale after unsupported language error', () async {
    final engine = _FakeSpeechRecognitionEngine(
      localeIds: const ['hu_HU', 'en_US'],
      systemLocaleId: 'en_US',
    );
    final adapter = SpeechToTextAdapter(engine: engine);
    final events = <SpeechEvent>[];

    final subscription = adapter.listen(locale: 'hu-HU').listen(events.add);
    await Future<void>.delayed(Duration.zero);
    engine.emitError('error_language_not_supported');
    await Future<void>.delayed(Duration.zero);
    engine.emitResult('hello', true);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(engine.listenLocales, ['hu_HU', 'en_US']);
    expect(events.whereType<SpeechResultEvent>().single.text, 'hello');
  });

  test(
    'falls back to system default when unsupported language has no alternate locale',
    () async {
      final engine = _FakeSpeechRecognitionEngine(
        localeIds: const ['hu_HU'],
        systemLocaleId: 'hu_HU',
      );
      final adapter = SpeechToTextAdapter(engine: engine);
      final events = <SpeechEvent>[];

      final subscription = adapter.listen(locale: 'hu-HU').listen(events.add);
      await Future<void>.delayed(Duration.zero);
      engine.emitError('error_language_not_supported');
      await Future<void>.delayed(Duration.zero);
      engine.emitResult('szia', true);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(engine.listenLocales, ['hu_HU', null]);
      expect(events.whereType<SpeechResultEvent>().single.text, 'szia');
    },
  );

  test('retries transient startup disconnect once before failing', () async {
    final engine = _FakeSpeechRecognitionEngine(
      localeIds: const ['hu_HU'],
      systemLocaleId: 'hu_HU',
    );
    final adapter = SpeechToTextAdapter(engine: engine);
    final events = <SpeechEvent>[];

    final subscription = adapter.listen(locale: 'hu-HU').listen(events.add);
    await Future<void>.delayed(Duration.zero);
    engine.emitStatus('notListening');
    engine.emitStatus('done');
    engine.emitError('error_server_disconnected');
    await Future<void>.delayed(
      SpeechToTextAdapter.startupRetryDelay + const Duration(milliseconds: 50),
    );
    engine.emitResult('ujraindult', true);
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(engine.stopCount, 2);
    expect(engine.listenLocales, ['hu_HU', 'hu_HU']);
    expect(events.whereType<SpeechErrorEvent>(), isEmpty);
    expect(events.whereType<SpeechResultEvent>().single.text, 'ujraindult');
  });
}

class _FakeSpeechRecognitionEngine implements SpeechRecognitionEngine {
  _FakeSpeechRecognitionEngine({
    this.localeIds = const ['hu_HU'],
    this.systemLocaleId = 'hu_HU',
  });

  final List<String> localeIds;
  final String? systemLocaleId;
  SpeechStatusCallback? _onStatus;
  SpeechErrorCallback? _onError;
  SpeechResultCallback? _onResult;
  var initializeCount = 0;
  var stopCount = 0;
  final listenLocales = <String?>[];

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
    required String? locale,
    required SpeechResultCallback onResult,
  }) async {
    listenLocales.add(locale);
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<List<String>> locales() async => localeIds;

  @override
  Future<String?> systemLocale() async => systemLocaleId;

  void emitError(String code) => _onError?.call(code);

  // Keeps the fake API complete for future adapter tests.
  void emitStatus(String status) => _onStatus?.call(status);

  void emitResult(String text, bool finalResult) =>
      _onResult?.call(text, finalResult);
}
