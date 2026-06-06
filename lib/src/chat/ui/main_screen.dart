import 'package:flutter/material.dart';

import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/data/pdf_import_service.dart';
import '../../knowledge/data/knowledge_sync_service.dart';
import '../../knowledge/ui/knowledge_base_screen.dart';
import '../../settings/data/api_key_store.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/ui/settings_screen.dart';
import '../data/chat_service.dart';
import '../data/local_chat_repository.dart';
import '../models/chat_conversation.dart';
import 'chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.repository,
    required this.chatService,
    required this.knowledgeRepository,
    required this.pdfImportService,
    required this.knowledgeSyncService,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
  });

  final LocalChatRepository repository;
  final ChatService chatService;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;
  final KnowledgeSyncService knowledgeSyncService;
  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<ChatConversation> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final conversations = await widget.repository.listConversations();
    if (!mounted) {
      return;
    }
    setState(() => _conversations = conversations);
  }

  Future<void> _openKnowledgeBase() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeBaseScreen(
          repository: widget.knowledgeRepository,
          importService: widget.pdfImportService,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          apiKeyStore: widget.apiKeyStore,
          loadSettings: widget.loadSettings,
          saveSettings: widget.saveSettings,
          testApiKey: widget.testApiKey,
        ),
      ),
    );
  }

  Future<void> _openNewChat() async {
    final conversation = await widget.repository.createConversation();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          repository: widget.repository,
          chatService: widget.chatService,
          knowledgeSyncService: widget.knowledgeSyncService,
          conversation: conversation,
        ),
      ),
    );
    await _loadConversations();
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          repository: widget.repository,
          chatService: widget.chatService,
          knowledgeSyncService: widget.knowledgeSyncService,
          conversation: conversation,
        ),
      ),
    );
    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                title: Text('Djinn'),
                subtitle: Text('Local ObjectBox mód'),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Beállítások'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Tudástár'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openKnowledgeBase();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Djinn'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tudastar',
            onPressed: _openKnowledgeBase,
            icon: const Icon(Icons.folder),
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? const Center(
              child: Text(
                'Nincs meg chat',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _conversations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(conversation.title),
                  subtitle: Text('${conversation.messages.length} uzenet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openConversation(conversation),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Uj chat',
        onPressed: _openNewChat,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}
