import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'voice_controller.dart';
import 'voice_input_mode.dart';
import 'voice_mode.dart';

export 'voice_input_mode.dart';

class VoiceControls extends StatefulWidget {
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
  State<VoiceControls> createState() => _VoiceControlsState();
}

class _VoiceControlsState extends State<VoiceControls> {
  static const _pushToTalkDelay = Duration(milliseconds: 300);

  Timer? _pressTimer;
  bool _pressStartedPushToTalk = false;
  bool _tapDownStoppedListening = false;
  bool _pendingPushToTalkStop = false;

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final listening = state == VoiceState.listening;
        final busy =
            widget.sending ||
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
              child: GestureDetector(
                key: const ValueKey('voice-listen'),
                onTapDown: busy ? null : _handleTapDown,
                onTapUp: busy ? null : _handleTapUp,
                onTapCancel: busy ? null : _handleTapCancel,
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

  void _handleTapDown(TapDownDetails _) {
    _pressTimer?.cancel();
    _pressStartedPushToTalk = false;
    _pendingPushToTalkStop = false;
    if (widget.controller.isListening) {
      _tapDownStoppedListening = true;
      unawaited(widget.controller.stopListening());
      return;
    }
    _tapDownStoppedListening = false;
    _pressTimer = Timer(_pushToTalkDelay, () {
      if (!mounted || widget.controller.isListening || widget.sending) {
        return;
      }
      _pressStartedPushToTalk = true;
      unawaited(_startListening(VoiceInputMode.pushToTalk));
    });
  }

  void _handleTapUp(TapUpDetails _) {
    if (_tapDownStoppedListening) {
      _tapDownStoppedListening = false;
      _pressTimer?.cancel();
      _pressTimer = null;
      return;
    }
    final startedPushToTalk = _pressStartedPushToTalk;
    _pressTimer?.cancel();
    _pressTimer = null;
    if (startedPushToTalk) {
      if (widget.controller.isListening) {
        unawaited(widget.controller.stopListening());
      } else {
        _pendingPushToTalkStop = true;
      }
      return;
    }
    unawaited(_startListening(_defaultInputMode));
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    _pressTimer = null;
    if (_pressStartedPushToTalk) {
      if (widget.controller.isListening) {
        unawaited(widget.controller.stopListening());
      } else {
        _pendingPushToTalkStop = true;
      }
    }
    _pressStartedPushToTalk = false;
    _tapDownStoppedListening = false;
  }

  Future<void> _startListening(VoiceInputMode mode) async {
    if (!await _hasMicrophonePermission()) {
      return;
    }
    if (mode == VoiceInputMode.pushToTalk && _pendingPushToTalkStop) {
      _pendingPushToTalkStop = false;
      return;
    }
    widget.onVoiceInputModeSelected(mode);
    await widget.controller.listenOnce(locale: widget.locale, mode: mode);
  }

  Future<bool> _hasMicrophonePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      return true;
    }
    try {
      final permission = await Permission.microphone.request();
      return permission.isGranted;
    } catch (_) {
      return true;
    }
  }

  VoiceInputMode get _defaultInputMode {
    return switch (widget.defaultVoiceMode) {
      VoiceMode.whisperConversation => VoiceInputMode.conversation,
      VoiceMode.nativeAndroidPtt => VoiceInputMode.pushToTalk,
    };
  }
}
