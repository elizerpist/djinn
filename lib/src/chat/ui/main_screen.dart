import 'package:flutter/material.dart';

import '../../ai/ai_provider.dart';
import '../../cases/data/case_repository.dart';
import '../../branding/djinn_brand_mark.dart';
import '../../cases/ui/cases_screen.dart';
import '../../debug/debug_header_button.dart';
import '../../flowchart/data/flowchart_validation_repository.dart';
import '../../flowchart/ui/flowchart_hub_screen.dart';
import '../../flowchart/ui/flowchart_validation_screen.dart';
import '../../knowledge/data/document_processing_service.dart';
import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/data/local_document_processing_service.dart';
import '../../knowledge/data/pdf_import_service.dart';
import '../../knowledge/models/knowledge_document.dart';
import '../../knowledge/ui/knowledge_base_screen.dart';
import '../../settings/data/api_key_store.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/ui/settings_screen.dart';
import '../data/chat_service.dart';
import '../data/local_chat_repository.dart';
import '../models/chat_conversation.dart';
import 'app_destination.dart';
import 'chat_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.repository,
    required this.chatService,
    required this.knowledgeRepository,
    required this.pdfImportService,
    required this.refreshKnowledgeReadiness,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
    required this.caseRepository,
    this.testApiKeyForProvider,
    this.processingService,
    this.localProcessingService,
    this.flowchartValidationRepository,
  });

  final LocalChatRepository repository;
  final ChatService chatService;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;
  final Future<KnowledgeBaseState> Function() refreshKnowledgeReadiness;
  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;
  final CaseRepository caseRepository;
  final Future<bool> Function(AiProvider provider, String model)?
  testApiKeyForProvider;
  final DocumentProcessingService? processingService;
  final LocalDocumentProcessingService? localProcessingService;
  final FlowchartValidationRepository? flowchartValidationRepository;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<ChatConversation> _conversations = const [];
  AppSettings _settings = AppSettings.defaults();
  AppDestinationId _selectedDestination = AppDestinationId.chat;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadConversations();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      if (settings.navigationMode == AppNavigationMode.drawer) {
        _selectedDestination = AppDestinationId.chat;
      }
    });
  }

  void _handleSettingsChanged(AppSettings settings) {
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      if (settings.navigationMode == AppNavigationMode.drawer) {
        _selectedDestination = AppDestinationId.chat;
      }
    });
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
          processingService: widget.processingService,
          localProcessingService: widget.localProcessingService,
        ),
      ),
    );
  }

  Future<void> _openFlowchartValidation() async {
    final repository = widget.flowchartValidationRepository;
    if (repository == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlowchartValidationScreen(repository: repository),
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
          testApiKeyForProvider: widget.testApiKeyForProvider,
          onSettingsChanged: _handleSettingsChanged,
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
          refreshKnowledgeReadiness: widget.refreshKnowledgeReadiness,
          conversation: conversation,
          loadSettings: widget.loadSettings,
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
          refreshKnowledgeReadiness: widget.refreshKnowledgeReadiness,
          conversation: conversation,
          loadSettings: widget.loadSettings,
        ),
      ),
    );
    await _loadConversations();
  }

  Future<List<CaseLinkCandidate>> _loadChatLinkCandidates(String caseId) async {
    final conversations = await widget.repository.listConversations();
    return [
      for (final conversation in conversations)
        CaseLinkCandidate(
          id: conversation.id,
          title: conversation.title,
          subtitle: '${conversation.messages.length} üzenet',
        ),
    ];
  }

  Future<List<CaseLinkCandidate>> _loadDocumentLinkCandidates(
    String caseId,
  ) async {
    final documents = await widget.knowledgeRepository.listDocuments();
    return [
      for (final document in documents)
        CaseLinkCandidate(
          id: document.id,
          title: document.filename,
          subtitle: document.syncStatusLabel,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_settings.navigationMode == AppNavigationMode.bottomNav) {
      return _buildBottomNavShell();
    }
    return _buildDrawerShell();
  }

  Widget _buildDrawerShell() {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const DjinnAppBarTitle(title: 'Djinn'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          const DebugHeaderButton(),
          IconButton(
            tooltip: 'Tudastar',
            onPressed: _openKnowledgeBase,
            icon: const Icon(Icons.folder),
          ),
        ],
      ),
      body: _buildChatListBody(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Új chat',
        onPressed: _openNewChat,
        child: const Icon(Icons.add_comment),
      ),
    );
  }

  Widget _buildBottomNavShell() {
    final index = appDestinations.indexWhere(
      (destination) => destination.id == _selectedDestination,
    );
    return Scaffold(
      appBar: _destinationOwnsScaffold(_selectedDestination)
          ? null
          : AppBar(
              title: DjinnAppBarTitle(title: _titleForDestination(_selectedDestination)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              actions: const [DebugHeaderButton()],
            ),
      body: _buildDestinationBody(_selectedDestination),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 2 : index,
        onDestinationSelected: (index) {
          setState(() => _selectedDestination = appDestinations[index].id);
        },
        destinations: [
          for (final destination in appDestinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.icon),
              label: destination.compactLabel,
              tooltip: destination.label,
            ),
        ],
      ),
      floatingActionButton: _selectedDestination == AppDestinationId.chat
          ? FloatingActionButton(
              tooltip: 'Új chat',
              onPressed: _openNewChat,
              child: const Icon(Icons.add_comment),
            )
          : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const ListTile(
              title: Text('Djinn'),
              subtitle: Text('Local ObjectBox mód'),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Esetek'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CasesScreen(
                          repository: widget.caseRepository,
                          loadChatLinkCandidates: _loadChatLinkCandidates,
                          loadDocumentLinkCandidates: _loadDocumentLinkCandidates,
                        ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Beszélgetések'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Tudástár'),
              onTap: () {
                Navigator.of(context).pop();
                _openKnowledgeBase();
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('Kinyert tartalom audit'),
              enabled: widget.flowchartValidationRepository != null,
              onTap: widget.flowchartValidationRepository == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _openFlowchartValidation();
                    },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Beállítások'),
              onTap: () {
                Navigator.of(context).pop();
                _openSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationBody(AppDestinationId destination) {
    return switch (destination) {
      AppDestinationId.cases => CasesScreen(
        repository: widget.caseRepository,
        showAppBar: false,
        loadChatLinkCandidates: _loadChatLinkCandidates,
        loadDocumentLinkCandidates: _loadDocumentLinkCandidates,
      ),
      AppDestinationId.knowledge => KnowledgeBaseScreen(
        repository: widget.knowledgeRepository,
        importService: widget.pdfImportService,
        processingService: widget.processingService,
        localProcessingService: widget.localProcessingService,
      ),
      AppDestinationId.chat => _buildChatListBody(),
      AppDestinationId.flow => _buildFlowDestination(),
      AppDestinationId.settings => SettingsScreen(
        apiKeyStore: widget.apiKeyStore,
        loadSettings: widget.loadSettings,
        saveSettings: widget.saveSettings,
        testApiKey: widget.testApiKey,
        testApiKeyForProvider: widget.testApiKeyForProvider,
        onSettingsChanged: _handleSettingsChanged,
      ),
    };
  }

  Widget _buildFlowDestination() {
    return FlowchartHubScreen(
      validationRepository: widget.flowchartValidationRepository,
      knowledgeRepository: widget.knowledgeRepository,
    );
  }

  Widget _buildChatListBody() {
    return _conversations.isEmpty
        ? const Center(
            child: Text(
              'Nincs még beszélgetés',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          )
        : ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
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
          );
  }

  bool _destinationOwnsScaffold(AppDestinationId destination) {
    return switch (destination) {
      AppDestinationId.knowledge ||
      AppDestinationId.flow ||
      AppDestinationId.settings => true,
      AppDestinationId.cases || AppDestinationId.chat => false,
    };
  }

  String _titleForDestination(AppDestinationId destination) {
    return switch (destination) {
      AppDestinationId.cases => 'Esetek',
      AppDestinationId.knowledge => 'Tudástár',
      AppDestinationId.chat => 'Djinn',
      AppDestinationId.flow => 'Audit',
      AppDestinationId.settings => 'Beállítások',
    };
  }
}
