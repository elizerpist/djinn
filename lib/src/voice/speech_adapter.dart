import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as speech_to_text;

import '../debug/debug_console.dart';

sealed class SpeechEvent {
  const SpeechEvent();

  const factory SpeechEvent.status(String status) = SpeechStatusEvent;

  const factory SpeechEvent.result(String text, bool finalResult) =
      SpeechResultEvent;

  const factory SpeechEvent.error(String code) = SpeechErrorEvent;
}

class SpeechStatusEvent extends SpeechEvent {
  const SpeechStatusEvent(this.status);

  final String status;
}

class SpeechResultEvent extends SpeechEvent {
  const SpeechResultEvent(this.text, this.finalResult);

  final String text;
  final bool finalResult;
}

class SpeechErrorEvent extends SpeechEvent {
  const SpeechErrorEvent(this.code);

  final String code;
}

abstract class SpeechAdapter {
  Stream<SpeechEvent> listen({required String locale});

  Future<void> stop();
}

typedef SpeechStatusCallback = void Function(String status);
typedef SpeechErrorCallback = void Function(String code);
typedef SpeechResultCallback = void Function(String text, bool finalResult);

abstract class SpeechRecognitionEngine {
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  });

  Future<List<String>> locales();

  Future<String?> systemLocale();

  Future<void> listen({
    required String locale,
    required SpeechResultCallback onResult,
  });

  Future<void> stop();
}

class PluginSpeechRecognitionEngine implements SpeechRecognitionEngine {
  PluginSpeechRecognitionEngine({speech_to_text.SpeechToText? speech})
    : _speech = speech ?? speech_to_text.SpeechToText();

  final speech_to_text.SpeechToText _speech;

  @override
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  }) {
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
      options: [
        speech_to_text.SpeechToText.androidNoBluetooth,
        speech_to_text.SpeechToText.androidIntentLookup,
        speech_to_text.SpeechToText.iosNoBluetooth,
      ],
    );
  }

  @override
  Future<List<String>> locales() async {
    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList(growable: false);
  }

  @override
  Future<String?> systemLocale() async {
    final locale = await _speech.systemLocale();
    return locale?.localeId;
  }

  @override
  Future<void> listen({
    required String locale,
    required SpeechResultCallback onResult,
  }) {
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: speech_to_text.SpeechListenOptions(
        localeId: locale,
        partialResults: true,
        cancelOnError: true,
        listenMode: speech_to_text.ListenMode.dictation,
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(minutes: 2),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}

class SpeechToTextAdapter implements SpeechAdapter {
  SpeechToTextAdapter({SpeechRecognitionEngine? engine})
    : _engine = engine ?? PluginSpeechRecognitionEngine();

  final SpeechRecognitionEngine _engine;
  StreamController<SpeechEvent>? _activeController;
  SpeechResultCallback? _activeResultCallback;
  String? _activeResolvedLocale;
  Future<bool>? _initialization;
  var _initialized = false;
  var _unsupportedRetryAttempted = false;

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    final controller = StreamController<SpeechEvent>();
    _activeController = controller;

    Future<void>(() async {
      try {
        final available = await _ensureInitialized();
        DebugConsole.log(
          '[Voice/STT] permission status=${available ? 'granted' : 'denied'}',
        );
        if (!available) {
          _addTo(controller, const SpeechEvent.error('error_permission'));
          _close(controller);
          return;
        }
        final resolvedLocale = await _resolveLocale(locale);
        _activeResolvedLocale = resolvedLocale;
        _unsupportedRetryAttempted = false;
        _activeResultCallback = (text, finalResult) =>
            _addTo(controller, SpeechEvent.result(text, finalResult));
        await _listenWithResolvedLocale(controller, resolvedLocale);
      } catch (error) {
        _addTo(controller, SpeechEvent.error(error.toString()));
        _close(controller);
      }
    });

    controller.onCancel = () async {
      if (_activeController == controller) {
        _activeController = null;
      }
      await stop();
    };
    return controller.stream;
  }

  @override
  Future<void> stop() => _engine.stop();

  Future<void> _listenWithResolvedLocale(
    StreamController<SpeechEvent> controller,
    String locale,
  ) async {
    final onResult = _activeResultCallback;
    if (_activeController != controller || onResult == null) {
      return;
    }
    await _engine.listen(locale: locale, onResult: onResult);
  }

  Future<String> _resolveLocale(String requestedLocale) async {
    final normalized = _normalizeLocale(requestedLocale);
    final locales = await _normalizedLocales();
    if (locales.isEmpty) {
      return normalized;
    }
    if (locales.contains(normalized)) {
      return normalized;
    }
    final language = _languagePart(normalized);
    for (final locale in locales) {
      if (_languagePart(locale) == language) {
        DebugConsole.log(
          '[Voice/STT] locale fallback from=$requestedLocale to=$locale reason=language_variant',
        );
        return locale;
      }
    }
    final systemLocale = await _normalizedSystemLocale();
    if (systemLocale != null) {
      DebugConsole.log(
        '[Voice/STT] locale fallback from=$requestedLocale to=$systemLocale reason=unsupported_locale',
      );
      return systemLocale;
    }
    return normalized;
  }

  Future<Set<String>> _normalizedLocales() async {
    try {
      return (await _engine.locales())
          .map(_normalizeLocale)
          .where((locale) => locale.isNotEmpty)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<String?> _normalizedSystemLocale() async {
    try {
      final locale = await _engine.systemLocale();
      if (locale == null || locale.trim().isEmpty) {
        return null;
      }
      return _normalizeLocale(locale);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) {
      return true;
    }
    final initialization =
        _initialization ??
        _engine.initialize(onStatus: _handleStatus, onError: _handleError).then(
          (available) {
            _initialized = available;
            if (!available) {
              _initialization = null;
            }
            return available;
          },
        );
    _initialization = initialization;
    return initialization;
  }

  void _handleStatus(String status) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }
    _addTo(controller, SpeechEvent.status(status));
    if (status == 'done') {
      Future<void>.delayed(
        const Duration(milliseconds: 200),
        () => _close(controller),
      );
    }
  }

  void _handleError(String code) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }
    if (code == 'error_language_not_supported' && !_unsupportedRetryAttempted) {
      _unsupportedRetryAttempted = true;
      Future<void>(() async {
        final from = _activeResolvedLocale;
        final fallback = await _normalizedSystemLocale();
        if (fallback != null &&
            fallback != from &&
            _activeController == controller) {
          DebugConsole.log(
            '[Voice/STT] locale fallback from=$from to=$fallback reason=error_language_not_supported',
          );
          _activeResolvedLocale = fallback;
          await _listenWithResolvedLocale(controller, fallback);
          return;
        }
        _addTo(controller, SpeechEvent.error(code));
        _close(controller);
      });
      return;
    }
    _addTo(controller, SpeechEvent.error(code));
    _close(controller);
  }

  void _addTo(StreamController<SpeechEvent> controller, SpeechEvent event) {
    if (_activeController == controller && !controller.isClosed) {
      controller.add(event);
    }
  }

  void _close(StreamController<SpeechEvent> controller) {
    if (_activeController == controller) {
      _activeController = null;
      _activeResultCallback = null;
      _activeResolvedLocale = null;
    }
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

String _normalizeLocale(String locale) {
  final trimmed = locale.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return trimmed.replaceAll('-', '_');
}

String _languagePart(String locale) {
  final separator = locale.contains('_') ? '_' : '-';
  return locale.split(separator).first.toLowerCase();
}

class FakeSpeechAdapter implements SpeechAdapter {
  FakeSpeechAdapter({required this.events});

  final List<SpeechEvent> events;
  var stopCount = 0;

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    return Stream<SpeechEvent>.fromIterable(events);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
