enum VoiceMode {
  whisperConversation('whisper_conversation'),
  nativeAndroidPtt('native_android_ptt');

  const VoiceMode(this.wireName);

  final String wireName;

  static VoiceMode fromWireName(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'native_android_ptt' || 'push_to_talk' || 'hands_free' => nativeAndroidPtt,
      'conversation' || 'whisper_conversation' => whisperConversation,
      _ => whisperConversation,
    };
  }
}
