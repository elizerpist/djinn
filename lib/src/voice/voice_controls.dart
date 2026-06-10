import 'package:flutter/material.dart';

import 'voice_controller.dart';

class VoiceControls extends StatelessWidget {
  const VoiceControls({
    super.key,
    required this.controller,
    required this.locale,
    required this.sending,
    required this.voiceReplyEnabled,
    required this.onVoiceReplyEnabledChanged,
  });

  final VoiceController controller;
  final String locale;
  final bool sending;
  final bool voiceReplyEnabled;
  final ValueChanged<bool> onVoiceReplyEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final listening = state == VoiceState.listening;
        final busy =
            sending ||
            state == VoiceState.listening ||
            state == VoiceState.sending;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const ValueKey('voice-listen'),
              tooltip: 'Hangbevitel',
              onPressed: busy
                  ? null
                  : () => controller.listenOnce(locale: locale),
              icon: Icon(listening ? Icons.graphic_eq : Icons.mic),
            ),
            IconButton(
              key: const ValueKey('voice-reply-toggle'),
              tooltip: 'Valasz felolvasasa',
              onPressed: sending
                  ? null
                  : () => onVoiceReplyEnabledChanged(!voiceReplyEnabled),
              icon: Icon(
                voiceReplyEnabled ? Icons.volume_up : Icons.volume_off,
              ),
            ),
            if (state == VoiceState.speaking)
              IconButton(
                key: const ValueKey('voice-pause'),
                tooltip: 'Felolvasas szuneteltetese',
                onPressed: controller.pauseTts,
                icon: const Icon(Icons.pause_circle_outline),
              ),
            if (state == VoiceState.speaking || state == VoiceState.paused)
              IconButton(
                key: const ValueKey('voice-stop'),
                tooltip: 'Felolvasas leallitasa',
                onPressed: controller.stopTts,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
          ],
        );
      },
    );
  }
}
