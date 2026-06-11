import 'dart:async';

import 'package:flutter/services.dart';

import '../debug/debug_console.dart';
import 'speech_adapter.dart';
import 'voice_channels.dart';

class NativeAndroidSpeechAdapter implements SpeechAdapter {
  NativeAndroidSpeechAdapter({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    this.stopGracePeriod = const Duration(milliseconds: 1800),
    this.debugLabel = 'PTT',
    this.completeSilenceTimeout,
    this.possibleCompleteSilenceTimeout,
    this.minimumSpeechLength,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel(VoiceChannels.method),
       _eventChannel =
           eventChannel ?? const EventChannel(VoiceChannels.events);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final Duration stopGracePeriod;
  final String debugLabel;
  final Duration? completeSilenceTimeout;
  final Duration? possibleCompleteSilenceTimeout;
  final Duration? minimumSpeechLength;

  StreamController<SpeechEvent>? _activeController;
  StreamSubscription<dynamic>? _eventSubscription;
  Timer? _stopGraceTimer;
  Completer<void>? _stopCompleter;
  String? _bestPartialTranscript;
  bool _stopRequested = false;
  int _sessionCounter = 0;
  int _activeSessionId = 0;
  int? _activeNativeSessionId;

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    final controller = StreamController<SpeechEvent>();
    final sessionId = ++_sessionCounter;

    DebugConsole.log('[Voice/$debugLabel] listen start locale=$locale');

    Future<void>(() async {
      try {
        if (_activeController != null) {
          await stop();
        }
        if (_activeSessionId != 0 || _activeController != null) {
          return;
        }
        _activeSessionId = sessionId;
        _activeController = controller;
        _bestPartialTranscript = null;
        _stopRequested = false;
        _stopCompleter = null;
        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            _handleEvent(controller, event);
          },
          onError: (Object error) {
            _addTo(controller, SpeechEvent.error(error.toString()));
            _close(controller);
          },
          onDone: () {
            _commitBestPartialIfNeeded(controller, reason: 'stream_done');
            _close(controller);
          },
          cancelOnError: true,
        );
        if (_activeController != controller || _activeSessionId != sessionId) {
          return;
        }
        final result = await _methodChannel.invokeMethod<dynamic>(
          'start',
          <String, dynamic>{
            'locale': locale,
            if (completeSilenceTimeout case final timeout?)
              'completeSilenceMillis': timeout.inMilliseconds,
            if (possibleCompleteSilenceTimeout case final timeout?)
              'possibleCompleteSilenceMillis': timeout.inMilliseconds,
            if (minimumSpeechLength case final timeout?)
              'minimumSpeechMillis': timeout.inMilliseconds,
          },
        );
        final nativeSessionId = _nativeSessionIdFromResult(result);
        if (_activeController != controller || _activeSessionId != sessionId) {
          return;
        }
        _activeNativeSessionId = nativeSessionId;
        if (nativeSessionId != null) {
          DebugConsole.log('[Voice/$debugLabel] native session=$nativeSessionId');
        }
      } on MissingPluginException catch (error) {
        DebugConsole.log('[Voice/$debugLabel] missing plugin error=$error');
        controller.add(const SpeechEvent.error('error_plugin_missing'));
        _close(controller);
      } on PlatformException catch (error) {
        final code = switch (error.code) {
          'permission_denied' => 'error_permission',
          'unavailable' => 'error_unavailable',
          _ => error.code.isEmpty ? 'error_unknown' : error.code,
        };
        DebugConsole.log(
          '[Voice/$debugLabel] platform error code=$code error=$error',
        );
        controller.add(SpeechEvent.error(code));
        _close(controller);
      } catch (error) {
        DebugConsole.log('[Voice/$debugLabel] listen failed error=$error');
        controller.add(SpeechEvent.error(error.toString()));
        _close(controller);
      }
    });

    controller.onCancel = () async {
      await stop();
    };
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    final controller = _activeController;
    if (controller == null) {
      return;
    }
    if (_stopRequested) {
      await _stopCompleter?.future;
      return;
    }
    _stopRequested = true;
    final completion = Completer<void>();
    _stopCompleter = completion;
    DebugConsole.log(
      '[Voice/$debugLabel] stop requested graceMs=${stopGracePeriod.inMilliseconds}',
    );
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } catch (_) {}
    if (_activeController != controller) {
      if (!completion.isCompleted) {
        completion.complete();
      }
      return;
    }
    _stopGraceTimer?.cancel();
    _stopGraceTimer = Timer(stopGracePeriod, () {
      DebugConsole.log('[Voice/$debugLabel] stop grace elapsed');
      _commitBestPartialIfNeeded(controller, reason: 'stop_timeout');
      _close(controller);
    });
    await completion.future;
  }

  void _handleEvent(StreamController<SpeechEvent> controller, dynamic event) {
    final mapped = _mapEvent(event);
    if (mapped == null) {
      return;
    }
    switch (mapped) {
      case SpeechResultEvent(:final text, :final finalResult):
        _rememberBestPartial(text);
        _addTo(controller, mapped);
        if (finalResult) {
          _close(controller);
        }
      case SpeechErrorEvent(:final code):
        if (_isRecoverableNoResultError(code) &&
            _commitBestPartialIfNeeded(controller, reason: code)) {
          _close(controller);
          return;
        }
        _addTo(controller, mapped);
        _close(controller);
      case SpeechStatusEvent(:final status):
        _addTo(controller, mapped);
        if (_stopRequested && status == 'done') {
          _commitBestPartialIfNeeded(controller, reason: 'done_status');
          _close(controller);
        }
    }
  }

  SpeechEvent? _mapEvent(dynamic event) {
    if (event is! Map) {
      return null;
    }
    final eventSessionId = event['sessionId'];
    final nativeSessionId = _activeNativeSessionId;
    if (eventSessionId is num &&
        nativeSessionId != null &&
        eventSessionId.toInt() != nativeSessionId) {
      DebugConsole.log(
        '[Voice/$debugLabel] drop stale event session=${eventSessionId.toInt()} '
        'activeNative=$nativeSessionId',
      );
      return null;
    }
    final type = event['type']?.toString();
    switch (type) {
      case 'status':
        return SpeechEvent.status(event['status']?.toString() ?? 'unknown');
      case 'result':
        return SpeechEvent.result(
          event['text']?.toString() ?? '',
          event['final'] == true,
        );
      case 'error':
        return SpeechEvent.error(event['code']?.toString() ?? 'error_unknown');
      default:
        return null;
    }
  }

  void _rememberBestPartial(String text) {
    final transcript = text.trim();
    if (transcript.isEmpty) {
      return;
    }
    final current = _bestPartialTranscript;
    if (current == null || transcript.length >= current.length) {
      _bestPartialTranscript = transcript;
    }
  }

  bool _commitBestPartialIfNeeded(
    StreamController<SpeechEvent> controller, {
    required String reason,
  }) {
    final transcript = _bestPartialTranscript?.trim();
    if (transcript == null || transcript.isEmpty) {
      return false;
    }
    DebugConsole.log(
      '[Voice/$debugLabel] commit partial transcript reason=$reason '
      'chars=${transcript.length}',
    );
    _addTo(controller, SpeechEvent.result(transcript, true));
    return true;
  }

  bool _isRecoverableNoResultError(String code) {
    return code == 'error_no_match' || code == 'error_speech_timeout';
  }

  void _addTo(StreamController<SpeechEvent> controller, SpeechEvent event) {
    if (_activeController == controller && !controller.isClosed) {
      controller.add(event);
    }
  }

  void _close(StreamController<SpeechEvent> controller) {
    if (_activeController == controller) {
      _activeController = null;
      _activeSessionId = 0;
      _activeNativeSessionId = null;
      _stopRequested = false;
      _bestPartialTranscript = null;
      _stopGraceTimer?.cancel();
      _stopGraceTimer = null;
      final completion = _stopCompleter;
      _stopCompleter = null;
      if (completion != null && !completion.isCompleted) {
        completion.complete();
      }
      unawaited(_eventSubscription?.cancel());
      _eventSubscription = null;
    }
    if (!controller.isClosed) {
      controller.close();
    }
  }

  int? _nativeSessionIdFromResult(dynamic result) {
    if (result is! Map) {
      return null;
    }
    final value = result['sessionId'];
    return value is num ? value.toInt() : null;
  }
}
