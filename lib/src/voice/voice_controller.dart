import 'dart:async';

import 'package:flutter/foundation.dart';

import '../debug/debug_console.dart';
import 'speech_adapter.dart';
import 'tts_adapter.dart';

enum VoiceState { idle, listening, noSpeech, sending, speaking, paused, error }

class VoiceController extends ChangeNotifier {
  VoiceController({
    required this.speech,
    required this.tts,
    required this.onFinalTranscript,
  });

  final SpeechAdapter speech;
  final TtsAdapter tts;
  final Future<void> Function(String text) onFinalTranscript;

  VoiceState _state = VoiceState.idle;
  String? _lastSpeakingText;
  var _disposed = false;

  VoiceState get state => _state;

  bool get isListening => _state == VoiceState.listening;

  bool get isSpeaking => _state == VoiceState.speaking;

  bool get isPaused => _state == VoiceState.paused;

  Future<void> listenOnce({required String locale}) async {
    if (_state == VoiceState.listening || _state == VoiceState.sending) {
      return;
    }
    if (_state == VoiceState.speaking || _state == VoiceState.paused) {
      await stopTts();
    }

    _setState(VoiceState.listening);
    DebugConsole.log('[Voice/STT] listen start locale=$locale');
    var sentFinal = false;
    String? bestPartialTranscript;
    try {
      await for (final event in speech.listen(locale: locale)) {
        switch (event) {
          case SpeechStatusEvent(:final status):
            DebugConsole.log('[Voice/STT] status=$status');
          case SpeechResultEvent(:final text, :final finalResult):
            DebugConsole.log(
              '[Voice/STT] result chars=${text.length} final=$finalResult',
            );
            final transcript = text.trim();
            if (transcript.isNotEmpty &&
                (bestPartialTranscript == null ||
                    transcript.length > bestPartialTranscript.length)) {
              bestPartialTranscript = transcript;
              DebugConsole.log(
                '[Voice/STT] partial transcript updated chars=${transcript.length}',
              );
            }
            if (finalResult && transcript.isNotEmpty && !sentFinal) {
              sentFinal = true;
              await _commitTranscript(transcript);
            }
          case SpeechErrorEvent(:final code):
            DebugConsole.log('[Voice/STT] error code=$code');
            if (!sentFinal) {
              _setState(
                code == 'error_speech_timeout'
                    ? VoiceState.noSpeech
                    : VoiceState.error,
              );
            }
        }
      }
      if (!sentFinal) {
        final fallbackTranscript = bestPartialTranscript;
        if (fallbackTranscript != null && fallbackTranscript.isNotEmpty) {
          sentFinal = true;
          DebugConsole.log(
            '[Voice/STT] commit partial transcript reason=stream_closed '
            'chars=${fallbackTranscript.length}',
          );
          await _commitTranscript(fallbackTranscript);
        } else if (_state == VoiceState.listening) {
          _setState(VoiceState.noSpeech);
        }
      }
    } catch (error) {
      DebugConsole.log('[Voice/STT] error code=$error');
      if (!sentFinal) {
        _setState(VoiceState.error);
      }
    }
  }

  Future<void> _commitTranscript(String transcript) async {
    _setState(VoiceState.sending);
    try {
      await onFinalTranscript(transcript);
      _setState(VoiceState.idle);
    } catch (error) {
      DebugConsole.log('[Voice/STT] send failed error=$error');
      _setState(VoiceState.error);
    }
  }

  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    final spokenText = text.trim();
    if (spokenText.isEmpty) {
      return;
    }
    if (_state == VoiceState.speaking && _lastSpeakingText == spokenText) {
      DebugConsole.log('[Voice/TTS] duplicate suppressed chars=${text.length}');
      return;
    }
    if (_state == VoiceState.speaking || _state == VoiceState.paused) {
      await stopTts();
    }
    final available = await tts.isLanguageAvailable(locale);
    if (!available) {
      DebugConsole.log('[Voice/TTS] language unavailable locale=$locale');
      _setState(VoiceState.error);
      return;
    }
    _lastSpeakingText = spokenText;
    _setState(VoiceState.speaking);
    DebugConsole.log(
      '[Voice/TTS] speak chars=${spokenText.length} locale=$locale '
      'rate=$rate pitch=$pitch',
    );
    try {
      await tts.speak(spokenText, locale: locale, rate: rate, pitch: pitch);
    } finally {
      if (_lastSpeakingText == spokenText &&
          (_state == VoiceState.speaking || _state == VoiceState.paused)) {
        _lastSpeakingText = null;
        _setState(VoiceState.idle);
      }
    }
  }

  Future<void> pauseTts() async {
    if (_state != VoiceState.speaking) {
      return;
    }
    DebugConsole.log('[Voice/TTS] pause');
    await tts.pause();
    _setState(VoiceState.paused);
  }

  Future<void> stopTts() async {
    if (_state != VoiceState.speaking && _state != VoiceState.paused) {
      return;
    }
    DebugConsole.log('[Voice/TTS] stop');
    await tts.stop();
    _lastSpeakingText = null;
    _setState(VoiceState.idle);
  }

  @override
  void dispose() {
    unawaited(speech.stop());
    if (_state == VoiceState.speaking || _state == VoiceState.paused) {
      unawaited(tts.stop());
    }
    _disposed = true;
    super.dispose();
  }

  void _setState(VoiceState state) {
    if (_state == state) {
      return;
    }
    _state = state;
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}
