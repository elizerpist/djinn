import 'package:flutter/material.dart';

import 'voice_controller.dart';

enum VoiceInputMode { conversation, pushToTalk }

class VoiceControls extends StatelessWidget {
  const VoiceControls({
    super.key,
    required this.controller,
    required this.locale,
    required this.sending,
    required this.onVoiceInputModeSelected,
  });

  final VoiceController controller;
  final String locale;
  final bool sending;
  final ValueChanged<VoiceInputMode> onVoiceInputModeSelected;

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
                  : () => _startListening(VoiceInputMode.conversation),
              onLongPress: busy
                  ? null
                  : () => _startListening(VoiceInputMode.pushToTalk),
              icon: Icon(listening ? Icons.graphic_eq : Icons.mic),
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

  Future<void> _startListening(VoiceInputMode mode) async {
    onVoiceInputModeSelected(mode);
    await controller.listenOnce(locale: locale);
  }
}
