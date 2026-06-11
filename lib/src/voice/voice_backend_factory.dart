import 'dart:io';

import 'native_android_speech_adapter.dart';
import 'speech_adapter.dart';
import 'whisper_conversation_adapter.dart';

class VoiceBackendFactory {
  const VoiceBackendFactory();

  SpeechAdapter conversation() => WhisperConversationAdapter();

  SpeechAdapter pushToTalk() {
    if (Platform.isAndroid) {
      return NativeAndroidSpeechAdapter();
    }
    return WhisperConversationAdapter();
  }

  SpeechAdapter pluginFallback() => SpeechToTextAdapter();
}
