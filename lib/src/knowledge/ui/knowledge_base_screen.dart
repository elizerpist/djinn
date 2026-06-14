import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../data/document_processing_service.dart';
import '../data/knowledge_document_repository.dart';
import '../data/local_document_processing_service.dart';
import '../data/knowledge_pack_share_service.dart';
import '../data/knowledge_pack_service.dart';
import '../data/pdf_import_service.dart';
import '../models/knowledge_document.dart';
import '../models/knowledge_folder.dart';
import '../models/knowledge_pack.dart';
import 'extracted_knowledge_screen.dart';
import 'knowledge_document_row.dart';
import 'knowledge_header.dart';
import 'manual_chunk_editor_screen.dart';
import 'pdf_viewer_screen.dart';

typedef PickPdfs = Future<List<PickedPdfFile>> Function();
typedef ExportKnowledgePackForTest =
    Future<String?> Function(KnowledgePack pack);
typedef ShareKnowledgePackForTest =
    Future<String?> Function(KnowledgePack pack);
typedef ImportKnowledgePackForTest = Future<KnowledgePack?> Function();
typedef ReadDocumentBytesForTest =
    Future<List<int>> Function(KnowledgeDocument document);
typedef ChooseDuplicatePackImportForTest =
    Future<KnowledgePackDuplicateChoice> Function(
      KnowledgeDocument existing,
      KnowledgePackDocument incoming,
    );

enum KnowledgePackDuplicateChoice { updateExisting, createDuplicate, cancel }

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
    this.localProcessingService,
    this.packService = const KnowledgePackService(),
    this.pickPdfs,
    this.clock,
    this.onOpenDocumentForTest,
    this.exportKnowledgePackForTest,
    this.shareKnowledgePackForTest,
    this.importKnowledgePackForTest,
    this.readDocumentBytesForTest,
    this.chooseDuplicatePackImportForTest,
  });

  final KnowledgeDocumentRepository repository;
  final PdfImportService importService;
  final DocumentProcessingService? processingService;
  final LocalDocumentProcessingService? localProcessingService;
  final KnowledgePackService packService;
  final PickPdfs? pickPdfs;
  final DateTime Function()? clock;
  final void Function(KnowledgeDocument document)? onOpenDocumentForTest;
  final ExportKnowledgePackForTest? exportKnowledgePackForTest;
  final ShareKnowledgePackForTest? shareKnowledgePackForTest;
  final ImportKnowledgePackForTest? importKnowledgePackForTest;
  final ReadDocumentBytesForTest? readDocumentBytesForTest;
  final ChooseDuplicatePackImportForTest? chooseDuplicatePackImportForTest;

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
  Map<String, ProcessingProgress> _processingProgressByDocumentId = const {};

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
      return widget.importService.copyDocumentFromPath(path);
    }
    final bytes = file.bytes;
    if (bytes != null) {
      return widget.importService.copyDocumentBytes(
        filename: file.filename,
        bytes: bytes,
      );
    }
    return null;
  }

  Future<List<PickedPdfFile>> _pickPdfsFromDevice() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png'],
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

  Future<void> _processDocument(KnowledgeDocument document) async {
    final processingService = widget.processingService;
    if (processingService == null) {
      return;
    }
    final documentId = document.id;
    setState(() {
      _processingDocumentId = documentId;
      _processingProgressByDocumentId = {
        ..._processingProgressByDocumentId,
        documentId: ProcessingProgress(
          documentId: documentId,
          phase: ProcessingPhase.extracting,
          label: 'Kinyerés...',
        ),
      };
    });
    try {
      await processingService.processDocument(
        documentId,
        forceReprocess: document.status.isReady,
        onProgress: _handleProcessingProgress,
      );
      await _loadDocuments();
    } finally {
      if (mounted) {
        setState(() {
          _processingDocumentId = null;
          final next = Map<String, ProcessingProgress>.of(
            _processingProgressByDocumentId,
          );
          next.remove(documentId);
          _processingProgressByDocumentId = next;
        });
      }
    }
  }


  Future<void> _processDocumentLocally(KnowledgeDocument document) async {
    final processingService = widget.localProcessingService;
    if (processingService == null) {
      return;
    }
    final documentId = document.id;
    setState(() {
      _processingDocumentId = documentId;
      _processingProgressByDocumentId = {
        ..._processingProgressByDocumentId,
        documentId: ProcessingProgress(
          documentId: documentId,
          phase: ProcessingPhase.extracting,
          label: 'Lokális OCR...',
        ),
      };
    });
    try {
      await processingService.processDocument(
        documentId,
        forceReprocess: document.status.isReady ||
            document.status == KnowledgeDocumentStatus.needsReview,
        onProgress: _handleProcessingProgress,
      );
      await _loadDocuments();
    } finally {
      if (mounted) {
        setState(() {
          _processingDocumentId = null;
          final next = Map<String, ProcessingProgress>.of(
            _processingProgressByDocumentId,
          );
          next.remove(documentId);
          _processingProgressByDocumentId = next;
        });
      }
    }
  }

  void _handleProcessingProgress(ProcessingProgress progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _processingProgressByDocumentId = {
        ..._processingProgressByDocumentId,
        progress.documentId: progress,
      };
    });
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

  Future<void> _processSelectedDocumentsWithAi() async {
    final selectedIds = Set<String>.of(_selectedDocumentIds);
    final documentsToProcess = _documents.where(
      (document) =>
          selectedIds.contains(document.id) &&
          _canProcessManually(document.status),
    );
    for (final document in documentsToProcess) {
      await _processDocument(document);
    }
    if (mounted) {
      _exitSelection();
    }
  }

  Future<void> _processSelectedDocumentsLocally() async {
    final selectedIds = Set<String>.of(_selectedDocumentIds);
    final documentsToProcess = _documents.where(
      (document) =>
          selectedIds.contains(document.id) &&
          _canProcessManually(document.status),
    );
    for (final document in documentsToProcess) {
      await _processDocumentLocally(document);
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

  Future<void> _deleteSelectedDocuments() async {
    final selectedIds = _selectedDocumentIds.toList(growable: false);
    if (selectedIds.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dokumentum törlése'),
          content: Text(
            selectedIds.length == 1
                ? 'A kijelölt dokumentum és a hozzá tartozó chunkok törlődnek.'
                : '${selectedIds.length} dokumentum és a hozzájuk tartozó chunkok törlődnek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Törlés'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await widget.repository.deleteDocuments(selectedIds);
    _exitSelection();
    await _loadDocuments();
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
        PopupMenuItem<String>(value: 'sort', child: const Text('Rendezés')),
        const PopupMenuItem<String>(
          value: 'new_folder',
          child: Text('Új mappa'),
        ),
        const PopupMenuItem<String>(
          value: 'import_chunks',
          child: Text('Chunk csomag import'),
        ),
        const PopupMenuItem<String>(
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
    } else if (selected == 'import_chunks') {
      await _importKnowledgePack();
    } else if (selected == 'export_knowledge') {
      await _exportKnowledgePack(_visibleDocuments);
    }
  }

  Future<void> _showSelectionMenu() async {
    final selectedDocuments = _selectedDocuments;
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, kToolbarHeight, 12, 0),
      items: [
        if (widget.processingService != null)
          PopupMenuItem<String>(
            value: 'ai_chunk',
            child: Text(_aiChunkActionLabel(selectedDocuments)),
          ),
        if (widget.localProcessingService != null)
          PopupMenuItem<String>(
            value: 'local_chunk',
            child: Text(_localChunkActionLabel()),
          ),
        const PopupMenuItem<String>(
          value: 'move',
          child: Text('Mozgatás mappába'),
        ),
        if (selectedDocuments.length == 1) ...[
          const PopupMenuItem<String>(
            value: 'manual_chunk',
            child: Text('Kézi chunkolás'),
          ),
          const PopupMenuItem<String>(
            value: 'inspect_extracted',
            child: Text('Kinyert chunkok'),
          ),
        ],
        const PopupMenuItem<String>(
          value: 'export_chunks',
          child: Text('Chunk+PDF csomag export'),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    if (selected == 'ai_chunk') {
      await _processSelectedDocumentsWithAi();
    } else if (selected == 'local_chunk') {
      await _processSelectedDocumentsLocally();
    } else if (selected == 'move') {
      await _moveSelectedDocuments();
    } else if (selected == 'manual_chunk') {
      await _openManualChunkEditor(selectedDocuments.single);
    } else if (selected == 'inspect_extracted') {
      _openExtractedKnowledge(selectedDocuments.single);
    } else if (selected == 'export_chunks') {
      await _exportKnowledgePack(_selectedDocuments);
    }
  }


  void _openExtractedKnowledge(KnowledgeDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExtractedKnowledgeScreen(
          repository: widget.repository,
          document: document,
        ),
      ),
    );
  }

  Future<void> _openManualChunkEditor(KnowledgeDocument document) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ManualChunkEditorScreen(
          repository: widget.repository,
          document: document,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (saved == true) {
      _exitSelection();
      await _loadDocuments();
    }
  }

  String _aiChunkActionLabel(List<KnowledgeDocument> selectedDocuments) {
    if (selectedDocuments.any((document) => document.status.isReady)) {
      return 'AI újrachunkolás';
    }
    if (selectedDocuments.any((document) => document.status.canRetry)) {
      return 'AI újrapróbálás';
    }
    return 'AI chunkolás';
  }

  String _localChunkActionLabel() {
    return 'Lokális chunkolás';
  }

  Future<void> _exportKnowledgePack(List<KnowledgeDocument> documents) async {
    if (documents.isEmpty) {
      DebugConsole.log('[Knowledge] pack export skipped empty_selection');
      return;
    }
    try {
      final pack = await _buildKnowledgePack(documents);
      final callback = widget.exportKnowledgePackForTest;
      final path = callback != null
          ? await callback(pack)
          : await _saveKnowledgePackFile(pack, documents);
      if (path != null) {
        DebugConsole.log(
          '[Knowledge] pack export documents=${pack.documents.length} path=$path',
        );
      }
    } catch (error) {
      DebugConsole.log('[Knowledge] pack export failed error=$error');
    }
  }

  Future<void> _shareKnowledgePack(List<KnowledgeDocument> documents) async {
    if (documents.isEmpty) {
      DebugConsole.log('[Knowledge] pack share skipped empty_selection');
      return;
    }
    try {
      final pack = await _buildKnowledgePack(documents);
      final callback = widget.shareKnowledgePackForTest;
      final path = callback != null
          ? await callback(pack)
          : (await KnowledgePackShareService(
              packService: widget.packService,
            ).share(pack, filename: _knowledgePackFilename(documents))).path;
      if (path != null) {
        DebugConsole.log(
          '[Knowledge] pack share documents=${pack.documents.length} path=$path',
        );
      }
    } catch (error) {
      DebugConsole.log('[Knowledge] pack share failed error=$error');
    }
  }

  Future<KnowledgePack> _buildKnowledgePack(
    List<KnowledgeDocument> documents,
  ) async {
    final packDocuments = <KnowledgePackDocument>[];
    for (final document in documents) {
      final reader = widget.readDocumentBytesForTest;
      final pdfBytes = reader != null
          ? await reader(document)
          : await File(document.localPath).readAsBytes();
      final chunkPackage = await widget.repository.exportChunkPackage(
        document.id,
      );
      packDocuments.add(
        KnowledgePackDocument(
          filename: document.filename,
          documentHash: document.sha256 ?? chunkPackage.documentHash,
          pdfBytes: pdfBytes,
          chunkPackage: chunkPackage,
        ),
      );
    }
    return KnowledgePack(schemaVersion: 1, documents: packDocuments);
  }

  Future<String?> _saveKnowledgePackFile(
    KnowledgePack pack,
    List<KnowledgeDocument> documents,
  ) async {
    final bytes = Uint8List.fromList(widget.packService.encode(pack));
    final filename = _knowledgePackFilename(documents);
    return FilePicker.saveFile(
      dialogTitle: 'Tudástár export',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['djinnpack'],
      bytes: bytes,
    );
  }

  String _knowledgePackFilename(List<KnowledgeDocument> documents) {
    return documents.length == 1
        ? '${_safeBaseName(documents.single.filename)}.djinnpack'
        : 'djinn-tudastar-${DateTime.now().millisecondsSinceEpoch}.djinnpack';
  }

  Future<void> _importKnowledgePack() async {
    try {
      final callback = widget.importKnowledgePackForTest;
      final pack = callback != null ? await callback() : await _pickPackFile();
      if (pack == null) {
        return;
      }
      var importedCount = 0;
      for (final document in pack.documents) {
        final imported = await _importPackDocument(document);
        if (imported) {
          importedCount += 1;
        }
      }
      DebugConsole.log('[Knowledge] pack import documents=$importedCount');
      await _loadDocuments();
    } catch (error) {
      DebugConsole.log('[Knowledge] pack import failed error=$error');
    }
  }

  Future<KnowledgePack?> _pickPackFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['djinnpack'],
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return null;
    }
    final bytes = file.bytes ?? await File(file.path ?? '').readAsBytes();
    return widget.packService.decode(bytes);
  }

  Future<bool> _importPackDocument(KnowledgePackDocument incoming) async {
    final existing = await _findDocumentByHash(incoming.documentHash);
    if (existing != null) {
      final choice = await _chooseDuplicatePackImport(existing, incoming);
      if (choice == KnowledgePackDuplicateChoice.cancel) {
        return false;
      }
      if (choice == KnowledgePackDuplicateChoice.updateExisting) {
        await widget.repository.importChunkPackage(
          existing.id,
          incoming.chunkPackage,
        );
        return true;
      }
    }

    final imported = await widget.importService.copyDocumentBytes(
      filename: incoming.filename,
      bytes: incoming.pdfBytes,
    );
    final document = await widget.repository.addDocument(
      filename: imported.filename,
      localPath: imported.localPath,
      sizeBytes: imported.sizeBytes,
      importedAt: (widget.clock ?? DateTime.now)(),
      sha256: imported.sha256,
      folderId: _activeFolderId,
    );
    await widget.repository.importChunkPackage(
      document.id,
      incoming.chunkPackage,
    );
    return true;
  }

  Future<KnowledgeDocument?> _findDocumentByHash(String hash) async {
    final documents = await widget.repository.listDocuments();
    for (final document in documents) {
      if (document.sha256 == hash) {
        return document;
      }
    }
    return null;
  }

  Future<KnowledgePackDuplicateChoice> _chooseDuplicatePackImport(
    KnowledgeDocument existing,
    KnowledgePackDocument incoming,
  ) async {
    final callback = widget.chooseDuplicatePackImportForTest;
    if (callback != null) {
      return callback(existing, incoming);
    }
    final choice = await showDialog<KnowledgePackDuplicateChoice>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dokumentum már létezik'),
          content: Text(
            'Ez a chunk csomag ugyanahhoz a dokumentumhoz tartozik: ${existing.filename}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(KnowledgePackDuplicateChoice.cancel),
              child: const Text('Mégse'),
            ),
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(KnowledgePackDuplicateChoice.updateExisting),
              child: const Text('Meglévő frissítése'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(KnowledgePackDuplicateChoice.createDuplicate),
              child: const Text('Duplikátum létrehozása'),
            ),
          ],
        );
      },
    );
    return choice ?? KnowledgePackDuplicateChoice.cancel;
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
        selectionSummary: '${visibleDocuments.length} dokumentum ebben a nézetben',
        onExitSelection: _exitSelection,
        onShareSelected: () => _shareKnowledgePack(_selectedDocuments),
        onDeleteSelected: _deleteSelectedDocuments,
        onGeneralMenu: _showGeneralMenu,
        onSelectionMenu: _showSelectionMenu,
      ),
      body: Column(
        children: [
          _FolderPillBar(
            folders: _folders,
            activeFolderId: _activeFolderId,
            onSelected: _setActiveFolder,
          ),
          Expanded(
            child: !hasAnyKnowledge
                ? const Center(
                    child: Text(
                      'Nincs importált dokumentum',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : visibleDocuments.isEmpty
                ? Center(
                    child: Text(
                      _activeFolderId == null
                          ? 'Nincs importált dokumentum'
                          : 'Nincs dokumentum ebben a mappában',
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
                        progressLabel:
                            _processingProgressByDocumentId[document.id]?.label,
                        progressValue: _progressValue(
                          _processingProgressByDocumentId[document.id],
                        ),
                        onTap: () => _openDocument(document),
                        onLongPress: () => _enterSelection(document.id),
                        onSelectionChanged: (value) =>
                            _selectDocument(document.id, value),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'PDF/PNG hozzáadása',
        onPressed: _importing ? null : _importPdfs,
        child: _importing
            ? const CircularProgressIndicator(strokeWidth: 2)
            : const Icon(Icons.upload_file),
      ),
    );
  }

  bool _canProcessManually(KnowledgeDocumentStatus status) {
    return _isUnsynced(status) || status.canRetry || status.isReady;
  }

  bool _isUnsynced(KnowledgeDocumentStatus status) {
    return status == KnowledgeDocumentStatus.imported ||
        status == KnowledgeDocumentStatus.pendingIngest;
  }

  double? _progressValue(ProcessingProgress? progress) {
    if (progress == null ||
        progress.total == null ||
        progress.current == null ||
        progress.total == 0) {
      return null;
    }
    return progress.current! / progress.total!;
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
      width: double.infinity,
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
