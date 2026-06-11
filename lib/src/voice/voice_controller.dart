import 'dart:async';

import 'package:flutter/foundation.dart';

import '../debug/debug_console.dart';
import 'speech_adapter.dart';
import 'tts_adapter.dart';
import 'voice_input_mode.dart';

enum VoiceState { idle, listening, noSpeech, sending, speaking, paused, error }

class VoiceController extends ChangeNotifier {
  VoiceController({
    SpeechAdapter? speech,
    SpeechAdapter? conversationSpeech,
    SpeechAdapter? pushToTalkSpeech,
    required this.tts,
    required this.onFinalTranscript,
  }) : _conversationSpeech =
           conversationSpeech ?? speech ?? SpeechToTextAdapter(),
       _pushToTalkSpeech = pushToTalkSpeech ?? speech ?? SpeechToTextAdapter();

  final SpeechAdapter _conversationSpeech;
  final SpeechAdapter _pushToTalkSpeech;
  final TtsAdapter tts;
  final Future<void> Function(String text) onFinalTranscript;

  VoiceState _state = VoiceState.idle;
  String? _lastSpeakingText;
  String _draftTranscript = '';
  SpeechAdapter? _activeSpeech;
  var _disposed = false;
  var _listenSessionCounter = 0;
  var _bargeInSessionCounter = 0;
  var _activeBargeInSessionId = 0;
  var _activeBargeInDetected = false;

  VoiceState get state => _state;

  bool get isListening => _state == VoiceState.listening;

  String get draftTranscript => _draftTranscript;

  bool get isSpeaking => _state == VoiceState.speaking;

  bool get isPaused => _state == VoiceState.paused;

  Future<void> listenOnce({
    required String locale,
    VoiceInputMode mode = VoiceInputMode.conversation,
  }) async {
    final sessionId = ++_listenSessionCounter;
    DebugConsole.log(
      '[Voice/STT] session=$sessionId listen requested locale=$locale '
      'mode=${mode.name} state=${_state.name}',
    );
    if (_state == VoiceState.listening || _state == VoiceState.sending) {
      DebugConsole.log(
        '[Voice/STT] session=$sessionId listen ignored state=${_state.name}',
      );
      return;
    }
    await _cancelBargeInMonitor(reason: 'manual_listen_start');
    await _prepareAudioForListening(sessionId);

    final speech = switch (mode) {
      VoiceInputMode.conversation => _conversationSpeech,
      VoiceInputMode.pushToTalk => _pushToTalkSpeech,
    };
    _activeSpeech = speech;
    _draftTranscript = '';
    _setState(VoiceState.listening);
    DebugConsole.log(
      '[Voice/STT] session=$sessionId listen start locale=$locale '
      'mode=${mode.name}',
    );
    var sentFinal = false;
    String? bestPartialTranscript;
    try {
      await for (final event in speech.listen(locale: locale)) {
        switch (event) {
          case SpeechStatusEvent(:final status):
            DebugConsole.log('[Voice/STT] session=$sessionId status=$status');
          case SpeechResultEvent(:final text, :final finalResult):
            DebugConsole.log(
              '[Voice/STT] session=$sessionId result chars=${text.length} '
              'final=$finalResult',
            );
            final transcript = text.trim();
            if (transcript.isNotEmpty &&
                (bestPartialTranscript == null ||
                    transcript.length > bestPartialTranscript.length)) {
              bestPartialTranscript = transcript;
              _draftTranscript = transcript;
              DebugConsole.log(
                '[Voice/STT] session=$sessionId partial transcript updated '
                'chars=${transcript.length}',
              );
              notifyListeners();
            }
            if (finalResult && transcript.isNotEmpty && !sentFinal) {
              sentFinal = true;
              await _commitTranscript(transcript, sessionId: sessionId);
            }
          case SpeechErrorEvent(:final code):
            DebugConsole.log('[Voice/STT] session=$sessionId error code=$code');
            if (!sentFinal) {
              _setState(
                code == 'error_speech_timeout' || code == 'error_no_match'
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
            '[Voice/STT] session=$sessionId commit partial transcript '
            'reason=stream_closed '
            'chars=${fallbackTranscript.length}',
          );
          await _commitTranscript(fallbackTranscript, sessionId: sessionId);
        } else if (_state == VoiceState.listening) {
          DebugConsole.log(
            '[Voice/STT] session=$sessionId stream closed without transcript',
          );
          _setState(VoiceState.noSpeech);
        }
      }
    } catch (error) {
      DebugConsole.log('[Voice/STT] session=$sessionId error code=$error');
      if (!sentFinal) {
        _setState(VoiceState.error);
      }
    } finally {
      if (_activeSpeech == speech) {
        _activeSpeech = null;
      }
    }
  }

  Future<void> listenConversation({required String locale}) async {
    await listenOnce(locale: locale, mode: VoiceInputMode.conversation);
  }

  Future<void> listenPushToTalk({required String locale}) async {
    await listenOnce(locale: locale, mode: VoiceInputMode.pushToTalk);
  }

  Future<void> stopListening() async {
    await _activeSpeech?.stop();
  }

  Future<void> _prepareAudioForListening(int sessionId) async {
    if (_state == VoiceState.speaking || _state == VoiceState.paused) {
      DebugConsole.log(
        '[Voice/TTS] barge-in stop requested session=$sessionId '
        'state=${_state.name}',
      );
      await stopTts();
      return;
    }
    DebugConsole.log(
      '[Voice/TTS] pre-listen stop requested session=$sessionId '
      'state=${_state.name}',
    );
    try {
      await tts.stop();
    } catch (error) {
      DebugConsole.log(
        '[Voice/TTS] pre-listen stop failed session=$sessionId error=$error',
      );
    }
  }

  Future<void> _commitTranscript(
    String transcript, {
    required int sessionId,
  }) async {
    DebugConsole.log(
      '[Voice/STT] session=$sessionId final commit start chars=${transcript.length}',
    );
    _setState(VoiceState.sending);
    try {
      await onFinalTranscript(transcript);
      _draftTranscript = '';
      notifyListeners();
      DebugConsole.log('[Voice/STT] session=$sessionId final commit complete');
      _setState(VoiceState.idle);
    } catch (error) {
      DebugConsole.log('[Voice/STT] session=$sessionId send failed error=$error');
      _setState(VoiceState.error);
    }
  }

  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
    bool listenForBargeIn = false,
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
    final bargeInSessionId = listenForBargeIn
        ? _startBargeInMonitor(locale: locale, spokenText: spokenText)
        : 0;
    DebugConsole.log(
      '[Voice/TTS] speak chars=${spokenText.length} locale=$locale '
      'rate=$rate pitch=$pitch',
    );
    try {
      await tts.speak(spokenText, locale: locale, rate: rate, pitch: pitch);
    } finally {
      if (bargeInSessionId != 0 &&
          _activeBargeInSessionId == bargeInSessionId &&
          !_activeBargeInDetected) {
        await _cancelBargeInMonitor(reason: 'tts_finished');
      }
      if (_lastSpeakingText == spokenText &&
          (_state == VoiceState.speaking || _state == VoiceState.paused)) {
        _lastSpeakingText = null;
        _setState(VoiceState.idle);
      }
    }
  }

  int _startBargeInMonitor({
    required String locale,
    required String spokenText,
  }) {
    final sessionId = ++_bargeInSessionCounter;
    _activeBargeInSessionId = sessionId;
    _activeBargeInDetected = false;
    DebugConsole.log(
      '[Voice/BargeIn] monitor start session=$sessionId locale=$locale '
      'ttsChars=${spokenText.length}',
    );
    unawaited(
      _runBargeInMonitor(
        sessionId: sessionId,
        locale: locale,
        spokenText: spokenText,
      ),
    );
    return sessionId;
  }

  Future<void> _runBargeInMonitor({
    required int sessionId,
    required String locale,
    required String spokenText,
  }) async {
    var sentFinal = false;
    String? bestPartialTranscript;
    try {
      await for (final event in _conversationSpeech.listen(locale: locale)) {
        if (_activeBargeInSessionId != sessionId) {
          DebugConsole.log(
            '[Voice/BargeIn] drop stale event session=$sessionId '
            'active=$_activeBargeInSessionId',
          );
          break;
        }
        switch (event) {
          case SpeechStatusEvent(:final status):
            DebugConsole.log(
              '[Voice/BargeIn] session=$sessionId status=$status '
              'detected=$_activeBargeInDetected',
            );
          case SpeechResultEvent(:final text, :final finalResult):
            final transcript = text.trim();
            if (transcript.isEmpty) {
              continue;
            }
            final echo = _looksLikeTtsEcho(transcript, spokenText);
            DebugConsole.log(
              '[Voice/BargeIn] session=$sessionId candidate '
              'chars=${transcript.length} final=$finalResult echo=$echo '
              'detected=$_activeBargeInDetected',
            );
            if (!_activeBargeInDetected && echo) {
              continue;
            }
            if (!_activeBargeInDetected) {
              _activeBargeInDetected = true;
              DebugConsole.log(
                '[Voice/BargeIn] detected session=$sessionId '
                'chars=${transcript.length}',
              );
              await stopTts();
              _activeSpeech = _conversationSpeech;
              _setState(VoiceState.listening);
            }
            if (bestPartialTranscript == null ||
                transcript.length > bestPartialTranscript.length) {
              bestPartialTranscript = transcript;
              _draftTranscript = transcript;
              notifyListeners();
            }
            if (finalResult && !sentFinal) {
              sentFinal = true;
              await _commitTranscript(transcript, sessionId: sessionId);
              await _finishBargeInMonitor(sessionId, reason: 'final_result');
              return;
            }
          case SpeechErrorEvent(:final code):
            DebugConsole.log(
              '[Voice/BargeIn] session=$sessionId error code=$code '
              'detected=$_activeBargeInDetected',
            );
            if (!_activeBargeInDetected &&
                (code == 'error_speech_timeout' || code == 'error_no_match')) {
              await _restartBargeInMonitor(
                sessionId: sessionId,
                locale: locale,
                spokenText: spokenText,
                reason: code,
              );
              return;
            }
            if (_activeBargeInDetected && !sentFinal) {
              final fallbackTranscript = bestPartialTranscript;
              if (fallbackTranscript != null &&
                  fallbackTranscript.isNotEmpty &&
                  (code == 'error_speech_timeout' || code == 'error_no_match')) {
                sentFinal = true;
                await _commitTranscript(
                  fallbackTranscript,
                  sessionId: sessionId,
                );
              }
            }
            await _finishBargeInMonitor(sessionId, reason: 'error_$code');
            return;
        }
      }
      if (_activeBargeInSessionId == sessionId &&
          !_activeBargeInDetected &&
          (_state == VoiceState.speaking || _state == VoiceState.paused)) {
        await _restartBargeInMonitor(
          sessionId: sessionId,
          locale: locale,
          spokenText: spokenText,
          reason: 'stream_closed_no_detection',
        );
        return;
      }
      if (_activeBargeInSessionId == sessionId &&
          _activeBargeInDetected &&
          !sentFinal) {
        final fallbackTranscript = bestPartialTranscript;
        if (fallbackTranscript != null && fallbackTranscript.isNotEmpty) {
          DebugConsole.log(
            '[Voice/BargeIn] commit partial session=$sessionId '
            'reason=stream_closed chars=${fallbackTranscript.length}',
          );
          await _commitTranscript(fallbackTranscript, sessionId: sessionId);
        }
      }
      await _finishBargeInMonitor(sessionId, reason: 'stream_closed');
    } catch (error) {
      DebugConsole.log('[Voice/BargeIn] session=$sessionId error=$error');
      await _finishBargeInMonitor(sessionId, reason: 'exception');
    }
  }

  Future<void> _restartBargeInMonitor({
    required int sessionId,
    required String locale,
    required String spokenText,
    required String reason,
  }) async {
    if (_activeBargeInSessionId != sessionId ||
        _activeBargeInDetected ||
        (_state != VoiceState.speaking && _state != VoiceState.paused)) {
      await _finishBargeInMonitor(sessionId, reason: 'restart_skipped_$reason');
      return;
    }
    DebugConsole.log(
      '[Voice/BargeIn] restart session=$sessionId reason=$reason',
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_activeBargeInSessionId != sessionId ||
        _activeBargeInDetected ||
        (_state != VoiceState.speaking && _state != VoiceState.paused)) {
      await _finishBargeInMonitor(
        sessionId,
        reason: 'restart_cancelled_$reason',
      );
      return;
    }
    unawaited(
      _runBargeInMonitor(
        sessionId: sessionId,
        locale: locale,
        spokenText: spokenText,
      ),
    );
  }

  Future<void> _cancelBargeInMonitor({required String reason}) async {
    final sessionId = _activeBargeInSessionId;
    if (sessionId == 0) {
      return;
    }
    DebugConsole.log(
      '[Voice/BargeIn] cancel session=$sessionId reason=$reason',
    );
    _activeBargeInSessionId = 0;
    _activeBargeInDetected = false;
    await _conversationSpeech.stop();
  }

  Future<void> _finishBargeInMonitor(
    int sessionId, {
    required String reason,
  }) async {
    if (_activeBargeInSessionId != sessionId) {
      return;
    }
    DebugConsole.log(
      '[Voice/BargeIn] finish session=$sessionId reason=$reason',
    );
    if (_activeSpeech == _conversationSpeech) {
      _activeSpeech = null;
    }
    _activeBargeInSessionId = 0;
    _activeBargeInDetected = false;
  }

  bool _looksLikeTtsEcho(String transcript, String spokenText) {
    final candidate = _normalizeSpeechComparison(transcript);
    if (candidate.length < 3) {
      return true;
    }
    final spoken = _normalizeSpeechComparison(spokenText);
    return spoken.contains(candidate) || candidate.contains(spoken);
  }

  String _normalizeSpeechComparison(String value) {
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final isDigit = rune >= 48 && rune <= 57;
      final isAsciiLetter = rune >= 97 && rune <= 122;
      final isNonAsciiLetter = rune > 127;
      buffer.writeCharCode(
        isDigit || isAsciiLetter || isNonAsciiLetter ? rune : 32,
      );
    }
    return buffer
        .toString()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
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
    unawaited(_activeSpeech?.stop());
    unawaited(_conversationSpeech.stop());
    if (!identical(_pushToTalkSpeech, _conversationSpeech)) {
      unawaited(_pushToTalkSpeech.stop());
    }
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
