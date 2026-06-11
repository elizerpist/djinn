import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../debug/debug_console.dart';
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
        final busy = widget.sending || state == VoiceState.sending;
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
    DebugConsole.log(
      '[Voice/UI] mic tap down listening=${widget.controller.isListening} '
      'sending=${widget.sending} state=${widget.controller.state.name}',
    );
    _pressTimer?.cancel();
    _pressStartedPushToTalk = false;
    _pendingPushToTalkStop = false;
    if (widget.controller.isListening) {
      _tapDownStoppedListening = true;
      DebugConsole.log('[Voice/UI] mic tap down stops active listening');
      unawaited(widget.controller.stopListening());
      return;
    }
    _tapDownStoppedListening = false;
    _pressTimer = Timer(_pushToTalkDelay, () {
      if (!mounted || widget.controller.isListening || widget.sending) {
        DebugConsole.log(
          '[Voice/UI] ptt threshold skipped mounted=$mounted '
          'listening=${widget.controller.isListening} sending=${widget.sending}',
        );
        return;
      }
      _pressStartedPushToTalk = true;
      DebugConsole.log('[Voice/UI] ptt threshold reached start pushToTalk');
      unawaited(_startListening(VoiceInputMode.pushToTalk));
    });
  }

  void _handleTapUp(TapUpDetails _) {
    DebugConsole.log(
      '[Voice/UI] mic tap up startedPtt=$_pressStartedPushToTalk '
      'stoppedExisting=$_tapDownStoppedListening '
      'listening=${widget.controller.isListening}',
    );
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
        DebugConsole.log('[Voice/UI] ptt release stop active listening');
        unawaited(widget.controller.stopListening());
      } else {
        _pendingPushToTalkStop = true;
        DebugConsole.log('[Voice/UI] ptt release pending stop before listening');
      }
      return;
    }
    DebugConsole.log('[Voice/UI] single tap start mode=${_defaultInputMode.name}');
    unawaited(_startListening(_defaultInputMode));
  }

  void _handleTapCancel() {
    DebugConsole.log(
      '[Voice/UI] mic tap cancel startedPtt=$_pressStartedPushToTalk '
      'listening=${widget.controller.isListening}',
    );
    _pressTimer?.cancel();
    _pressTimer = null;
    if (_pressStartedPushToTalk) {
      if (widget.controller.isListening) {
        DebugConsole.log('[Voice/UI] ptt cancel stop active listening');
        unawaited(widget.controller.stopListening());
      } else {
        _pendingPushToTalkStop = true;
        DebugConsole.log('[Voice/UI] ptt cancel pending stop before listening');
      }
    }
    _pressStartedPushToTalk = false;
    _tapDownStoppedListening = false;
  }

  Future<void> _startListening(VoiceInputMode mode) async {
    DebugConsole.log('[Voice/UI] start listening requested mode=${mode.name}');
    if (!await _hasMicrophonePermission()) {
      DebugConsole.log('[Voice/UI] start listening blocked permission_denied');
      return;
    }
    if (mode == VoiceInputMode.pushToTalk && _pendingPushToTalkStop) {
      _pendingPushToTalkStop = false;
      DebugConsole.log('[Voice/UI] ptt start cancelled by pending stop');
      return;
    }
    widget.onVoiceInputModeSelected(mode);
    await widget.controller.listenOnce(locale: widget.locale, mode: mode);
  }

  Future<bool> _hasMicrophonePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      DebugConsole.log(
        '[Voice/UI] permission skipped platform=${Platform.operatingSystem}',
      );
      return true;
    }
    try {
      final permission = await Permission.microphone.request();
      DebugConsole.log('[Voice/UI] permission status=${permission.name}');
      return permission.isGranted;
    } catch (error) {
      DebugConsole.log('[Voice/UI] permission check failed error=$error');
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
