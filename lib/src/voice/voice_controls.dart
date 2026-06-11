import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_controller.dart';
import 'voice_input_mode.dart';
import 'voice_mode.dart';

export 'voice_input_mode.dart';

class VoiceControls extends StatelessWidget {
  const VoiceControls({
    super.key,
    required this.controller,
    required this.locale,
    required this.sending,
    required this.defaultVoiceMode,
    required this.onVoiceInputModeSelected,
  });

  final VoiceController controller;
  final String locale;
  final bool sending;
  final VoiceMode defaultVoiceMode;
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
            state == VoiceState.speaking ||
            state == VoiceState.paused ||
            state == VoiceState.sending;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: busy
                  ? const Color(0xFF9CA3AF)
                  : listening
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF155EEF),
              shape: const CircleBorder(),
              child: InkResponse(
                key: const ValueKey('voice-listen'),
                onTap: busy
                    ? null
                    : () {
                        if (listening) {
                          unawaited(controller.stopListening());
                        } else {
                          unawaited(_startListening(_defaultInputMode));
                        }
                      },
                onLongPressStart: busy || listening
                    ? null
                    : (_) {
                        unawaited(
                          _startListening(VoiceInputMode.pushToTalk),
                        );
                      },
                onLongPressEnd: busy
                    ? null
                    : (_) {
                        if (controller.isListening) {
                          unawaited(controller.stopListening());
                        }
                      },
                onLongPressCancel: busy
                    ? null
                    : () {
                        if (controller.isListening) {
                          unawaited(controller.stopListening());
                        }
                      },
                customBorder: const CircleBorder(),
                radius: 28,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    listening ? Icons.graphic_eq : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startListening(VoiceInputMode mode) async {
    PermissionStatus permission = PermissionStatus.granted;
    try {
      permission = await Permission.microphone.request();
    } catch (_) {
      permission = PermissionStatus.granted;
    }
    if (!permission.isGranted) {
      return;
    }
    onVoiceInputModeSelected(mode);
    await controller.listenOnce(locale: locale, mode: mode);
  }

  VoiceInputMode get _defaultInputMode {
    return switch (defaultVoiceMode) {
      VoiceMode.whisperConversation => VoiceInputMode.conversation,
      VoiceMode.nativeAndroidPtt => VoiceInputMode.pushToTalk,
    };
  }
}
