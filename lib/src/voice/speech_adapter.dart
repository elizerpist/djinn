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
    required String? locale,
    required SpeechResultCallback onResult,
  });

  Future<void> stop();
}

class PluginSpeechRecognitionEngine implements SpeechRecognitionEngine {
  PluginSpeechRecognitionEngine({speech_to_text.SpeechToText? speech})
    : _speech = speech ?? speech_to_text.SpeechToText();

  static final initializationOptions = [
    speech_to_text.SpeechToText.androidNoBluetooth,
    speech_to_text.SpeechToText.iosNoBluetooth,
  ];

  final speech_to_text.SpeechToText _speech;

  @override
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  }) {
    DebugConsole.log(
      '[Voice/STT] plugin initialize options=${initializationOptions.join(',')}',
    );
    return _speech.initialize(
      onStatus: onStatus,
      onError: (error) => onError(error.errorMsg),
      options: initializationOptions,
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
    required String? locale,
    required SpeechResultCallback onResult,
  }) {
    DebugConsole.log(
      '[Voice/STT] plugin listen locale=${locale ?? 'system_default'} '
      'partial=true cancelOnError=true mode=confirmation pauseFor=8s listenFor=2m',
    );
    return _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: speech_to_text.SpeechListenOptions(
        localeId: locale,
        partialResults: true,
        cancelOnError: true,
        listenMode: speech_to_text.ListenMode.confirmation,
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
  var _activeSessionId = 0;
  Stopwatch? _activeStopwatch;
  Future<bool>? _initialization;
  var _initialized = false;
  var _unsupportedRetryAttempted = false;
  var _startupRetryAttempted = false;
  var _startupRetryInProgress = false;
  var _hasSpeechResult = false;

  static const startupRetryDelay = Duration(milliseconds: 350);

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    final controller = StreamController<SpeechEvent>();
    final sessionId = _activeSessionId + 1;
    _activeSessionId = sessionId;
    _activeStopwatch = Stopwatch()..start();
    _activeController = controller;
    _hasSpeechResult = false;

    DebugConsole.log(
      '[Voice/STT] session=$sessionId adapter listen requested locale=$locale',
    );

    Future<void>(() async {
      try {
        final available = await _ensureInitialized();
        DebugConsole.log(
          '[Voice/STT] session=$sessionId permission status=${available ? 'granted' : 'denied'} '
          'elapsed=${_elapsedMs()}ms',
        );
        if (!available) {
          _addTo(controller, const SpeechEvent.error('error_permission'));
          _close(controller);
          return;
        }
        final resolvedLocale = await _resolveLocale(locale);
        _activeResolvedLocale = resolvedLocale;
        _unsupportedRetryAttempted = false;
        _startupRetryAttempted = false;
        _startupRetryInProgress = false;
        _activeResultCallback = (text, finalResult) {
          if (text.trim().isNotEmpty) {
            _hasSpeechResult = true;
          }
          _addTo(controller, SpeechEvent.result(text, finalResult));
        };
        await _listenWithResolvedLocale(controller, resolvedLocale);
      } catch (error) {
        DebugConsole.log(
          '[Voice/STT] session=$sessionId adapter listen failed error=$error '
          'elapsed=${_elapsedMs()}ms',
        );
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
    String? locale,
  ) async {
    final onResult = _activeResultCallback;
    if (_activeController != controller || onResult == null) {
      return;
    }
    DebugConsole.log(
      '[Voice/STT] session=$_activeSessionId engine listen locale=${locale ?? 'system_default'} '
      'elapsed=${_elapsedMs()}ms',
    );
    await _engine.listen(locale: locale, onResult: onResult);
    DebugConsole.log(
      '[Voice/STT] session=$_activeSessionId engine listen returned '
      'elapsed=${_elapsedMs()}ms',
    );
  }

  Future<String> _resolveLocale(String requestedLocale) async {
    final normalized = _normalizeLocale(requestedLocale);
    final locales = await _normalizedLocales();
    final systemLocale = await _normalizedSystemLocale();
    String selected = normalized;
    String? fallbackReason;
    if (locales.contains(normalized)) {
      selected = normalized;
    } else if (locales.isNotEmpty) {
      final language = _languagePart(normalized);
      for (final locale in locales) {
        if (_languagePart(locale) == language) {
          selected = locale;
          fallbackReason = 'language_variant';
          break;
        }
      }
      if (selected == normalized && systemLocale != null) {
        selected = systemLocale;
        fallbackReason = 'unsupported_locale';
      }
    } else if (systemLocale != null) {
      selected = systemLocale;
      fallbackReason = 'unsupported_locale';
    }
    DebugConsole.log(
      '[Voice/STT] session=$_activeSessionId locale requested=$requestedLocale normalized=$normalized '
      'system=${systemLocale ?? 'none'} available=${locales.length} '
      'selected=$selected sample=${_localeSample(locales)}',
    );
    if (fallbackReason != null) {
      DebugConsole.log(
        '[Voice/STT] locale fallback from=$requestedLocale to=$selected reason=$fallbackReason',
      );
    }
    return selected;
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
      DebugConsole.log(
        '[Voice/STT] session=$_activeSessionId initialize reused=true '
        'elapsed=${_elapsedMs()}ms',
      );
      return true;
    }
    DebugConsole.log(
      '[Voice/STT] session=$_activeSessionId initialize start '
      'elapsed=${_elapsedMs()}ms',
    );
    final initialization =
        _initialization ??
        _engine.initialize(onStatus: _handleStatus, onError: _handleError).then((
          available,
        ) {
          _initialized = available;
          if (!available) {
            _initialization = null;
          }
          DebugConsole.log(
            '[Voice/STT] session=$_activeSessionId initialize result=$available '
            'elapsed=${_elapsedMs()}ms',
          );
          return available;
        });
    _initialization = initialization;
    return initialization;
  }

  void _handleStatus(String status) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }
    DebugConsole.log(
      '[Voice/STT] session=$_activeSessionId adapter status=$status '
      'elapsed=${_elapsedMs()}ms',
    );
    _addTo(controller, SpeechEvent.status(status));
    if (status == 'done') {
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (_startupRetryInProgress && _activeController == controller) {
          DebugConsole.log(
            '[Voice/STT] session=$_activeSessionId done close delayed for retry '
            'elapsed=${_elapsedMs()}ms',
          );
          return;
        }
        _close(controller);
      });
    }
  }

  void _handleError(String code) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }
    DebugConsole.log(
      '[Voice/STT] session=$_activeSessionId adapter error code=$code '
      'locale=${_activeResolvedLocale ?? 'system_default'} '
      'hasResult=$_hasSpeechResult elapsed=${_elapsedMs()}ms',
    );
    if (_isRetryableStartupError(code)) {
      _startupRetryAttempted = true;
      _startupRetryInProgress = true;
      Future<void>(() async {
        try {
          await _engine.stop();
          await Future<void>.delayed(startupRetryDelay);
          if (_activeController != controller) {
            return;
          }
          DebugConsole.log(
            '[Voice/STT] session=$_activeSessionId retry start reason=$code '
            'locale=${_activeResolvedLocale ?? 'system_default'} delayMs=${startupRetryDelay.inMilliseconds}',
          );
          await _listenWithResolvedLocale(controller, _activeResolvedLocale);
        } catch (error) {
          DebugConsole.log(
            '[Voice/STT] session=$_activeSessionId retry failed error=$error',
          );
          _addTo(controller, SpeechEvent.error(error.toString()));
          _close(controller);
        } finally {
          _startupRetryInProgress = false;
        }
      });
      return;
    }
    if (code == 'error_language_not_supported' && !_unsupportedRetryAttempted) {
      _unsupportedRetryAttempted = true;
      _startupRetryInProgress = true;
      Future<void>(() async {
        try {
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
          if (_activeController == controller && from != null) {
            DebugConsole.log(
              '[Voice/STT] locale fallback from=$from to=system_default '
              'reason=error_language_not_supported',
            );
            _activeResolvedLocale = null;
            await _listenWithResolvedLocale(controller, null);
            return;
          }
          _addTo(controller, SpeechEvent.error(code));
          _close(controller);
        } catch (error) {
          DebugConsole.log('[Voice/STT] locale fallback failed error=$error');
          _addTo(controller, SpeechEvent.error(error.toString()));
          _close(controller);
        } finally {
          _startupRetryInProgress = false;
        }
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
      _activeStopwatch = null;
      _startupRetryInProgress = false;
    }
    if (!controller.isClosed) {
      controller.close();
    }
  }

  bool _isRetryableStartupError(String code) {
    return !_startupRetryAttempted &&
        !_hasSpeechResult &&
        (code == 'error_server_disconnected' ||
            code == 'error_audio_error' ||
            code == 'error_client');
  }

  int _elapsedMs() => _activeStopwatch?.elapsedMilliseconds ?? -1;
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

String _localeSample(Set<String> locales) {
  if (locales.isEmpty) {
    return '[]';
  }
  return '[${locales.take(8).join(',')}]';
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
