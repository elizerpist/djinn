import 'dart:async';

import 'package:flutter/material.dart';

import '../../knowledge/models/knowledge_document.dart';
import '../../settings/models/app_settings.dart';
import '../../voice/speech_adapter.dart';
import '../../voice/tts_adapter.dart';
import '../../voice/voice_controller.dart';
import '../data/chat_service.dart';
import '../data/local_chat_repository.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import 'chat_bubble.dart';
import 'message_composer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repository,
    required this.chatService,
    required this.refreshKnowledgeReadiness,
    required this.conversation,
    this.voiceController,
    this.loadSettings,
  });

  final LocalChatRepository repository;
  final ChatService chatService;
  final Future<KnowledgeBaseState> Function() refreshKnowledgeReadiness;
  final ChatConversation conversation;
  final VoiceController? voiceController;
  final Future<AppSettings> Function()? loadSettings;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = const [];
  KnowledgeBaseState _knowledgeState = KnowledgeBaseState.fromDocuments(
    const [],
  );
  bool _sending = false;
  bool _voiceReplyEnabled = false;
  String _voiceMode = 'push_to_talk';
  String _voiceLocale = 'hu-HU';
  late final VoiceController _voiceController;
  late final bool _ownsVoiceController;

  @override
  void initState() {
    super.initState();
    _ownsVoiceController = widget.voiceController == null;
    _voiceController =
        widget.voiceController ??
        VoiceController(
          speech: SpeechToTextAdapter(),
          tts: FlutterTtsAdapter(),
          onFinalTranscript: (text) =>
              _send(text, speakResponse: _voiceReplyEnabled),
        );
    _loadMessages();
    _loadKnowledgeState();
    _loadVoiceSettings();
  }

  @override
  void dispose() {
    if (_ownsVoiceController) {
      _voiceController.stopTts();
      _voiceController.dispose();
    }
    super.dispose();
  }

  Future<List<ChatMessage>> _loadMessages() async {
    final messages = await widget.repository.getMessages(
      widget.conversation.id,
    );
    if (!mounted) {
      return messages;
    }
    setState(() => _messages = messages);
    return messages;
  }

  Future<void> _loadKnowledgeState() async {
    final state = await widget.refreshKnowledgeReadiness();
    if (!mounted) {
      return;
    }
    setState(() => _knowledgeState = state);
  }

  Future<void> _loadVoiceSettings() async {
    final loader = widget.loadSettings;
    if (loader == null) {
      return;
    }
    final settings = await loader();
    if (!mounted) {
      return;
    }
    setState(() {
      _voiceMode = settings.voiceMode;
      _voiceLocale = settings.voiceLocale;
      _voiceReplyEnabled = settings.voiceMode == 'conversation';
    });
  }

  Future<void> _send(String text, {bool speakResponse = false}) async {
    if (!mounted) {
      return;
    }
    ChatMessage? assistantMessage;
    setState(() => _sending = true);
    try {
      await _loadKnowledgeState();
      await widget.chatService.sendMessage(widget.conversation.id, text);
      final messages = await _loadMessages();
      if (speakResponse) {
        assistantMessage = _lastAssistantMessage(messages);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
    if (mounted && assistantMessage != null) {
      unawaited(_speakAssistant(assistantMessage.text));
    }
  }

  Future<void> _speakAssistant(String text) async {
    await _voiceController.speak(text, locale: _voiceLocale);
    if (!mounted ||
        _voiceMode != 'conversation' ||
        !_voiceReplyEnabled ||
        _voiceController.state != VoiceState.idle) {
      return;
    }
    unawaited(_voiceController.listenOnce(locale: _voiceLocale));
  }

  ChatMessage? _lastAssistantMessage(List<ChatMessage> messages) {
    for (final message in messages.reversed) {
      if (message.sender == ChatSender.assistant) {
        return message;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          KnowledgeStatusBanner(state: _knowledgeState),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Ird be az elso kerdest'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        ChatBubble(message: _messages[index]),
                  ),
          ),
          MessageComposer(
            onSend: (text) => _send(text, speakResponse: _voiceReplyEnabled),
            sending: _sending,
            voiceController: _voiceController,
            voiceLocale: _voiceLocale,
            voiceReplyEnabled: _voiceReplyEnabled,
            onVoiceReplyEnabledChanged: (value) =>
                setState(() => _voiceReplyEnabled = value),
          ),
        ],
      ),
    );
  }
}

class KnowledgeStatusBanner extends StatelessWidget {
  const KnowledgeStatusBanner({super.key, required this.state});

  final KnowledgeBaseState state;

  @override
  Widget build(BuildContext context) {
    final (text, icon, color) = switch (state.readiness) {
      KnowledgeBaseReadiness.empty => (
        'Nincs betoltott tudastar',
        Icons.folder_off,
        const Color(0xFF6B7280),
      ),
      KnowledgeBaseReadiness.pendingIngest => (
        'PDF-ek feldolgozasra varnak',
        Icons.hourglass_top,
        const Color(0xFF9A3412),
      ),
      KnowledgeBaseReadiness.ready => (
        'Tudastar kesz: ${state.processedCount} PDF',
        Icons.verified,
        const Color(0xFF166534),
      ),
      KnowledgeBaseReadiness.failed => (
        'Tudastar hiba',
        Icons.error_outline,
        const Color(0xFF991B1B),
      ),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
