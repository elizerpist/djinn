import 'package:flutter/material.dart';

import '../../knowledge/models/knowledge_document.dart';
import '../../knowledge/ui/source_page_screen.dart';
import '../../settings/models/app_settings.dart';
import '../../voice/text_to_speech_service.dart';
import '../../voice/voice_input_service.dart';
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
    this.loadSettings,
    this.voiceInputService,
    this.textToSpeechService,
  });

  final LocalChatRepository repository;
  final ChatService chatService;
  final Future<KnowledgeBaseState> Function() refreshKnowledgeReadiness;
  final ChatConversation conversation;
  final Future<AppSettings> Function()? loadSettings;
  final VoiceInputService? voiceInputService;
  final TextToSpeechService? textToSpeechService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<ChatMessage> _messages = const [];
  KnowledgeBaseState _knowledgeState = KnowledgeBaseState.fromDocuments(
    const [],
  );
  bool _sending = false;
  String? _selectedCollection;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadKnowledgeState();
  }

  Future<void> _loadMessages() async {
    final messages = await widget.repository.getMessages(
      widget.conversation.id,
    );
    if (!mounted) {
      return;
    }
    setState(() => _messages = messages);
  }

  Future<void> _loadKnowledgeState() async {
    final state = await widget.refreshKnowledgeReadiness();
    if (!mounted) {
      return;
    }
    setState(() => _knowledgeState = state);
  }

  Future<void> _send(String text) async {
    setState(() => _sending = true);
    try {
      await _loadKnowledgeState();
      await widget.chatService.sendMessage(
        widget.conversation.id,
        text,
        collectionName: _selectedCollection,
      );
      await _loadMessages();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<AppSettings> _settings() async {
    final loader = widget.loadSettings;
    return loader == null ? AppSettings.defaults() : loader();
  }

  Future<void> _speak(ChatMessage message) async {
    final service = widget.textToSpeechService;
    if (service == null) {
      return;
    }
    final settings = await _settings();
    await service.speak(
      text: message.text,
      locale: settings.voiceLocale,
      speechRate: settings.ttsSpeechRate,
      pitch: settings.ttsPitch,
    );
  }

  Future<void> _pauseTts() async {
    await widget.textToSpeechService?.pause();
  }

  Future<void> _stopTts() async {
    await widget.textToSpeechService?.stop();
  }

  @override
  Widget build(BuildContext context) {
    final collectionOptions = _collectionOptions();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          KnowledgeStatusBanner(state: _knowledgeState),
          if (collectionOptions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollection ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Gyűjtemény',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Minden gyűjtemény'),
                  ),
                  for (final collection in collectionOptions)
                    DropdownMenuItem(
                      value: collection,
                      child: Text(collection),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCollection = value == null || value.isEmpty
                        ? null
                        : value;
                  });
                },
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Ird be az elso kerdest'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatBubble(
                        message: message,
                        onCitationTap: (citation) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SourcePageScreen(citation: citation),
                          ),
                        ),
                        onSpeak:
                            message.sender == ChatSender.assistant &&
                                widget.textToSpeechService != null
                            ? () => _speak(message)
                            : null,
                        onPause:
                            message.sender == ChatSender.assistant &&
                                widget.textToSpeechService != null
                            ? _pauseTts
                            : null,
                        onStop:
                            message.sender == ChatSender.assistant &&
                                widget.textToSpeechService != null
                            ? _stopTts
                            : null,
                      );
                    },
                  ),
          ),
          FutureBuilder<AppSettings>(
            future: _settings(),
            builder: (context, snapshot) {
              return MessageComposer(
                onSend: _send,
                sending: _sending,
                voiceInputService: widget.voiceInputService,
                voiceLocale: snapshot.data?.voiceLocale ?? 'hu-HU',
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.textToSpeechService?.stop();
    super.dispose();
  }

  List<String> _collectionOptions() {
    final collections =
        _knowledgeState.documents
            .map((document) => document.collectionName.trim())
            .where((collection) => collection.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return collections;
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
