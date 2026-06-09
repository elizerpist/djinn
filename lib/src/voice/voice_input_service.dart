import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../debug/debug_console.dart';

abstract class VoiceInputService {
  Future<String?> listen({required String locale});
}

class FakeVoiceInputService implements VoiceInputService {
  FakeVoiceInputService({required this.transcript});

  final String transcript;
  final List<String> listenLocales = [];

  @override
  Future<String?> listen({required String locale}) async {
    listenLocales.add(locale);
    return transcript;
  }
}

class SpeechToTextVoiceInputService implements VoiceInputService {
  SpeechToTextVoiceInputService({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  @override
  Future<String?> listen({required String locale}) async {
    final permission = await Permission.microphone.request();
    DebugConsole.log('[Voice/STT] permission status=${permission.name}');
    if (!permission.isGranted) {
      return null;
    }
    final available = await _speechToText.initialize(
      onError: (error) =>
          DebugConsole.log('[Voice/STT] error code=${error.errorMsg}'),
      onStatus: (status) => DebugConsole.log('[Voice/STT] status=$status'),
    );
    if (!available) {
      DebugConsole.log('[Voice/STT] unavailable');
      return null;
    }
    DebugConsole.log('[Voice/STT] listen start locale=$locale');
    var transcript = '';
    final completer = Completer<String?>();
    await _speechToText.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: locale.replaceAll('-', '_'),
      ),
      onResult: (result) {
        transcript = result.recognizedWords;
        DebugConsole.log(
          '[Voice/STT] result chars=${transcript.length} final=${result.finalResult}',
        );
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(transcript);
        }
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () async {
        await _speechToText.stop();
        return transcript.trim().isEmpty ? null : transcript;
      },
    );
  }
}
