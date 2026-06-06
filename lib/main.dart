import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/chat/data/chat_service.dart';
import 'src/chat/data/local_answer_service.dart';
import 'src/chat/data/local_chat_repository.dart';
import 'src/chat/data/objectbox_chat_repository.dart';
import 'src/chat/ui/main_screen.dart';
import 'src/flowchart/data/flowchart_validation_repository.dart';
import 'src/knowledge/data/document_processing_service.dart';
import 'src/knowledge/data/knowledge_document_repository.dart';
import 'src/knowledge/data/knowledge_sync_service.dart';
import 'src/knowledge/models/knowledge_document.dart';
import 'src/knowledge/data/objectbox_knowledge_document_repository.dart';
import 'src/knowledge/data/objectbox_knowledge_repository.dart';
import 'src/knowledge/data/pdf_import_service.dart';
import 'src/local_store/objectbox_store.dart';
import 'src/openai/openai_client.dart';
import 'src/openai/openai_http_client.dart';
import 'src/rag/retrieval/local_retriever.dart';
import 'src/rag/verification/citation_verifier.dart';
import 'src/settings/data/api_key_store.dart';
import 'src/settings/data/app_settings_repository.dart';
import 'src/settings/models/app_settings.dart';

void main() {
  runApp(const DjinnApp());
}

class DjinnApp extends StatefulWidget {
  const DjinnApp({
    super.key,
    this.chatRepository,
    this.chatService,
    this.knowledgeRepository,
    this.pdfImportService,
    this.knowledgeSyncService,
    this.refreshKnowledgeReadiness,
    this.processingService,
    this.flowchartValidationRepository,
    this.apiKeyStore,
    this.loadSettings,
    this.saveSettings,
    this.testApiKey,
  });

  final LocalChatRepository? chatRepository;
  final ChatService? chatService;
  final KnowledgeDocumentRepository? knowledgeRepository;
  final PdfImportService? pdfImportService;
  final KnowledgeSyncService? knowledgeSyncService;
  final Future<KnowledgeBaseState> Function()? refreshKnowledgeReadiness;
  final DocumentProcessingService? processingService;
  final FlowchartValidationRepository? flowchartValidationRepository;
  final ApiKeyStore? apiKeyStore;
  final Future<AppSettings> Function()? loadSettings;
  final Future<void> Function(AppSettings settings)? saveSettings;
  final Future<bool> Function()? testApiKey;

  @override
  State<DjinnApp> createState() => _DjinnAppState();
}

class _DjinnAppState extends State<DjinnApp> {
  late final Future<_AppDependencies> _dependencies = _loadDependencies();
  ObjectBoxStore? _objectBoxStore;

  Future<_AppDependencies> _loadDependencies() async {
    if (widget.chatRepository != null &&
        widget.knowledgeRepository != null &&
        widget.pdfImportService != null) {
      final apiKeyStore = widget.apiKeyStore ?? MemoryApiKeyStore();
      final settingsStore = _MemoryAppSettingsStore();
      final loadSettings = widget.loadSettings ?? settingsStore.load;
      final saveSettings = widget.saveSettings ?? settingsStore.save;
      return _AppDependencies(
        chatRepository: widget.chatRepository!,
        chatService:
            widget.chatService ??
            ChatService(
              repository: widget.chatRepository!,
              answerService: const _UnavailableAnswerService(),
            ),
        knowledgeRepository: widget.knowledgeRepository!,
        pdfImportService: widget.pdfImportService!,
        refreshKnowledgeReadiness:
            widget.refreshKnowledgeReadiness ??
            widget.knowledgeSyncService?.refreshReadiness ??
            widget.knowledgeRepository!.state,
        processingService: widget.processingService,
        flowchartValidationRepository: widget.flowchartValidationRepository,
        apiKeyStore: apiKeyStore,
        loadSettings: loadSettings,
        saveSettings: saveSettings,
        testApiKey: widget.testApiKey ?? _buildOpenAiKeyTester(apiKeyStore),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final objectBox = await ObjectBoxStore.open(directory: directory);
    _objectBoxStore = objectBox;
    final store = objectBox.store;

    final apiKeyStore = widget.apiKeyStore ?? SecureApiKeyStore();
    final settingsRepository = AppSettingsRepository(store: store);
    final openAiClient = OpenAiHttpClient(apiKeyStore: apiKeyStore);
    final objectBoxKnowledgeRepository = ObjectBoxKnowledgeRepository(
      store: store,
    );
    final knowledgeRepository = ObjectBoxKnowledgeDocumentRepository(
      repository: objectBoxKnowledgeRepository,
    );
    final processingService = DocumentProcessingService(
      openAiClient: openAiClient,
      loadSettings: settingsRepository.load,
      hasApiKey: apiKeyStore.hasKey,
      repository: knowledgeRepository,
    );
    final retriever = ObjectBoxLocalRetriever(store: store);
    final answerService = LocalAnswerService(
      openAiClient: openAiClient,
      retriever: retriever,
      citationVerifier: CitationVerifier(),
      loadSettings: settingsRepository.load,
      hasApiKey: apiKeyStore.hasKey,
      hasReadyDocuments: objectBoxKnowledgeRepository.hasReadyDocuments,
    );
    final chatRepository = ObjectBoxChatRepository(store: store);
    final chatService = ChatService(
      repository: chatRepository,
      answerService: answerService,
    );
    final pdfImportService = PdfImportService(
      importDirectory: Directory('${directory.path}/knowledge_pdfs'),
    );
    final flowchartValidationRepository =
        ObjectBoxFlowchartValidationRepository(store: store);

    return _AppDependencies(
      chatRepository: chatRepository,
      chatService: chatService,
      knowledgeRepository: knowledgeRepository,
      pdfImportService: pdfImportService,
      refreshKnowledgeReadiness: knowledgeRepository.state,
      processingService: processingService,
      flowchartValidationRepository: flowchartValidationRepository,
      apiKeyStore: apiKeyStore,
      loadSettings: settingsRepository.load,
      saveSettings: (settings) async {
        await settingsRepository.save(settings);
      },
      testApiKey: _buildOpenAiKeyTester(apiKeyStore),
    );
  }

  @override
  void dispose() {
    _objectBoxStore?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Djinn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          primary: const Color(0xFF155EEF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        useMaterial3: true,
      ),
      home: FutureBuilder<_AppDependencies>(
        future: _dependencies,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final dependencies = snapshot.data;
          if (dependencies == null) {
            return const Scaffold(body: Center(child: Text('Inditasi hiba')));
          }
          return MainScreen(
            repository: dependencies.chatRepository,
            chatService: dependencies.chatService,
            knowledgeRepository: dependencies.knowledgeRepository,
            pdfImportService: dependencies.pdfImportService,
            refreshKnowledgeReadiness: dependencies.refreshKnowledgeReadiness,
            apiKeyStore: dependencies.apiKeyStore,
            loadSettings: dependencies.loadSettings,
            saveSettings: dependencies.saveSettings,
            testApiKey: dependencies.testApiKey,
            processingService: dependencies.processingService,
            flowchartValidationRepository:
                dependencies.flowchartValidationRepository,
          );
        },
      ),
    );
  }
}

class _AppDependencies {
  const _AppDependencies({
    required this.chatRepository,
    required this.chatService,
    required this.knowledgeRepository,
    required this.pdfImportService,
    required this.refreshKnowledgeReadiness,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
    this.processingService,
    this.flowchartValidationRepository,
  });

  final LocalChatRepository chatRepository;
  final ChatService chatService;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;
  final Future<KnowledgeBaseState> Function() refreshKnowledgeReadiness;
  final DocumentProcessingService? processingService;
  final FlowchartValidationRepository? flowchartValidationRepository;
  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;
}

Future<bool> Function() _buildOpenAiKeyTester(ApiKeyStore apiKeyStore) {
  final client = OpenAiHttpClient(apiKeyStore: apiKeyStore);
  return () async {
    final key = await apiKeyStore.readKey();
    if (key == null || key.trim().isEmpty) {
      return false;
    }
    try {
      await client.testApiKey(apiKey: key);
      return true;
    } on OpenAiException {
      return false;
    }
  };
}

class _MemoryAppSettingsStore {
  AppSettings _settings = AppSettings.defaults();

  Future<AppSettings> load() async => _settings;

  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

class MyApp extends DjinnApp {
  const MyApp({super.key});
}

class _UnavailableAnswerService implements AnswerService {
  const _UnavailableAnswerService();

  @override
  Future<LocalAnswerResult> answer(String question) async {
    return const LocalAnswerResult(
      text:
          'A helyi B mód még nincs teljesen inicializálva. Importálj PDF-et és állítsd be az OpenAI kulcsot.',
      status: 'local_mode_not_ready',
      refusalReason: 'local_mode_not_ready',
      citations: [],
    );
  }
}
