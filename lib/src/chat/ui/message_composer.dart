export '../../voice/voice_controls.dart' show VoiceInputMode;

import 'package:flutter/material.dart';

import '../../voice/voice_controller.dart';
import '../../voice/voice_controls.dart';
import '../../voice/voice_mode.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.sending,
    this.voiceController,
    this.voiceLocale = 'hu-HU',
    this.defaultVoiceMode = VoiceMode.whisperConversation,
    this.onVoiceInputModeSelected,
  });

  final Future<void> Function(String text) onSend;
  final bool sending;
  final VoiceController? voiceController;
  final String voiceLocale;
  final VoiceMode defaultVoiceMode;
  final ValueChanged<VoiceInputMode>? onVoiceInputModeSelected;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  String _draft = '';
  bool _voiceDraftOwned = false;
  bool _voiceListening = false;

  @override
  void initState() {
    super.initState();
    widget.voiceController?.addListener(_syncVoiceDraft);
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceController != widget.voiceController) {
      oldWidget.voiceController?.removeListener(_syncVoiceDraft);
      widget.voiceController?.addListener(_syncVoiceDraft);
    }
  }

  @override
  void dispose() {
    widget.voiceController?.removeListener(_syncVoiceDraft);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.voiceController?.isListening ?? false;
    final canSend = _draft.trim().isNotEmpty && !widget.sending && !listening;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('message-input'),
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                enabled: !widget.sending && !listening,
                onChanged: (value) => setState(() => _draft = value),
                onSubmitted: canSend ? (_) => _send() : null,
                decoration: InputDecoration(
                  hintText: 'Kerdes az OMSZ eljarasrendekrol',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.voiceController != null)
              VoiceControls(
                controller: widget.voiceController!,
                locale: widget.voiceLocale,
                sending: widget.sending,
                defaultVoiceMode: widget.defaultVoiceMode,
                onVoiceInputModeSelected:
                    widget.onVoiceInputModeSelected ?? (_) {},
              ),
            IconButton.filled(
              key: const ValueKey('send-message'),
              tooltip: 'Kuldes',
              onPressed: canSend ? _send : null,
              icon: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    await widget.onSend(text);
    _controller.clear();
    setState(() => _draft = '');
    _voiceDraftOwned = false;
  }

  void _syncVoiceDraft() {
    final voiceController = widget.voiceController;
    if (voiceController == null || !mounted) {
      return;
    }

    final listening = voiceController.isListening;
    final listeningChanged = listening != _voiceListening;
    _voiceListening = listening;

    if (listening) {
      _voiceDraftOwned = true;
      final draft = voiceController.draftTranscript;
      if (_controller.text != draft) {
        _controller.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length),
        );
        setState(() => _draft = draft);
      } else if (listeningChanged) {
        setState(() {});
      }
      return;
    }

    if (_voiceDraftOwned && voiceController.draftTranscript.isEmpty) {
      _voiceDraftOwned = false;
      if (_controller.text.isNotEmpty) {
        _controller.clear();
        setState(() => _draft = '');
      } else if (listeningChanged) {
        setState(() {});
      }
    } else if (listeningChanged) {
      setState(() {});
    }
  }
}
