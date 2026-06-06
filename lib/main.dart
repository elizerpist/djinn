import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/chat/data/chat_service.dart';
import 'src/chat/data/local_answer_service.dart';
import 'src/chat/data/local_chat_repository.dart';
import 'src/chat/ui/main_screen.dart';
import 'src/core/storage/json_file_store.dart';
import 'src/knowledge/data/knowledge_api_client.dart';
import 'src/knowledge/data/knowledge_document_repository.dart';
import 'src/knowledge/data/knowledge_sync_service.dart';
import 'src/knowledge/data/pdf_import_service.dart';
import 'src/openai/openai_client.dart';
import 'src/openai/openai_http_client.dart';
import 'src/settings/data/api_key_store.dart';
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
  final ApiKeyStore? apiKeyStore;
  final Future<AppSettings> Function()? loadSettings;
  final Future<void> Function(AppSettings settings)? saveSettings;
  final Future<bool> Function()? testApiKey;

  @override
  State<DjinnApp> createState() => _DjinnAppState();
}

class _DjinnAppState extends State<DjinnApp> {
  late final Future<_AppDependencies> _dependencies = _loadDependencies();

  Future<_AppDependencies> _loadDependencies() async {
    final apiKeyStore = widget.apiKeyStore ?? SecureApiKeyStore();
    final settingsStore = _MemoryAppSettingsStore();
    final loadSettings = widget.loadSettings ?? settingsStore.load;
    final saveSettings = widget.saveSettings ?? settingsStore.save;
    final testApiKey = widget.testApiKey ?? _buildOpenAiKeyTester(apiKeyStore);

    if (widget.chatRepository != null &&
        widget.knowledgeRepository != null &&
        widget.pdfImportService != null) {
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
        knowledgeSyncService:
            widget.knowledgeSyncService ??
            KnowledgeSyncService(
              repository: widget.knowledgeRepository!,
              client: KnowledgeApiClient(baseUri: _backendUri()),
            ),
        apiKeyStore: apiKeyStore,
        loadSettings: loadSettings,
        saveSettings: saveSettings,
        testApiKey: testApiKey,
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final chatRepository =
        widget.chatRepository ??
        LocalChatRepository(
          store: JsonFileStore(File('${directory.path}/chat.json')),
        );
    await chatRepository.load();

    final chatService =
        widget.chatService ??
        ChatService(
          repository: chatRepository,
          answerService: const _UnavailableAnswerService(),
        );

    final knowledgeRepository =
        widget.knowledgeRepository ??
        KnowledgeDocumentRepository(
          store: JsonFileStore(
            File('${directory.path}/knowledge_documents.json'),
          ),
        );
    await knowledgeRepository.load();

    final pdfImportService =
        widget.pdfImportService ??
        PdfImportService(
          importDirectory: Directory('${directory.path}/knowledge_pdfs'),
        );

    final knowledgeSyncService =
        widget.knowledgeSyncService ??
        KnowledgeSyncService(
          repository: knowledgeRepository,
          client: KnowledgeApiClient(baseUri: _backendUri()),
        );

    return _AppDependencies(
      chatRepository: chatRepository,
      chatService: chatService,
      knowledgeRepository: knowledgeRepository,
      pdfImportService: pdfImportService,
      knowledgeSyncService: knowledgeSyncService,
      apiKeyStore: apiKeyStore,
      loadSettings: loadSettings,
      saveSettings: saveSettings,
      testApiKey: testApiKey,
    );
  }

  Uri _backendUri() {
    return Uri.parse(
      const String.fromEnvironment(
        'DJINN_BACKEND_URL',
        defaultValue: 'http://10.0.2.2:8000',
      ),
    );
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
            knowledgeSyncService: dependencies.knowledgeSyncService,
            apiKeyStore: dependencies.apiKeyStore,
            loadSettings: dependencies.loadSettings,
            saveSettings: dependencies.saveSettings,
            testApiKey: dependencies.testApiKey,
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
    required this.knowledgeSyncService,
    required this.apiKeyStore,
    required this.loadSettings,
    required this.saveSettings,
    required this.testApiKey,
  });

  final LocalChatRepository chatRepository;
  final ChatService chatService;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;
  final KnowledgeSyncService knowledgeSyncService;
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
