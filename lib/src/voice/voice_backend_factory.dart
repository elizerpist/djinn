import 'dart:io';

import 'native_android_speech_adapter.dart';
import 'speech_adapter.dart';
import 'whisper_conversation_adapter.dart';

class VoiceBackendFactory {
  const VoiceBackendFactory();

  SpeechAdapter conversation() {
    if (Platform.isAndroid) {
      return NativeAndroidSpeechAdapter(
        debugLabel: 'Conversation',
        completeSilenceTimeout: const Duration(milliseconds: 3500),
        possibleCompleteSilenceTimeout: const Duration(milliseconds: 2200),
        minimumSpeechLength: const Duration(milliseconds: 1200),
      );
    }
    return WhisperConversationAdapter();
  }

  SpeechAdapter pushToTalk() {
    if (Platform.isAndroid) {
      return NativeAndroidSpeechAdapter();
    }
    return WhisperConversationAdapter();
  }

  SpeechAdapter pluginFallback() => SpeechToTextAdapter();
}
