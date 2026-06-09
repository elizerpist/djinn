import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../../settings/models/app_settings.dart';
import '../data/document_processing_service.dart';
import '../data/knowledge_document_repository.dart';
import '../data/pdf_import_service.dart';
import '../data/training_queue.dart';
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
    this.loadSettings,
    this.pickPdfs,
    this.clock,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final DocumentProcessingService? processingService;
  final Future<AppSettings> Function()? loadSettings;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<KnowledgeDocument> _documents = const [];
  bool _importing = false;
  String? _processingDocumentId;
  String? _statusText;
  bool _queueRunning = false;
  final List<String> _selectedDocumentIds = [];
  late final TrainingQueue _trainingQueue = TrainingQueue(
    processDocument: _runProcessDocument,
  );

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
        final duplicate = await widget.repository.findByContentHash(
          imported.contentHash,
        );
        if (duplicate != null) {
          DebugConsole.log(
            '[Knowledge] duplicate skipped hash=${imported.contentHash} filename=${imported.filename}',
          );
          try {
            await widget.importService.deleteImportedFile(imported);
          } catch (error) {
            DebugConsole.log(
              '[Knowledge] duplicate cleanup failed error=$error',
            );
          }
          if (mounted) {
            setState(
              () => _statusText = 'duplikált PDF kihagyva: ${file.filename}',
            );
          }
          continue;
        }
        final document = await widget.repository.addDocument(
          filename: imported.filename,
          localPath: imported.localPath,
          sizeBytes: imported.sizeBytes,
          importedAt: (widget.clock ?? DateTime.now)(),
          contentHash: imported.contentHash,
          ocrStatus: imported.ocrStatus,
        );
        DebugConsole.log(
          '[Knowledge] imported document=${document.id} hash=${imported.contentHash} ocr=${imported.ocrStatus}',
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

  Future<void> _processDocument(String documentId) {
    return _processDocuments([documentId]);
  }

  Future<void> _processSelectedDocuments() async {
    final documentById = {
      for (final document in _documents) document.id: document,
    };
    final selected = _selectedDocumentIds
        .where((documentId) {
          final document = documentById[documentId];
          return document != null &&
              (document.status.canStartTraining || document.status.canRetry);
        })
        .toList(growable: false);
    if (selected.isEmpty) {
      return;
    }
    await _processDocuments(selected);
  }

  Future<void> _processDocuments(List<String> documentIds) async {
    final processingService = widget.processingService;
    if (processingService == null) {
      return;
    }
    final allowed = await _confirmPaidAiProcessing();
    if (!allowed) {
      return;
    }
    if (mounted) {
      setState(() => _queueRunning = true);
    }
    try {
      await _trainingQueue.process(documentIds);
      await _loadDocuments();
    } finally {
      if (mounted) {
        setState(() {
          _queueRunning = false;
          _selectedDocumentIds.removeWhere(documentIds.contains);
        });
      }
    }
  }

  Future<void> _runProcessDocument(String documentId) async {
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

  Future<bool> _confirmPaidAiProcessing() async {
    final loadSettings = widget.loadSettings;
    if (loadSettings == null) {
      return true;
    }
    final settings = await loadSettings();
    if (!settings.allowPaidAi) {
      DebugConsole.log('[Knowledge] sync blocked paid_ai_disabled');
      if (mounted) {
        setState(
          () => _statusText =
              'AI feldolgozás tiltva. Engedélyezd a Beállításokban.',
        );
      }
      return false;
    }
    if (!settings.confirmBeforeAiProcessing || !mounted) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI feldolgozás indítása?'),
        content: const Text(
          'Ez fizetős API hívásokat indíthat extraction és embedding lépésekkel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Indítás'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _toggleRag(String documentId, bool enabled) async {
    await widget.repository.updateRagEnabled(documentId, enabled);
    DebugConsole.log('[Knowledge] rag document=$documentId enabled=$enabled');
    await _loadDocuments();
  }

  Future<void> _editCollection(KnowledgeDocument document) async {
    final collectionName = await showDialog<String>(
      context: context,
      builder: (context) =>
          _CollectionDialog(initialValue: document.collectionName),
    );
    if (collectionName == null) {
      return;
    }
    await widget.repository.updateCollection(document.id, collectionName);
    DebugConsole.log(
      '[Knowledge] collection document=${document.id} name=$collectionName',
    );
    await _loadDocuments();
  }

  void _toggleSelected(String documentId, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedDocumentIds.contains(documentId)) {
          _selectedDocumentIds.add(documentId);
        }
      } else {
        _selectedDocumentIds.remove(documentId);
      }
    });
  }

  void _cancelQueue() {
    _trainingQueue.cancel();
    DebugConsole.log('[Knowledge] training queue cancel requested');
    setState(() => _statusText = 'Queue leállítása folyamatban');
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
          if (_statusText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _statusText!,
                  style: const TextStyle(
                    color: Color(0xFF166534),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_selectedDocumentIds.isNotEmpty || _queueRunning)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedDocumentIds.length} PDF kijelölve',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_queueRunning)
                    Tooltip(
                      message: 'Queue leállítása',
                      child: OutlinedButton.icon(
                        onPressed: _cancelQueue,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    )
                  else
                    Tooltip(
                      message: 'Kijelöltek chunkolása',
                      child: FilledButton.icon(
                        onPressed: widget.processingService == null
                            ? null
                            : _processSelectedDocuments,
                        icon: const Icon(Icons.sync),
                        label: const Text('Chunkolás'),
                      ),
                    ),
                ],
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
                        leading: Tooltip(
                          message: 'PDF kiválasztása: ${document.filename}',
                          child: Checkbox(
                            value: _selectedDocumentIds.contains(document.id),
                            onChanged: _queueRunning
                                ? null
                                : (value) => _toggleSelected(
                                    document.id,
                                    value ?? false,
                                  ),
                          ),
                        ),
                        title: Text(document.filename),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text('${document.sizeBytes} byte'),
                            _Badge(text: _documentStatusLabel(document.status)),
                            _Badge(text: document.ocrStatus),
                            ActionChip(
                              tooltip:
                                  'Gyűjtemény módosítása: ${document.filename}',
                              label: Text(document.collectionName),
                              onPressed: _queueRunning
                                  ? null
                                  : () => _editCollection(document),
                            ),
                            _Badge(
                              text: document.ragEnabled ? 'RAG be' : 'RAG ki',
                            ),
                          ],
                        ),
                        trailing: _DocumentAction(
                          document: document,
                          processing: _processingDocumentId == document.id,
                          onToggleRag: (value) =>
                              _toggleRag(document.id, value),
                          onProcess:
                              widget.processingService != null &&
                                  _processingDocumentId == null &&
                                  (document.status.canStartTraining ||
                                      document.status.canRetry)
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
    required this.onToggleRag,
    required this.onProcess,
  });

  final KnowledgeDocument document;
  final bool processing;
  final ValueChanged<bool> onToggleRag;
  final VoidCallback? onProcess;

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: document.ragEnabled, onChanged: null),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }
    final label = _documentStatusLabel(document.status);
    if (onProcess == null) {
      return Switch(value: document.ragEnabled, onChanged: onToggleRag);
    }
    if (document.status.canStartTraining) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: document.ragEnabled, onChanged: onToggleRag),
          IconButton(
            tooltip: 'Chunkolás indítása',
            visualDensity: VisualDensity.compact,
            onPressed: onProcess,
            icon: const Icon(Icons.sync),
          ),
        ],
      );
    }
    if (!document.status.canRetry) {
      return Switch(value: document.ragEnabled, onChanged: onToggleRag);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: document.ragEnabled, onChanged: onToggleRag),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        IconButton(
          tooltip: document.status.canRetry
              ? 'Újrapróbálás'
              : 'Chunkolás indítása',
          visualDensity: VisualDensity.compact,
          onPressed: onProcess,
          icon: Icon(document.status.canRetry ? Icons.refresh : Icons.sync),
        ),
      ],
    );
  }
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gyűjtemény módosítása'),
      content: TextField(
        key: const ValueKey('collection-field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Gyűjtemény'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Mentés'),
        ),
      ],
    );
  }
}

String _documentStatusLabel(KnowledgeDocumentStatus status) {
  return switch (status) {
    KnowledgeDocumentStatus.imported ||
    KnowledgeDocumentStatus.pendingIngest => 'Feldolgozásra vár',
    KnowledgeDocumentStatus.blockedMissingApiKey =>
      'OpenAI API kulcs szükséges',
    KnowledgeDocumentStatus.blockedPaidAi => 'AI költséggate tiltja',
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

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF374151)),
      ),
    );
  }
}
