import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../data/document_processing_service.dart';
import '../data/knowledge_document_repository.dart';
import '../data/pdf_import_service.dart';
import '../models/chunk_package.dart';
import '../models/knowledge_document.dart';
import '../models/knowledge_folder.dart';
import 'knowledge_document_row.dart';
import 'knowledge_header.dart';
import 'pdf_viewer_screen.dart';

typedef PickPdfs = Future<List<PickedPdfFile>> Function();
typedef ExportChunkPackageForTest =
    Future<String?> Function(KnowledgeDocument document, ChunkPackage package);
typedef ImportChunkPackageForTest =
    Future<ChunkPackage?> Function(KnowledgeDocument document);

enum _KnowledgeSortMode {
  newestFirst,
  oldestFirst,
  largestFirst,
  smallestFirst,
  nameAsc,
  nameDesc,
}

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
    this.exportChunkPackageForTest,
    this.importChunkPackageForTest,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final DocumentProcessingService? processingService;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;
  final void Function(KnowledgeDocument document)? onOpenDocumentForTest;
  final ExportChunkPackageForTest? exportChunkPackageForTest;
  final ImportChunkPackageForTest? importChunkPackageForTest;

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<KnowledgeDocument> _documents = const [];
  List<KnowledgeFolder> _folders = const [];
  Set<String> _selectedDocumentIds = {};
  String? _activeFolderId;
  _KnowledgeSortMode _sortMode = _KnowledgeSortMode.newestFirst;
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
      if (_activeFolderId != null &&
          !folders.any((folder) => folder.id == _activeFolderId)) {
        _activeFolderId = null;
      }
      final existingIds = documents.map((document) => document.id).toSet();
      _selectedDocumentIds = _selectedDocumentIds.intersection(existingIds);
    });
  }

  List<KnowledgeDocument> get _visibleDocuments {
    final folderId = _activeFolderId;
    final documents =
        (folderId == null
                ? _documents
                : _documents.where((document) => document.folderId == folderId))
            .toList(growable: false);
    documents.sort(_compareDocuments);
    return documents;
  }

  int _compareDocuments(KnowledgeDocument a, KnowledgeDocument b) {
    return switch (_sortMode) {
      _KnowledgeSortMode.newestFirst => b.importedAt.compareTo(a.importedAt),
      _KnowledgeSortMode.oldestFirst => a.importedAt.compareTo(b.importedAt),
      _KnowledgeSortMode.largestFirst => b.sizeBytes.compareTo(a.sizeBytes),
      _KnowledgeSortMode.smallestFirst => a.sizeBytes.compareTo(b.sizeBytes),
      _KnowledgeSortMode.nameAsc => a.filename.toLowerCase().compareTo(
        b.filename.toLowerCase(),
      ),
      _KnowledgeSortMode.nameDesc => b.filename.toLowerCase().compareTo(
        a.filename.toLowerCase(),
      ),
    };
  }

  void _setActiveFolder(String? folderId) {
    setState(() {
      _activeFolderId = folderId;
      final visibleIds = _visibleDocuments
          .map((document) => document.id)
          .toSet();
      _selectedDocumentIds = _selectedDocumentIds.intersection(visibleIds);
    });
  }

  List<KnowledgeDocument> get _selectedDocuments {
    final selectedIds = _selectedDocumentIds;
    return _visibleDocuments
        .where((document) => selectedIds.contains(document.id))
        .toList(growable: false);
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
          folderId: _activeFolderId,
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
        () => _selectedDocumentIds = _visibleDocuments
            .map((document) => document.id)
            .toSet(),
      );
    } else if (selected == 'new_folder') {
      await _createFolder();
    } else if (selected == 'sort') {
      await _showSortSheet();
    }
  }

  Future<void> _showSelectionMenu() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, kToolbarHeight, 12, 0),
      items: [
        PopupMenuItem<String>(
          enabled: widget.processingService != null,
          value: 'sync',
          child: const Text('Szinkronizálás'),
        ),
        const PopupMenuItem<String>(
          value: 'move',
          child: Text('Mozgatás mappába'),
        ),
        const PopupMenuItem<String>(
          value: 'export_chunks',
          child: Text('Chunk csomag export'),
        ),
        const PopupMenuItem<String>(
          value: 'refresh_embeddings',
          enabled: false,
          child: Text('Embedding frissítés'),
        ),
        const PopupMenuItem<String>(
          value: 'import_chunks',
          child: Text('Chunk csomag import'),
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
    if (selected == 'sync') {
      await _syncSelectedDocuments();
    } else if (selected == 'move') {
      await _moveSelectedDocuments();
    } else if (selected == 'export_chunks') {
      await _exportSelectedChunkPackages();
    } else if (selected == 'import_chunks') {
      await _importSelectedChunkPackages();
    }
  }

  Future<void> _exportSelectedChunkPackages() async {
    final selectedDocuments = _selectedDocuments;
    for (final document in selectedDocuments) {
      try {
        final package = await widget.repository.exportChunkPackage(document.id);
        final callback = widget.exportChunkPackageForTest;
        final path = callback != null
            ? await callback(document, package)
            : await _saveChunkPackageFile(document, package);
        if (path != null) {
          DebugConsole.log(
            '[Knowledge] chunk export document=${document.id} path=$path chunks=${package.chunks.length}',
          );
        }
      } catch (error) {
        DebugConsole.log(
          '[Knowledge] chunk export failed document=${document.id} error=$error',
        );
      }
    }
  }

  Future<void> _importSelectedChunkPackages() async {
    final selectedDocuments = _selectedDocuments;
    for (final document in selectedDocuments) {
      try {
        final callback = widget.importChunkPackageForTest;
        final package = callback != null
            ? await callback(document)
            : await _pickChunkPackageFile();
        if (package == null) {
          continue;
        }
        await widget.repository.importChunkPackage(document.id, package);
        DebugConsole.log(
          '[Knowledge] chunk import document=${document.id} chunks=${package.chunks.length}',
        );
      } catch (error) {
        DebugConsole.log(
          '[Knowledge] chunk import failed document=${document.id} error=$error',
        );
      }
    }
    _exitSelection();
    await _loadDocuments();
  }

  Future<String?> _saveChunkPackageFile(
    KnowledgeDocument document,
    ChunkPackage package,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(package.toJson())));
    final path = await FilePicker.saveFile(
      dialogTitle: 'Chunk csomag export',
      fileName: '${_safeBaseName(document.filename)}.djinn-chunks.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) {
      return null;
    }
    final file = File(path);
    if (path.startsWith('/') && !await file.exists()) {
      await file.writeAsBytes(bytes);
    }
    return path;
  }

  Future<ChunkPackage?> _pickChunkPackageFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return null;
    }
    final bytes = file.bytes;
    final text = bytes != null
        ? utf8.decode(bytes)
        : await File(file.path ?? '').readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Chunk package root must be an object.');
    }
    return ChunkPackage.fromJson(Map<String, Object?>.from(decoded));
  }

  String _safeBaseName(String filename) {
    final base = filename.trim().replaceAll(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );
    final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'document' : safe;
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<_KnowledgeSortMode>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Text(
                  'Rendezés',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              RadioGroup<_KnowledgeSortMode>(
                groupValue: _sortMode,
                onChanged: (value) => Navigator.of(context).pop(value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _KnowledgeSortMode.values)
                      RadioListTile<_KnowledgeSortMode>(
                        key: Key('sort-${option.name}'),
                        title: Text(_sortLabel(option)),
                        value: option,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _sortMode = selected);
  }

  String _sortLabel(_KnowledgeSortMode mode) {
    return switch (mode) {
      _KnowledgeSortMode.newestFirst => 'Legújabb legelöl',
      _KnowledgeSortMode.oldestFirst => 'Legrégebbi legelöl',
      _KnowledgeSortMode.largestFirst => 'A legnagyobb legelöl',
      _KnowledgeSortMode.smallestFirst => 'A legkisebb legelöl',
      _KnowledgeSortMode.nameAsc => 'Név (A→Z)',
      _KnowledgeSortMode.nameDesc => 'Név (Z→A)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectionCount = _selectedDocumentIds.length;
    final selectionMode = selectionCount > 0;
    final visibleDocuments = _visibleDocuments;
    final hasAnyKnowledge = _documents.isNotEmpty || _folders.isNotEmpty;
    return Scaffold(
      appBar: KnowledgeHeader(
        selectionCount: selectionCount,
        selectionSummary: '${visibleDocuments.length} PDF ebben a nézetben',
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
          _FolderPillBar(
            folders: _folders,
            activeFolderId: _activeFolderId,
            onSelected: _setActiveFolder,
          ),
          Expanded(
            child: !hasAnyKnowledge
                ? const Center(
                    child: Text(
                      'Nincs importált PDF',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : visibleDocuments.isEmpty
                ? Center(
                    child: Text(
                      _activeFolderId == null
                          ? 'Nincs importált PDF'
                          : 'Nincs PDF ebben a mappában',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: visibleDocuments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final document = visibleDocuments[index];
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

class _FolderPillBar extends StatelessWidget {
  const _FolderPillBar({
    required this.folders,
    required this.activeFolderId,
    required this.onSelected,
  });

  final List<KnowledgeFolder> folders;
  final String? activeFolderId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: SingleChildScrollView(
        key: const Key('folder-pill-scroll'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            ChoiceChip(
              key: const Key('folder-pill-all'),
              label: const Text('Összes'),
              selected: activeFolderId == null,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => onSelected(null),
            ),
            for (final folder in folders) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                key: Key('folder-pill-${folder.id}'),
                avatar: const Icon(Icons.folder_outlined, size: 18),
                label: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: activeFolderId == folder.id,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onSelected(folder.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
