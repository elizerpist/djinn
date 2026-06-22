import 'dart:async';

import 'package:flutter/material.dart';

import '../../branding/djinn_brand_mark.dart';
import '../../debug/debug_console.dart';
import '../../debug/debug_header_button.dart';
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
  AppSettings? _settings;
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
      _settings = settings;
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
    final scopeText = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _CitationPreviewScreen(citation: citation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    final trimmed = scopeText?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      unawaited(_send(trimmed, speakResponse: _voiceReplyEnabled));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DjinnAppBarTitle(title: widget.conversation.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (_settings case final settings?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChatModeChip(settings: settings),
            ),
          const DebugHeaderButton(),
        ],
      ),
      body: Column(
        children: [
          KnowledgeStatusBanner(state: _knowledgeState),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Ird be az elso kerdest'))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
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
            onVoiceInputModeSelected: (mode) => setState(() {
              _voiceReplyEnabled = mode == VoiceInputMode.conversation;
              _voiceListenStarting = true;
              DebugConsole.log(
                '[Voice/UI] input mode selected mode=${mode.name} '
                'voiceReply=$_voiceReplyEnabled '
                'starting=$_voiceListenStarting',
              );
            }),
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

class _CitationPreviewScreen extends StatelessWidget {
  const _CitationPreviewScreen({required this.citation});

  final ChatCitation citation;

  @override
  Widget build(BuildContext context) {
    final sourceType = citation.sourceType;
    final isFlowchart =
        sourceType == 'flowchart_node' || sourceType == 'flowchart_edge';
    final isTable = sourceType == 'table_chunk' || sourceType == 'score_chunk';
    final fullChunkText = citation.fullChunkText?.trim();
    final showFullChunk =
        fullChunkText != null &&
        fullChunkText.isNotEmpty &&
        fullChunkText != citation.excerpt.trim();
    return Scaffold(
      key: const ValueKey('citation-preview-screen'),
      appBar: AppBar(
        title: Text(citation.title),
        actions: [
          if (citation.excerpt.trim().isNotEmpty)
            IconButton(
              key: const ValueKey('citation-start-scope'),
              onPressed: () =>
                  Navigator.of(context).pop(citation.excerpt.trim()),
              icon: const Icon(Icons.account_tree_outlined),
              tooltip: 'Új scope ebből',
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Bezárás',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (citation.sourceLabel case final label?) ...[
                _PreviewHeader(label: label),
                const SizedBox(height: 12),
              ],
              if (citation.page case final page?) ...[
                Text(
                  '$page. oldal',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (citation.section case final section?) ...[
                Text(section, style: const TextStyle(color: Color(0xFF475569))),
                const SizedBox(height: 10),
              ],
              if (isFlowchart)
                _FlowchartCitationPreview(excerpt: citation.excerpt)
              else if (isTable)
                _TableCitationPreview(excerpt: citation.excerpt)
              else
                _TextCitationPreview(excerpt: citation.excerpt),
              if (showFullChunk) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'Teljes chunk',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _TextCitationPreview(
                  selectableKey: const ValueKey('citation-preview-full-chunk'),
                  excerpt: fullChunkText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TextCitationPreview extends StatelessWidget {
  const _TextCitationPreview({
    this.selectableKey = const ValueKey('citation-preview-text'),
    required this.excerpt,
  });

  final Key selectableKey;
  final String excerpt;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      key: selectableKey,
      excerpt,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 16,
        height: 1.45,
      ),
    );
  }
}

class _TableCitationPreview extends StatelessWidget {
  const _TableCitationPreview({required this.excerpt});

  final String excerpt;

  @override
  Widget build(BuildContext context) {
    final rows = excerpt
        .split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => line
              .split(line.contains('|') ? '|' : ';')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList(growable: false),
        )
        .where((row) => row.isNotEmpty)
        .toList(growable: false);
    final columns = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    return SingleChildScrollView(
      key: const ValueKey('citation-preview-table'),
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: const Color(0xFFE2E8F0)),
        children: [
          for (final row in rows)
            TableRow(
              children: [
                for (var index = 0; index < columns; index += 1)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      index < row.length ? row[index] : '',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FlowchartCitationPreview extends StatelessWidget {
  const _FlowchartCitationPreview({required this.excerpt});

  final String excerpt;

  @override
  Widget build(BuildContext context) {
    final lines = excerpt
        .split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return Column(
      key: const ValueKey('citation-preview-flowchart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              _flowchartPreviewLine(line),
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }

  String _flowchartPreviewLine(String line) {
    final match = RegExp(
      r'^\s*(.+?)\s*->\s*(.+?)(?:\s*\[(.*?)\])?\s*$',
    ).firstMatch(line);
    if (match == null) {
      return line;
    }
    final from = match.group(1)?.trim() ?? '';
    final to = match.group(2)?.trim() ?? '';
    final label = match.group(3)?.trim().toLowerCase() ?? '';
    final condition = _conditionText(from);
    if (label == 'igen') {
      return 'Ha $condition, akkor $to.';
    }
    if (label == 'nem') {
      return 'Ha nem $condition, akkor $to.';
    }
    if (label.isEmpty || label == 'kimenet') {
      return '$from után $to.';
    }
    return 'Ha $condition: $label, akkor $to.';
  }

  String _conditionText(String value) {
    final trimmed = value.trim().replaceFirst(RegExp(r'\?$'), '');
    if (trimmed.isEmpty) {
      return '';
    }
    return '${trimmed[0].toLowerCase()}${trimmed.substring(1)}';
  }
}

class ChatModeChip extends StatelessWidget {
  const ChatModeChip({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (settings.answerMode) {
      AnswerModes.offline => (
        'Offline',
        Icons.cloud_off_outlined,
        const Color(0xFF166534),
      ),
      _ => (
        settings.activeProvider.label,
        Icons.cloud_done_outlined,
        const Color(0xFF155EEF),
      ),
    };
    return Container(
      key: const ValueKey('chat-mode-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
