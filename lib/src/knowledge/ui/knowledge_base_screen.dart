import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    this.pickPdfs,
    this.clock,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<KnowledgeDocument> _documents = const [];
  bool _importing = false;

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
        await widget.repository.addDocument(
          filename: imported.filename,
          localPath: imported.localPath,
          sizeBytes: imported.sizeBytes,
          importedAt: (widget.clock ?? DateTime.now)(),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tudastar'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _documents.isEmpty
          ? const Center(
              child: Text(
                'Nincs importalt PDF',
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
                  trailing: Text(_statusLabel(document.status)),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'PDF hozzaadasa',
        onPressed: _importing ? null : _importPdfs,
        child: _importing
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.upload_file),
      ),
    );
  }

  String _statusLabel(KnowledgeDocumentStatus status) {
    return switch (status) {
      KnowledgeDocumentStatus.imported => 'Importalva',
      KnowledgeDocumentStatus.pendingIngest => 'Feldolgozasra var',
      KnowledgeDocumentStatus.uploading => 'Feltoltes',
      KnowledgeDocumentStatus.processed => 'Feldolgozva',
      KnowledgeDocumentStatus.failed => 'Hiba',
    };
  }
}
