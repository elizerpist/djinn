import 'package:flutter/material.dart';

import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/data/pdf_import_service.dart';
import '../../knowledge/ui/knowledge_base_screen.dart';
import '../data/local_chat_repository.dart';
import '../models/chat_conversation.dart';
import 'chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.repository,
    required this.knowledgeRepository,
    required this.pdfImportService,
  });

  final LocalChatRepository repository;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;

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

  Future<void> _openNewChat() async {
    final conversation = await widget.repository.createConversation();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          repository: widget.repository,
          knowledgeRepository: widget.knowledgeRepository,
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
          knowledgeRepository: widget.knowledgeRepository,
          conversation: conversation,
        ),
      ),
    );
    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
