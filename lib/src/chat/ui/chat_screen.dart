import 'dart:async';

import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../../knowledge/models/knowledge_document.dart';
import '../../settings/models/app_settings.dart';
import '../../voice/voice_mode.dart';
import '../../voice/voice_backend_factory.dart';
import '../../voice/tts_adapter.dart';
import '../../voice/voice_controller.dart';
import '../data/chat_service.dart';
import '../data/local_chat_repository.dart';
import '../models/chat_citation.dart';
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
  bool _voiceListenStarting = false;
  String _voiceLocale = 'hu-HU';
  VoiceMode _voiceMode = VoiceMode.whisperConversation;
  String? _speakingMessageId;
  String? _pausedMessageId;
  late final VoiceController _voiceController;
  late final bool _ownsVoiceController;
  static const _voiceBackendFactory = VoiceBackendFactory();

  @override
  void initState() {
    super.initState();
    _ownsVoiceController = widget.voiceController == null;
    _voiceController =
        widget.voiceController ??
        VoiceController(
          conversationSpeech: _voiceBackendFactory.conversation(),
          pushToTalkSpeech: _voiceBackendFactory.pushToTalk(),
          tts: FlutterTtsAdapter(),
          onFinalTranscript: (text) =>
              _send(text, speakResponse: _voiceReplyEnabled),
        );
    _voiceController.addListener(_syncVoicePlaybackState);
    _loadMessages();
    _loadKnowledgeState();
    _loadVoiceSettings();
  }

  @override
  void dispose() {
    _voiceController.removeListener(_syncVoicePlaybackState);
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
      _voiceLocale = settings.voiceLocale;
      _voiceMode = settings.voiceMode;
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
      unawaited(_playAssistantMessage(assistantMessage));
    }
  }

  Future<void> _playAssistantMessage(ChatMessage message) async {
    DebugConsole.log(
      '[Voice/TTS] bubble play message=${message.id} chars=${message.text.length}',
    );
    setState(() {
      _speakingMessageId = message.id;
      _pausedMessageId = null;
    });
    await _voiceController.speak(message.text, locale: _voiceLocale);
    if (mounted && _speakingMessageId == message.id) {
      setState(() {
        _speakingMessageId = null;
        _pausedMessageId = null;
      });
    }
    DebugConsole.log('[Voice/TTS] bubble play finished message=${message.id}');
    _restartVoiceConversationIfNeeded();
  }

  void _restartVoiceConversationIfNeeded() {
    if (!mounted) {
      return;
    }
    if (!_voiceReplyEnabled ||
        _voiceListenStarting ||
        _voiceController.isListening ||
        _voiceController.state == VoiceState.sending ||
        _voiceController.state == VoiceState.speaking) {
      DebugConsole.log(
        '[Voice/STT] conversation restart skipped enabled=$_voiceReplyEnabled '
        'starting=$_voiceListenStarting state=${_voiceController.state.name} '
        'listening=${_voiceController.isListening}',
      );
      return;
    }
    DebugConsole.log(
      '[Voice/STT] conversation restart locale=$_voiceLocale '
      'state=${_voiceController.state.name}',
    );
    unawaited(
      _voiceController.listenOnce(
        locale: _voiceLocale,
        mode: VoiceInputMode.conversation,
      ),
    );
  }

  Future<void> _pauseAssistantMessage(ChatMessage message) async {
    DebugConsole.log('[Voice/TTS] bubble pause message=${message.id}');
    await _voiceController.pauseTts();
    if (!mounted) {
      return;
    }
    setState(() {
      _speakingMessageId = null;
      _pausedMessageId = null;
    });
    _restartVoiceConversationIfNeeded();
  }

  Future<void> _resumeAssistantMessage(ChatMessage message) async {
    DebugConsole.log('[Voice/TTS] bubble resume message=${message.id}');
    await _playAssistantMessage(message);
  }

  Future<void> _stopAssistantMessage(ChatMessage message) async {
    DebugConsole.log('[Voice/TTS] bubble stop message=${message.id}');
    await _voiceController.stopTts();
    if (!mounted) {
      return;
    }
    setState(() {
      _speakingMessageId = null;
      _pausedMessageId = null;
    });
    _restartVoiceConversationIfNeeded();
  }

  void _syncVoicePlaybackState() {
    if (_voiceListenStarting) {
      final state = _voiceController.state;
      if (state == VoiceState.listening ||
          state == VoiceState.sending ||
          state == VoiceState.noSpeech ||
          state == VoiceState.error ||
          state == VoiceState.idle) {
        DebugConsole.log(
          '[Voice/UI] listen start flag cleared state=${state.name}',
        );
        _voiceListenStarting = false;
      }
    }
    if (!mounted || (_speakingMessageId == null && _pausedMessageId == null)) {
      return;
    }
    final state = _voiceController.state;
    if (state == VoiceState.speaking || state == VoiceState.paused) {
      return;
    }
    DebugConsole.log(
      '[Voice/TTS] bubble state cleared reason=voice_state_${state.name} '
      'speaking=$_speakingMessageId paused=$_pausedMessageId',
    );
    setState(() {
      _speakingMessageId = null;
      _pausedMessageId = null;
    });
  }

  BubbleTtsState _bubbleTtsState(ChatMessage message) {
    if (_speakingMessageId == message.id) {
      return BubbleTtsState.speaking;
    }
    if (_pausedMessageId == message.id) {
      return BubbleTtsState.paused;
    }
    return BubbleTtsState.idle;
  }

  ChatMessage? _lastAssistantMessage(List<ChatMessage> messages) {
    for (final message in messages.reversed) {
      if (message.sender == ChatSender.assistant) {
        return message;
      }
    }
    return null;
  }

  Future<void> _showCitationExcerpt(ChatCitation citation) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(citation.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (citation.page case final page?) ...[
                  Text(
                    '$page. oldal',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                ],
                if (citation.section case final section?) ...[
                  Text(
                    section,
                    style: const TextStyle(color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(citation.excerpt),
                if (citation.sourceId case final sourceId?) ...[
                  const SizedBox(height: 12),
                  Text(
                    sourceId,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bezárás'),
            ),
          ],
        );
      },
    );
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
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatBubble(
                        message: message,
                        ttsState: _bubbleTtsState(message),
                        onPlay: message.sender == ChatSender.assistant
                            ? (message) =>
                                  unawaited(_playAssistantMessage(message))
                            : null,
                        onPause: (message) =>
                            unawaited(_pauseAssistantMessage(message)),
                        onResume: (message) =>
                            unawaited(_resumeAssistantMessage(message)),
                        onStop: (message) =>
                            unawaited(_stopAssistantMessage(message)),
                        onCitationTap: _showCitationExcerpt,
                      );
                    },
                  ),
          ),
          MessageComposer(
            onSend: (text) => _send(text, speakResponse: _voiceReplyEnabled),
            sending: _sending,
            voiceController: _voiceController,
            voiceLocale: _voiceLocale,
            defaultVoiceMode: _voiceMode,
            onVoiceInputModeSelected: (mode) => setState(
              () {
                _voiceReplyEnabled = mode == VoiceInputMode.conversation;
                _voiceListenStarting = true;
                DebugConsole.log(
                  '[Voice/UI] input mode selected mode=${mode.name} '
                  'voiceReply=$_voiceReplyEnabled '
                  'starting=$_voiceListenStarting',
                );
              },
            ),
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
