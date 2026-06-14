import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'src/ai/ai_client.dart';
import 'src/cases/data/case_repository.dart';
import 'src/ai/ai_provider.dart';
import 'src/chat/data/chat_service.dart';
import 'src/chat/data/local_answer_service.dart';
import 'src/chat/data/local_chat_repository.dart';
import 'src/chat/models/chat_message.dart';
import 'src/chat/data/objectbox_chat_repository.dart';
import 'src/chat/ui/main_screen.dart';
import 'src/branding/djinn_brand_mark.dart';
import 'src/flowchart/data/flowchart_validation_repository.dart';
import 'src/knowledge/data/document_processing_service.dart';
import 'src/knowledge/data/knowledge_document_repository.dart';
import 'src/knowledge/data/knowledge_sync_service.dart';
import 'src/knowledge/models/knowledge_document.dart';
import 'src/knowledge/data/objectbox_knowledge_document_repository.dart';
import 'src/knowledge/data/objectbox_knowledge_repository.dart';
import 'src/knowledge/data/local_document_processing_service.dart';
import 'src/knowledge/data/mlkit_ocr_engine.dart';
import 'src/knowledge/data/pdfrx_local_page_extractor.dart';
import 'src/knowledge/data/pdf_import_service.dart';
import 'src/local_store/objectbox_store.dart';
import 'src/google/gemini_http_client.dart';
import 'src/openai/openai_client.dart';
import 'src/openai/openai_http_client.dart';
import 'src/rag/retrieval/local_retriever.dart';
import 'src/rag/verification/citation_verifier.dart';
import 'src/settings/data/api_key_store.dart';
import 'src/settings/data/app_settings_repository.dart';
import 'src/settings/models/app_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(const DjinnApp());
}

class DjinnApp extends StatefulWidget {
  const DjinnApp({
    super.key,
    this.chatRepository,
    this.chatService,
    this.caseRepository,
    this.knowledgeRepository,
    this.pdfImportService,
    this.knowledgeSyncService,
    this.refreshKnowledgeReadiness,
    this.processingService,
    this.localProcessingService,
    this.flowchartValidationRepository,
    this.apiKeyStore,
    this.loadSettings,
    this.saveSettings,
    this.testApiKey,
    this.testApiKeyForProvider,
  });

  final LocalChatRepository? chatRepository;
  final ChatService? chatService;
  final CaseRepository? caseRepository;
  final KnowledgeDocumentRepository? knowledgeRepository;
  final PdfImportService? pdfImportService;
  final KnowledgeSyncService? knowledgeSyncService;
  final Future<KnowledgeBaseState> Function()? refreshKnowledgeReadiness;
  final DocumentProcessingService? processingService;
  final LocalDocumentProcessingService? localProcessingService;
  final FlowchartValidationRepository? flowchartValidationRepository;
  final ApiKeyStore? apiKeyStore;
  final Future<AppSettings> Function()? loadSettings;
  final Future<void> Function(AppSettings settings)? saveSettings;
  final Future<bool> Function()? testApiKey;
  final Future<bool> Function(AiProvider provider, String model)?
  testApiKeyForProvider;

  @override
  State<DjinnApp> createState() => _DjinnAppState();
}

class _DjinnAppState extends State<DjinnApp> {
  late final Future<_AppDependencies> _dependencies = _loadDependencies();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ObjectBoxStore? _objectBoxStore;

  Future<_AppDependencies> _loadDependencies() async {
    if (widget.chatRepository != null &&
        widget.knowledgeRepository != null &&
        widget.pdfImportService != null) {
      final apiKeyStore = widget.apiKeyStore ?? MemoryApiKeyStore();
      final settingsStore = _MemoryAppSettingsStore();
      final loadSettings = widget.loadSettings ?? settingsStore.load;
      final saveSettings = widget.saveSettings ?? settingsStore.save;
      final testApiKey =
          widget.testApiKey ?? _buildOpenAiKeyTester(apiKeyStore);
      return _AppDependencies(
        chatRepository: widget.chatRepository!,
        chatService:
            widget.chatService ??
            ChatService(
              repository: widget.chatRepository!,
              answerService: const _UnavailableAnswerService(),
            ),
        caseRepository: widget.caseRepository ?? MemoryCaseRepository(),
        knowledgeRepository: widget.knowledgeRepository!,
        pdfImportService: widget.pdfImportService!,
        refreshKnowledgeReadiness:
            widget.refreshKnowledgeReadiness ??
            widget.knowledgeSyncService?.refreshReadiness ??
            widget.knowledgeRepository!.state,
        processingService: widget.processingService,
        localProcessingService: widget.localProcessingService,
        flowchartValidationRepository: widget.flowchartValidationRepository,
        apiKeyStore: apiKeyStore,
        loadSettings: loadSettings,
        saveSettings: saveSettings,
        testApiKey: testApiKey,
        testApiKeyForProvider:
            widget.testApiKeyForProvider ??
            _buildFallbackProviderKeyTester(testApiKey),
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final objectBox = await ObjectBoxStore.open(directory: directory);
    _objectBoxStore = objectBox;
    final store = objectBox.store;

    final apiKeyStore = widget.apiKeyStore ?? SecureApiKeyStore();
    final settingsRepository = AppSettingsRepository(store: store);
    final openAiClient = OpenAiHttpClient(apiKeyStore: apiKeyStore);
    final geminiClient = GeminiHttpClient(apiKeyStore: apiKeyStore);
    AiClient clientForProvider(AiProvider provider) {
      return switch (provider) {
        AiProvider.openAi => openAiClient,
        AiProvider.gemini => geminiClient,
      };
    }

    Future<bool> hasKeyForProvider(AiProvider provider) {
      return apiKeyStore.hasKeyForProvider(provider);
    }

    final objectBoxKnowledgeRepository = ObjectBoxKnowledgeRepository(
      store: store,
    );
    final knowledgeRepository = ObjectBoxKnowledgeDocumentRepository(
      repository: objectBoxKnowledgeRepository,
    );
    final processingService = DocumentProcessingService(
      clientForProvider: clientForProvider,
      loadSettings: settingsRepository.load,
      hasApiKeyForProvider: hasKeyForProvider,
      repository: knowledgeRepository,
    );
    final localOcrEngine = MlKitOcrEngine();
    final localProcessingService = LocalDocumentProcessingService(
      repository: knowledgeRepository,
      pageExtractor: PdfrxLocalPageExtractor(ocrEngine: localOcrEngine),
    );
    final retriever = ObjectBoxLocalRetriever(store: store);
    final answerService = LocalAnswerService(
      clientForProvider: clientForProvider,
      retriever: retriever,
      citationVerifier: CitationVerifier(),
      loadSettings: settingsRepository.load,
      hasApiKeyForProvider: hasKeyForProvider,
      hasReadyDocuments: objectBoxKnowledgeRepository.hasReadyDocuments,
    );
    final chatRepository = ObjectBoxChatRepository(store: store);
    final caseRepository = ObjectBoxCaseRepository(store: store);
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
      caseRepository: caseRepository,
      knowledgeRepository: knowledgeRepository,
      pdfImportService: pdfImportService,
      refreshKnowledgeReadiness: knowledgeRepository.state,
      processingService: processingService,
      localProcessingService: localProcessingService,
      flowchartValidationRepository: flowchartValidationRepository,
      apiKeyStore: apiKeyStore,
      loadSettings: settingsRepository.load,
      saveSettings: (settings) async {
        await settingsRepository.save(settings);
      },
      testApiKey: _buildOpenAiKeyTester(apiKeyStore),
      testApiKeyForProvider: _buildProviderKeyTester(
        apiKeyStore: apiKeyStore,
        openAiClient: openAiClient,
        geminiClient: geminiClient,
      ),
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
      navigatorKey: _navigatorKey,
      title: 'Djinn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          primary: const Color(0xFF155EEF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        useMaterial3: true,
      ),
      builder: (context, child) => child ?? const SizedBox.shrink(),
      home: FutureBuilder<_AppDependencies>(
        future: _dependencies,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const DjinnLoadingScreen();
          }
          final dependencies = snapshot.data;
          if (dependencies == null) {
            return const Scaffold(body: Center(child: Text('Inditasi hiba')));
          }
          return MainScreen(
            repository: dependencies.chatRepository,
            chatService: dependencies.chatService,
            caseRepository: dependencies.caseRepository,
            knowledgeRepository: dependencies.knowledgeRepository,
            pdfImportService: dependencies.pdfImportService,
            refreshKnowledgeReadiness: dependencies.refreshKnowledgeReadiness,
            apiKeyStore: dependencies.apiKeyStore,
            loadSettings: dependencies.loadSettings,
            saveSettings: dependencies.saveSettings,
            testApiKey: dependencies.testApiKey,
            testApiKeyForProvider: dependencies.testApiKeyForProvider,
            processingService: dependencies.processingService,
            localProcessingService: dependencies.localProcessingService,
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
    required this.caseRepository,
    required this.knowledgeRepository,
    required this.pdfImportService,
    required this.refreshKnowledgeReadiness,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
    required this.testApiKeyForProvider,
    this.processingService,
    this.localProcessingService,
    this.flowchartValidationRepository,
  });

  final LocalChatRepository chatRepository;
  final ChatService chatService;
  final CaseRepository caseRepository;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;
  final Future<KnowledgeBaseState> Function() refreshKnowledgeReadiness;
  final DocumentProcessingService? processingService;
  final LocalDocumentProcessingService? localProcessingService;
  final FlowchartValidationRepository? flowchartValidationRepository;
  final ApiKeyStore apiKeyStore;
  final Future<AppSettings> Function() loadSettings;
  final Future<void> Function(AppSettings settings) saveSettings;
  final Future<bool> Function() testApiKey;
  final Future<bool> Function(AiProvider provider, String model)
  testApiKeyForProvider;
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

Future<bool> Function(AiProvider provider, String model)
_buildFallbackProviderKeyTester(Future<bool> Function() openAiTester) {
  return (provider, _) {
    if (provider == AiProvider.openAi) {
      return openAiTester();
    }
    return Future.value(false);
  };
}

Future<bool> Function(AiProvider provider, String model)
_buildProviderKeyTester({
  required ApiKeyStore apiKeyStore,
  required OpenAiHttpClient openAiClient,
  required GeminiHttpClient geminiClient,
}) {
  return (provider, model) async {
    final key = await apiKeyStore.readKeyForProvider(provider);
    if (key == null || key.trim().isEmpty) {
      return false;
    }
    switch (provider) {
      case AiProvider.openAi:
        await openAiClient.testApiKey(apiKey: key, model: model);
      case AiProvider.gemini:
        await geminiClient.testApiKey(apiKey: key, model: model);
    }
    return true;
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
  Future<LocalAnswerResult> answer(
    String question, {
    List<ChatMessage> context = const [],
  }) async {
    return const LocalAnswerResult(
      text:
          'A helyi B mód még nincs teljesen inicializálva. Importálj PDF-et és állítsd be az OpenAI kulcsot.',
      status: 'local_mode_not_ready',
      refusalReason: 'local_mode_not_ready',
      citations: [],
    );
  }
}
