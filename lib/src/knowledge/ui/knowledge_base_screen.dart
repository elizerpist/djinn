import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/knowledge_document_repository.dart';
import '../data/knowledge_sync_service.dart';
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
    this.syncService,
    this.pickPdfs,
    this.clock,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final KnowledgeSyncService? syncService;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<KnowledgeDocument> _documents = const [];
  bool _importing = false;
  String? _syncingDocumentId;
  String _backendStatusText = 'Backend nincs ellenorizve';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _refreshBackendStatus();
  }

  Future<void> _loadDocuments() async {
    final documents = await widget.repository.listDocuments();
    if (!mounted) {
      return;
    }
    setState(() => _documents = documents);
  }

  Future<void> _refreshBackendStatus() async {
    final syncService = widget.syncService;
    if (syncService == null) {
      if (mounted) {
        setState(() => _backendStatusText = 'Backend nincs beallitva');
      }
      return;
    }
    final result = await syncService.refresh();
    if (!mounted) {
      return;
    }
    setState(() {
      _backendStatusText = result.backendAvailable
          ? _statusText(result.state.readiness)
          : 'Backend nem erheto el';
    });
    await _loadDocuments();
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
      await _refreshBackendStatus();
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

  Future<void> _syncDocument(KnowledgeDocument document) async {
    final syncService = widget.syncService;
    if (syncService == null) {
      return;
    }
    setState(() => _syncingDocumentId = document.id);
    try {
      await syncService.syncDocument(document.id);
      await _loadDocuments();
      await _refreshBackendStatus();
    } finally {
      if (mounted) {
        setState(() => _syncingDocumentId = null);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _backendStatusText,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ),
          Expanded(
            child: _documents.isEmpty
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
                        trailing: _DocumentAction(
                          document: document,
                          syncing: _syncingDocumentId == document.id,
                          onSync: widget.syncService == null
                              ? null
                              : () => _syncDocument(document),
                        ),
                      );
                    },
                  ),
          ),
        ],
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

  String _statusText(KnowledgeBaseReadiness readiness) {
    return switch (readiness) {
      KnowledgeBaseReadiness.empty => 'Nincs betoltott tudastar',
      KnowledgeBaseReadiness.pendingIngest => 'Feldolgozas folyamatban',
      KnowledgeBaseReadiness.ready => 'Tudastar kesz',
      KnowledgeBaseReadiness.failed => 'Tudastar hiba',
    };
  }
}

class _DocumentAction extends StatelessWidget {
  const _DocumentAction({
    required this.document,
    required this.syncing,
    required this.onSync,
  });

  final KnowledgeDocument document;
  final bool syncing;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    if (syncing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (document.status == KnowledgeDocumentStatus.processed) {
      return const Text('Feldolgozva');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _statusLabel(document.status),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: document.status == KnowledgeDocumentStatus.failed
              ? 'Ujraprobalas'
              : 'Szinkronizalas',
          visualDensity: VisualDensity.compact,
          onPressed: onSync,
          icon: const Icon(Icons.sync),
        ),
      ],
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
