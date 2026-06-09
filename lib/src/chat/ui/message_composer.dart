import 'package:flutter/material.dart';

import '../../voice/voice_input_service.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.sending,
    this.voiceInputService,
    this.voiceLocale = 'hu-HU',
  });

  final Future<void> Function(String text) onSend;
  final bool sending;
  final VoiceInputService? voiceInputService;
  final String voiceLocale;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  String _draft = '';
  bool _listening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _draft.trim().isNotEmpty && !widget.sending;

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
                enabled: !widget.sending,
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
            if (widget.voiceInputService != null) ...[
              IconButton(
                key: const ValueKey('voice-input-toggle'),
                tooltip: 'Diktálás',
                onPressed: widget.sending || _listening ? null : _listen,
                icon: _listening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.mic),
              ),
              const SizedBox(width: 4),
            ],
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

  Future<void> _listen() async {
    final service = widget.voiceInputService;
    if (service == null) {
      return;
    }
    setState(() => _listening = true);
    try {
      final transcript = await service.listen(locale: widget.voiceLocale);
      if (transcript == null || transcript.trim().isEmpty) {
        return;
      }
      _controller.text = transcript;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      setState(() => _draft = transcript);
    } finally {
      if (mounted) {
        setState(() => _listening = false);
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    await widget.onSend(text);
    _controller.clear();
    setState(() => _draft = '');
  }
}
