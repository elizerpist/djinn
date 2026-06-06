import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/document_processing_service.dart';
import '../data/knowledge_document_repository.dart';
import '../data/pdf_import_service.dart';
import '../models/knowledge_document.dart';

typedef PickPdfs = Future<List<PickedPdfFile>> Function();

class PickedPdfFile {
  const PickedPdfFile({required this.filename, this.path, this.bytes});

  final String filename;
  final String? path;
  final List<int>? bytes;
}

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({
    super.key,
    required this.repository,
    required this.importService,
    this.processingService,
    this.pickPdfs,
    this.clock,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final DocumentProcessingService? processingService;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<KnowledgeDocument> _documents = const [];
  bool _importing = false;
  String? _processingDocumentId;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final documents = await widget.repository.listDocuments();
    if (!mounted) {
      return;
    }
    setState(() => _documents = documents);
  }

  Future<void> _importPdfs() async {
    setState(() => _importing = true);
    try {
      final picked = await (widget.pickPdfs ?? _pickPdfsFromDevice)();
      for (final file in picked) {
        final imported = await _copyPickedFile(file);
        if (imported == null) {
          continue;
        }
        final document = await widget.repository.addDocument(
          filename: imported.filename,
          localPath: imported.localPath,
          sizeBytes: imported.sizeBytes,
          importedAt: (widget.clock ?? DateTime.now)(),
        );
        if (widget.processingService != null) {
          await _processDocument(document.id);
        }
      }
      await _loadDocuments();
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<PdfImportResult?> _copyPickedFile(PickedPdfFile file) async {
    final path = file.path;
    if (path != null) {
      return widget.importService.copyPdfFromPath(path);
    }
    final bytes = file.bytes;
    if (bytes != null) {
      return widget.importService.copyPdfBytes(
        filename: file.filename,
        bytes: bytes,
      );
    }
    return null;
  }

  Future<List<PickedPdfFile>> _pickPdfsFromDevice() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null) {
      return const [];
    }
    return result.files
        .map(
          (file) => PickedPdfFile(
            filename: file.name,
            path: file.path,
            bytes: file.bytes,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _processDocument(String documentId) async {
    final processingService = widget.processingService;
    if (processingService == null) {
      return;
    }
    setState(() => _processingDocumentId = documentId);
    try {
      await processingService.processDocument(documentId);
      await _loadDocuments();
    } finally {
      if (mounted) {
        setState(() => _processingDocumentId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tudastar'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Helyi ObjectBox tudástár',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: _documents.isEmpty
                ? const Center(
                    child: Text(
                      'Nincs importált PDF',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: _documents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final document = _documents[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(document.filename),
                        subtitle: Text('${document.sizeBytes} byte'),
                        trailing: _DocumentAction(
                          document: document,
                          processing: _processingDocumentId == document.id,
                          onRetry:
                              document.status.canRetry &&
                                  widget.processingService != null
                              ? () => _processDocument(document.id)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'PDF hozzáadása',
        onPressed: _importing ? null : _importPdfs,
        child: _importing
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.upload_file),
      ),
    );
  }
}

class _DocumentAction extends StatelessWidget {
  const _DocumentAction({
    required this.document,
    required this.processing,
    required this.onRetry,
  });

  final KnowledgeDocument document;
  final bool processing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final label = _statusLabel(document.status);
    if (onRetry == null) {
      return Text(label, style: const TextStyle(fontSize: 12));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Újrapróbálás',
          visualDensity: VisualDensity.compact,
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  String _statusLabel(KnowledgeDocumentStatus status) {
    return switch (status) {
      KnowledgeDocumentStatus.imported ||
      KnowledgeDocumentStatus.pendingIngest => 'Feldolgozásra vár',
      KnowledgeDocumentStatus.blockedMissingApiKey =>
        'OpenAI API kulcs szükséges',
      KnowledgeDocumentStatus.blockedOffline => 'Offline állapot',
      KnowledgeDocumentStatus.uploading ||
      KnowledgeDocumentStatus.processing => 'Feldolgozás folyamatban',
      KnowledgeDocumentStatus.embedded => 'Embedding kész',
      KnowledgeDocumentStatus.ready ||
      KnowledgeDocumentStatus.processed => 'Kész',
      KnowledgeDocumentStatus.needsReview => 'Validáció szükséges',
      KnowledgeDocumentStatus.failed => 'Hiba',
    };
  }
}
