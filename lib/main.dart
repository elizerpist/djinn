import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

import 'objectbox.g.dart';
import 'src/admin/ui/admin_screen.dart';
import 'src/ai/gemini_ai_client.dart';
import 'src/ai/provider_routing_client.dart';
import 'src/chat/data/chat_service.dart';
import 'src/chat/data/local_answer_service.dart';
import 'src/chat/data/local_chat_repository.dart';
import 'src/chat/data/objectbox_chat_repository.dart';
import 'src/chat/ui/main_screen.dart';
import 'src/debug/debug_floating_button.dart';
import 'src/flowchart/data/flowchart_validation_repository.dart';
import 'src/knowledge/data/document_processing_service.dart';
import 'src/knowledge/data/knowledge_document_repository.dart';
import 'src/knowledge/data/knowledge_sync_service.dart';
import 'src/knowledge/models/knowledge_document.dart';
import 'src/knowledge/data/objectbox_knowledge_document_repository.dart';
import 'src/knowledge/data/objectbox_knowledge_repository.dart';
import 'src/knowledge/data/pdf_import_service.dart';
import 'src/knowledge/data/training_pack_service.dart';
import 'src/local_store/entities.dart';
import 'src/local_store/objectbox_store.dart';
import 'src/openai/openai_client.dart';
import 'src/openai/openai_http_client.dart';
import 'src/rag/retrieval/local_retriever.dart';
import 'src/rag/verification/citation_verifier.dart';
import 'src/settings/data/api_key_store.dart';
import 'src/settings/data/app_settings_repository.dart';
import 'src/settings/models/app_settings.dart';
import 'src/voice/text_to_speech_service.dart';
import 'src/voice/voice_input_service.dart';

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
    this.testGoogleApiKey,
    this.voiceInputService,
    this.textToSpeechService,
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
  final Future<bool> Function()? testGoogleApiKey;
  final VoiceInputService? voiceInputService;
  final TextToSpeechService? textToSpeechService;

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
        testGoogleApiKey:
            widget.testGoogleApiKey ?? _buildGoogleKeyTester(apiKeyStore),
        voiceInputService: widget.voiceInputService,
        textToSpeechService: widget.textToSpeechService,
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final objectBox = await ObjectBoxStore.open(directory: directory);
    _objectBoxStore = objectBox;
    final store = objectBox.store;

    final apiKeyStore = widget.apiKeyStore ?? SecureApiKeyStore();
    final settingsRepository = AppSettingsRepository(store: store);
    final openAiClient = OpenAiHttpClient(apiKeyStore: apiKeyStore);
    final googleClient = GeminiAiClient(apiKeyStore: apiKeyStore);
    final routingClient = ProviderRoutingAiClient(
      openAiClient: openAiClient,
      googleClient: googleClient,
      loadSettings: settingsRepository.load,
    );
    final objectBoxKnowledgeRepository = ObjectBoxKnowledgeRepository(
      store: store,
    );
    final trainingPackService = TrainingPackService(
      repository: objectBoxKnowledgeRepository,
    );
    final knowledgeRepository = ObjectBoxKnowledgeDocumentRepository(
      repository: objectBoxKnowledgeRepository,
    );
    final processingService = DocumentProcessingService(
      openAiClient: routingClient,
      loadSettings: settingsRepository.load,
      hasApiKey: () => _hasActiveApiKey(
        apiKeyStore: apiKeyStore,
        loadSettings: settingsRepository.load,
      ),
      repository: knowledgeRepository,
    );
    final retriever = ObjectBoxLocalRetriever(store: store);
    final answerService = LocalAnswerService(
      openAiClient: routingClient,
      retriever: retriever,
      citationVerifier: CitationVerifier(),
      loadSettings: settingsRepository.load,
      hasApiKey: () => _hasActiveApiKey(
        apiKeyStore: apiKeyStore,
        loadSettings: settingsRepository.load,
      ),
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
      testGoogleApiKey: _buildGoogleKeyTester(apiKeyStore),
      voiceInputService:
          widget.voiceInputService ?? SpeechToTextVoiceInputService(),
      textToSpeechService:
          widget.textToSpeechService ?? FlutterTextToSpeechService(),
      loadAdminSummary: () async => _loadAdminSummary(store),
      clearKnowledgeBase: () async => _clearKnowledgeBase(store),
      exportTrainingPack: () => _exportTrainingPack(trainingPackService),
      importTrainingPack: () => _importTrainingPack(trainingPackService),
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
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(builder: (_) => child ?? const SizedBox.shrink()),
            OverlayEntry(
              builder: (_) => DebugFloatingButton(navigatorKey: _navigatorKey),
            ),
          ],
        );
      },
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
            testGoogleApiKey: dependencies.testGoogleApiKey,
            processingService: dependencies.processingService,
            flowchartValidationRepository:
                dependencies.flowchartValidationRepository,
            voiceInputService: dependencies.voiceInputService,
            textToSpeechService: dependencies.textToSpeechService,
            loadAdminSummary: dependencies.loadAdminSummary,
            clearKnowledgeBase: dependencies.clearKnowledgeBase,
            exportTrainingPack: dependencies.exportTrainingPack,
            importTrainingPack: dependencies.importTrainingPack,
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
    required this.testGoogleApiKey,
    this.voiceInputService,
    this.textToSpeechService,
    this.processingService,
    this.flowchartValidationRepository,
    this.loadAdminSummary,
    this.clearKnowledgeBase,
    this.exportTrainingPack,
    this.importTrainingPack,
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
  final Future<bool> Function() testGoogleApiKey;
  final VoiceInputService? voiceInputService;
  final TextToSpeechService? textToSpeechService;
  final Future<AdminSummary> Function()? loadAdminSummary;
  final Future<void> Function()? clearKnowledgeBase;
  final Future<String?> Function()? exportTrainingPack;
  final Future<String?> Function()? importTrainingPack;
}

Future<AdminSummary> _loadAdminSummary(Store store) async {
  return AdminSummary(
    documentCount: store.box<KnowledgeDocumentEntity>().count(),
    chunkCount: store.box<DocumentChunkEntity>().count(),
    flowchartCount: store.box<FlowchartEntity>().count(),
  );
}

Future<void> _clearKnowledgeBase(Store store) async {
  store.box<ChunkEmbeddingEntity>().removeAll();
  store.box<FlowchartEdgeEntity>().removeAll();
  store.box<FlowchartNodeEntity>().removeAll();
  store.box<FlowchartEntity>().removeAll();
  store.box<DocumentChunkEntity>().removeAll();
  store.box<KnowledgeDocumentEntity>().removeAll();
}

Future<String?> _exportTrainingPack(TrainingPackService service) async {
  final jsonText = await service.exportPack();
  final bytes = Uint8List.fromList(utf8.encode(jsonText));
  final path = await FilePicker.saveFile(
    dialogTitle: 'Djinn training pack mentése',
    fileName: 'djinn-training.djinnpack',
    bytes: bytes,
  );
  if (path == null) {
    return null;
  }
  final file = File(path);
  if (!await file.exists()) {
    await file.writeAsBytes(bytes);
  }
  return path;
}

Future<String?> _importTrainingPack(TrainingPackService service) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['djinnpack', 'json'],
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  final file = result.files.single;
  final bytes = file.bytes;
  final text = bytes != null
      ? utf8.decode(bytes)
      : await File(file.path!).readAsString();
  await service.importPack(text);
  return file.name;
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

Future<bool> Function() _buildGoogleKeyTester(ApiKeyStore apiKeyStore) {
  final client = GeminiAiClient(apiKeyStore: apiKeyStore);
  return () async {
    final key = await apiKeyStore.readKey(provider: ApiKeyProvider.google);
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

Future<bool> _hasActiveApiKey({
  required ApiKeyStore apiKeyStore,
  required Future<AppSettings> Function() loadSettings,
}) async {
  final settings = await loadSettings();
  return apiKeyStore.hasKey(
    provider: settings.usesGoogle
        ? ApiKeyProvider.google
        : ApiKeyProvider.openai,
  );
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
    String? collectionName,
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
