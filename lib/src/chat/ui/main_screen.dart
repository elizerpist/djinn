import 'package:flutter/material.dart';

import '../../ai/ai_provider.dart';
import '../../branding/djinn_brand_mark.dart';
import '../../cases/data/case_repository.dart';
import '../../debug/debug_header_button.dart';
import '../../debug/debug_console.dart';
import '../../flowchart/data/flowchart_validation_repository.dart';
import '../../knowledge/data/document_processing_service.dart';
import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/data/local_document_processing_service.dart';
import '../../knowledge/data/pdf_import_service.dart';
import '../../knowledge/models/knowledge_document.dart';
import '../../knowledge/ui/knowledge_base_screen.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/data/tag_repository.dart';
import '../../notes/ui/notes_screen.dart';
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
    required this.noteRepository,
    this.tagRepository,
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
  final NoteRepository noteRepository;
  final TagRepository? tagRepository;
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
  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();
  final NotesScreenController _notesController = NotesScreenController();
  final KnowledgeBaseScreenController _knowledgeController =
      KnowledgeBaseScreenController();
  List<ChatConversation> _conversations = const [];
  AppDestinationId _selectedDestination = AppDestinationId.chat;
  final Map<AppDestinationId, Widget> _destinationBodyCache =
      <AppDestinationId, Widget>{};

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _handleSettingsChanged(AppSettings settings) {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _loadConversations() async {
    final conversations = await widget.repository.listConversations();
    if (!mounted) {
      return;
    }
    setState(() => _conversations = conversations);
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

  @override
  Widget build(BuildContext context) {
    return _buildBottomNavShell();
  }

  Widget _buildBottomNavShell() {
    final index = appDestinations.indexWhere(
      (destination) => destination.id == _selectedDestination,
    );
    _destinationBodyCache.putIfAbsent(
      _selectedDestination,
      () => _buildDestinationBody(_selectedDestination),
    );
    return Scaffold(
      appBar: _destinationOwnsScaffold(_selectedDestination)
          ? null
          : AppBar(
              title: DjinnAppBarTitle(
                title: _titleForDestination(_selectedDestination),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              actions: const [DebugHeaderButton()],
            ),
      body: IndexedStack(
        index: index < 0 ? 2 : index,
        children: [
          for (final destination in appDestinations)
            _destinationBodyCache[destination.id] ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 2 : index,
        onDestinationSelected: (index) {
          final destination = appDestinations[index].id;
          if (destination == _selectedDestination) {
            return;
          }
          DebugConsole.log(
            '[MainNav] switch from=${_selectedDestination.name} '
            'to=${destination.name}',
          );
          setState(() {
            _selectedDestination = destination;
            _destinationBodyCache.putIfAbsent(
              destination,
              () => _buildDestinationBody(destination),
            );
          });
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
      floatingActionButton: _buildDestinationFab(),
    );
  }

  Widget _buildDestinationFab() {
    final child = switch (_selectedDestination) {
      AppDestinationId.chat => FloatingActionButton(
        key: const ValueKey('main-destination-fab-chat'),
        heroTag: 'main-destination-fab-chat',
        tooltip: 'Új chat',
        onPressed: _openNewChat,
        child: const Icon(Icons.add_comment),
      ),
      AppDestinationId.notes => FloatingActionButton(
        key: const ValueKey('main-destination-fab-notes'),
        heroTag: 'main-destination-fab-notes',
        tooltip: 'Új jegyzet',
        onPressed: _notesController.openEditor,
        child: const Icon(Icons.note_add_outlined),
      ),
      AppDestinationId.knowledge => FloatingActionButton(
        key: const ValueKey('main-destination-fab-knowledge'),
        heroTag: 'main-destination-fab-knowledge',
        tooltip: 'PDF/PNG hozzáadása',
        onPressed: _knowledgeController.importPdfs,
        child: const Icon(Icons.upload_file),
      ),
      AppDestinationId.settings => const SizedBox.shrink(
        key: ValueKey('main-destination-fab-empty'),
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        final outgoing = animation.status == AnimationStatus.reverse;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );
        final turns = Tween<double>(
          begin: outgoing ? -0.18 : 0.18,
          end: 0,
        ).animate(curved);
        return ScaleTransition(
          scale: curved,
          child: RotationTransition(turns: turns, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildDestinationBody(AppDestinationId destination) {
    return switch (destination) {
      AppDestinationId.notes => NotesScreen(
        repository: widget.noteRepository,
        tagRepository: _tagRepository,
        controller: _notesController,
        showFloatingActionButton: false,
      ),
      AppDestinationId.knowledge => KnowledgeBaseScreen(
        repository: widget.knowledgeRepository,
        importService: widget.pdfImportService,
        processingService: widget.processingService,
        localProcessingService: widget.localProcessingService,
        controller: _knowledgeController,
        showFloatingActionButton: false,
      ),
      AppDestinationId.chat => _buildChatListBody(),
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
      AppDestinationId.notes ||
      AppDestinationId.knowledge ||
      AppDestinationId.settings => true,
      AppDestinationId.chat => false,
    };
  }

  String _titleForDestination(AppDestinationId destination) {
    return switch (destination) {
      AppDestinationId.notes => 'Jegyzetek',
      AppDestinationId.knowledge => 'Tudástár',
      AppDestinationId.chat => 'Djinn',
      AppDestinationId.settings => 'Beállítások',
    };
  }
}
