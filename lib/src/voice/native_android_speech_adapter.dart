import 'dart:async';

import 'package:flutter/services.dart';

import '../debug/debug_console.dart';
import 'speech_adapter.dart';
import 'voice_channels.dart';

class NativeAndroidSpeechAdapter implements SpeechAdapter {
  NativeAndroidSpeechAdapter({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? const MethodChannel(VoiceChannels.method),
       _eventChannel = eventChannel ?? const EventChannel(VoiceChannels.events);

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  StreamController<SpeechEvent>? _activeController;
  StreamSubscription<dynamic>? _eventSubscription;
  int _sessionCounter = 0;
  int _activeSessionId = 0;

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    final controller = StreamController<SpeechEvent>();
    final sessionId = ++_sessionCounter;

    DebugConsole.log('[Voice/PTT] listen start locale=$locale');

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
        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            final mapped = _mapEvent(event);
            if (mapped != null) {
              controller.add(mapped);
              if (_isTerminal(mapped)) {
                _close(controller);
              }
            }
          },
          onError: (Object error) {
            controller.add(SpeechEvent.error(error.toString()));
            _close(controller);
          },
          onDone: () {
            _close(controller);
          },
          cancelOnError: true,
        );
        if (_activeController != controller || _activeSessionId != sessionId) {
          return;
        }
        await _methodChannel.invokeMethod<void>('start', <String, dynamic>{
          'locale': locale,
        });
      } on MissingPluginException catch (error) {
        DebugConsole.log('[Voice/PTT] missing plugin error=$error');
        controller.add(const SpeechEvent.error('error_plugin_missing'));
        _close(controller);
      } on PlatformException catch (error) {
        final code = switch (error.code) {
          'permission_denied' => 'error_permission',
          'unavailable' => 'error_unavailable',
          _ => error.code.isEmpty ? 'error_unknown' : error.code,
        };
        DebugConsole.log('[Voice/PTT] platform error code=$code error=$error');
        controller.add(SpeechEvent.error(code));
        _close(controller);
      } catch (error) {
        DebugConsole.log('[Voice/PTT] listen failed error=$error');
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
    _activeSessionId = 0;
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } catch (_) {}
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    final controller = _activeController;
    if (controller != null) {
      _close(controller);
    }
  }

  SpeechEvent? _mapEvent(dynamic event) {
    if (event is! Map) {
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

  bool _isTerminal(SpeechEvent event) {
    return switch (event) {
      SpeechResultEvent(:final finalResult) => finalResult,
      SpeechErrorEvent() => true,
      _ => false,
    };
  }

  void _close(StreamController<SpeechEvent> controller) {
    if (_activeController == controller) {
      _activeController = null;
      _activeSessionId = 0;
    }
    if (!controller.isClosed) {
      controller.close();
    }
  }
}
