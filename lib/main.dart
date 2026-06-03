import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/chat/data/local_chat_repository.dart';
import 'src/chat/ui/main_screen.dart';
import 'src/core/storage/json_file_store.dart';
import 'src/knowledge/data/knowledge_document_repository.dart';
import 'src/knowledge/data/pdf_import_service.dart';

void main() {
  runApp(const DjinnApp());
}

class DjinnApp extends StatefulWidget {
  const DjinnApp({
    super.key,
    this.chatRepository,
    this.knowledgeRepository,
    this.pdfImportService,
  });

  final LocalChatRepository? chatRepository;
  final KnowledgeDocumentRepository? knowledgeRepository;
  final PdfImportService? pdfImportService;

  @override
  State<DjinnApp> createState() => _DjinnAppState();
}

class _DjinnAppState extends State<DjinnApp> {
  late final Future<_AppDependencies> _dependencies = _loadDependencies();

  Future<_AppDependencies> _loadDependencies() async {
    if (widget.chatRepository != null &&
        widget.knowledgeRepository != null &&
        widget.pdfImportService != null) {
      return _AppDependencies(
        chatRepository: widget.chatRepository!,
        knowledgeRepository: widget.knowledgeRepository!,
        pdfImportService: widget.pdfImportService!,
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final chatRepository =
        widget.chatRepository ??
        LocalChatRepository(
          store: JsonFileStore(File('${directory.path}/chat.json')),
        );
    await chatRepository.load();

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

    return _AppDependencies(
      chatRepository: chatRepository,
      knowledgeRepository: knowledgeRepository,
      pdfImportService: pdfImportService,
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
            knowledgeRepository: dependencies.knowledgeRepository,
            pdfImportService: dependencies.pdfImportService,
          );
        },
      ),
    );
  }
}

class _AppDependencies {
  const _AppDependencies({
    required this.chatRepository,
    required this.knowledgeRepository,
    required this.pdfImportService,
  });

  final LocalChatRepository chatRepository;
  final KnowledgeDocumentRepository knowledgeRepository;
  final PdfImportService pdfImportService;
}

class MyApp extends DjinnApp {
  const MyApp({super.key});
}
