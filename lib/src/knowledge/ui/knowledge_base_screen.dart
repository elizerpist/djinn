import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/document_processing_service.dart';
import '../data/knowledge_document_repository.dart';
import '../data/pdf_import_service.dart';
import '../models/knowledge_document.dart';
import '../models/knowledge_folder.dart';
import 'knowledge_document_row.dart';
import 'knowledge_header.dart';
import 'pdf_viewer_screen.dart';

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
    this.onOpenDocumentForTest,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final DocumentProcessingService? processingService;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;
  final void Function(KnowledgeDocument document)? onOpenDocumentForTest;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<KnowledgeDocument> _documents = const [];
  List<KnowledgeFolder> _folders = const [];
  Set<String> _selectedDocumentIds = {};
  bool _importing = false;
  String? _processingDocumentId;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final documents = await widget.repository.listDocuments();
    final folders = await widget.repository.listFolders();
    if (!mounted) {
      return;
    }
    setState(() {
      _documents = documents;
      _folders = folders;
      final existingIds = documents.map((document) => document.id).toSet();
      _selectedDocumentIds = _selectedDocumentIds.intersection(existingIds);
    });
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
          sha256: imported.sha256,
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

  void _openDocument(KnowledgeDocument document) {
    final callback = widget.onOpenDocumentForTest;
    if (callback != null) {
      callback(document);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PdfViewerScreen(title: document.filename, path: document.localPath),
      ),
    );
  }

  void _selectDocument(String documentId, bool selected) {
    setState(() {
      final next = Set<String>.of(_selectedDocumentIds);
      if (selected) {
        next.add(documentId);
      } else {
        next.remove(documentId);
      }
      _selectedDocumentIds = next;
    });
  }

  void _enterSelection(String documentId) {
    _selectDocument(documentId, true);
  }

  void _exitSelection() {
    setState(() => _selectedDocumentIds = {});
  }

  Future<void> _syncSelectedDocuments() async {
    final selectedIds = Set<String>.of(_selectedDocumentIds);
    final documentsToProcess = _documents.where(
      (document) =>
          selectedIds.contains(document.id) &&
          _canProcessManually(document.status),
    );
    for (final document in documentsToProcess) {
      await _processDocument(document.id);
    }
    if (mounted) {
      _exitSelection();
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateFolderDialog(),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }
    await widget.repository.createFolder(trimmed);
    await _loadDocuments();
  }

  Future<void> _moveSelectedDocuments() async {
    final selectedIds = _selectedDocumentIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      return;
    }
    await _showMoveDialog(selectedIds);
  }

  Future<void> _moveSingleDocument(KnowledgeDocument document) async {
    await _showMoveDialog([document.id]);
  }

  Future<void> _showMoveDialog(List<String> documentIds) async {
    final folders = await widget.repository.listFolders();
    if (!mounted) {
      return;
    }
    final folderId = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Mozgatás mappába'), dense: true),
              ListTile(
                key: const Key('move-folder-root'),
                leading: const Icon(Icons.home_outlined),
                title: const Text('Tudástár gyökér'),
                onTap: () => Navigator.of(context).pop(''),
              ),
              for (final folder in folders)
                ListTile(
                  key: Key('move-folder-${folder.id}'),
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  onTap: () => Navigator.of(context).pop(folder.id),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || folderId == null) {
      return;
    }
    await widget.repository.moveDocumentsToFolder(
      documentIds,
      folderId.isEmpty ? null : folderId,
    );
    _exitSelection();
    await _loadDocuments();
  }

  Future<void> _showGeneralMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, kToolbarHeight, 12, 0),
      items: [
        const PopupMenuItem(
          value: 'select_all',
          child: Text('Összes kijelölése'),
        ),
        PopupMenuItem<String>(
          enabled: _documents.length > 1,
          value: 'sort',
          child: const Text('Rendezés'),
        ),
        const PopupMenuItem<String>(
          value: 'new_folder',
          child: Text('Új mappa'),
        ),
        const PopupMenuItem(
          enabled: false,
          value: 'import_chunks',
          child: Text('Chunk csomag import'),
        ),
        const PopupMenuItem(
          enabled: false,
          value: 'export_knowledge',
          child: Text('Tudástár export'),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    if (selected == 'select_all') {
      setState(
        () => _selectedDocumentIds = _documents
            .map((document) => document.id)
            .toSet(),
      );
    } else if (selected == 'new_folder') {
      await _createFolder();
    }
  }

  Future<void> _showSelectionMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, kToolbarHeight, 12, 0),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          value: 'rag_on',
          child: Text('RAG bekapcsolása'),
        ),
        const PopupMenuItem<String>(
          value: 'move',
          child: Text('Mozgatás mappába'),
        ),
        const PopupMenuItem(
          enabled: false,
          value: 'export_chunks',
          child: Text('Chunk csomag export'),
        ),
        const PopupMenuItem(
          enabled: false,
          value: 'refresh_embeddings',
          child: Text('Embedding frissítés'),
        ),
        const PopupMenuItem(
          enabled: false,
          value: 'flowchart_review',
          child: Text('Flowchart validálásra'),
        ),
        const PopupMenuItem(
          enabled: false,
          value: 'offline_index',
          child: Text('Offline index frissítés'),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    if (selected == 'move') {
      await _moveSelectedDocuments();
    }
  }

  Future<void> _showDocumentMenu(KnowledgeDocument document) async {
    final canProcess = _canProcessManually(document.status);
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, kToolbarHeight, 12, 0),
      items: [
        PopupMenuItem<String>(
          enabled: canProcess,
          value: 'sync',
          child: const Text('Szinkronizálás'),
        ),
        const PopupMenuItem<String>(
          value: 'move',
          child: Text('Mozgatás mappába'),
        ),
        const PopupMenuItem<String>(
          enabled: false,
          value: 'delete',
          child: Text('Törlés'),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    if (selected == 'sync' && _canProcessManually(document.status)) {
      await _processDocument(document.id);
    } else if (selected == 'move') {
      await _moveSingleDocument(document);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionCount = _selectedDocumentIds.length;
    final selectionMode = selectionCount > 0;
    return Scaffold(
      appBar: KnowledgeHeader(
        selectionCount: selectionCount,
        selectionSummary: '${_documents.length} PDF a tudástárban',
        onExitSelection: _exitSelection,
        onSendSelected: widget.processingService == null
            ? () {}
            : _syncSelectedDocuments,
        onDeleteSelected: null,
        onGeneralMenu: _showGeneralMenu,
        onSelectionMenu: _showSelectionMenu,
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
            child: _documents.isEmpty && _folders.isEmpty
                ? const Center(
                    child: Text(
                      'Nincs importált PDF',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: _folders.length + _documents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index < _folders.length) {
                        final folder = _folders[index];
                        return _KnowledgeFolderRow(folder: folder);
                      }
                      final documentIndex = index - _folders.length;
                      final document = _documents[documentIndex];
                      final selected = _selectedDocumentIds.contains(
                        document.id,
                      );
                      return KnowledgeDocumentRow(
                        document: document,
                        selectionMode: selectionMode,
                        selected: selected,
                        processing: _processingDocumentId == document.id,
                        onTap: () => _openDocument(document),
                        onLongPress: () => _enterSelection(document.id),
                        onSelectionChanged: (value) =>
                            _selectDocument(document.id, value),
                        onProcess:
                            _canProcessManually(document.status) &&
                                widget.processingService != null
                            ? () => _processDocument(document.id)
                            : null,
                        processTooltip: _isUnsynced(document.status)
                            ? 'Szinkronizálás'
                            : 'Újrapróbálás',
                        onMenu: () => _showDocumentMenu(document),
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

  bool _canProcessManually(KnowledgeDocumentStatus status) {
    return _isUnsynced(status) || status.canRetry;
  }

  bool _isUnsynced(KnowledgeDocumentStatus status) {
    return status == KnowledgeDocumentStatus.imported ||
        status == KnowledgeDocumentStatus.pendingIngest;
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Új mappa'),
      content: TextField(
        key: const Key('folder-name-field'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Mappa neve',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Létrehozás'),
        ),
      ],
    );
  }
}

class _KnowledgeFolderRow extends StatelessWidget {
  const _KnowledgeFolderRow({required this.folder});

  final KnowledgeFolder folder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.folder, color: Color(0xFF155EEF)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
