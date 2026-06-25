import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../ai/ai_client.dart';
import '../../flowchart/models/editable_flowchart.dart';
import '../../core/storage/json_file_store.dart';
import '../../local_store/entities.dart';
import '../../notes/models/note_document.dart';
import '../../openai/openai_client.dart';
import '../models/chunk_package.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/knowledge_document.dart';
import '../models/local_extraction.dart';
import '../models/knowledge_folder.dart';
import 'chunk_package_service.dart';
import 'document_processing_service.dart';

class KnowledgeDocumentRepository implements ProcessingRepository {
  KnowledgeDocumentRepository({
    JsonFileStore? store,
    JsonFileStore? folderStore,
    Uuid? uuid,
  }) : _store = store,
       _folderStore = folderStore ?? _defaultFolderStore(store),
       _uuid = uuid ?? const Uuid();

  final JsonFileStore? _store;
  final JsonFileStore? _folderStore;
  final Uuid _uuid;
  List<KnowledgeDocument> _documents = [];
  final List<KnowledgeFolder> _folders = [];
  final Map<String, List<ChunkPackageItem>> _chunksByDocument = {};
  final Map<String, List<ExtractedKnowledgeItem>> _extractedItemsByDocument =
      {};
  final Map<String, String> _embeddingModelByDocument = {};
  final Map<String, List<AiFlowchartCandidate>> _flowchartsByDocument = {};
  int _nextDocumentId = 1;

  static JsonFileStore? _defaultFolderStore(JsonFileStore? store) {
    if (store == null) {
      return null;
    }
    return JsonFileStore(File('${store.file.parent.path}/folders.json'));
  }

  Future<void> load() async {
    final store = _store;
    if (store != null) {
      final items = await store.readList();
      _documents
        ..clear()
        ..addAll(items.map(KnowledgeDocument.fromJson));
      _nextDocumentId =
          _nextNumericSuffix(
            _documents.map((document) => document.id),
            'document-',
          ) +
          1;
    }
    final folderStore = _folderStore;
    if (folderStore != null) {
      final items = await folderStore.readList();
      _folders
        ..clear()
        ..addAll(items.map(KnowledgeFolder.fromJson));
    }
  }

  Future<List<KnowledgeDocument>> listDocuments({String? folderId}) async {
    final documents = folderId == null
        ? _documents
        : _documents.where((document) => document.folderId == folderId);
    return List.unmodifiable(documents);
  }

  Future<List<KnowledgeFolder>> listFolders() async {
    return List.unmodifiable(_folders);
  }

  Future<KnowledgeFolder> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder name must not be blank');
    }
    final now = DateTime.now();
    final folder = KnowledgeFolder(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    _folders.add(folder);
    await _persistFolders();
    return folder;
  }

  Future<KnowledgeFolder> renameFolder(String folderId, String name) async {
    final index = _folders.indexWhere((folder) => folder.id == folderId);
    if (index == -1) {
      throw StateError('knowledge folder not found: $folderId');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder name must not be blank');
    }
    final updated = _folders[index].copyWith(
      name: trimmed,
      updatedAt: DateTime.now(),
    );
    _folders[index] = updated;
    await _persistFolders();
    return updated;
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((folder) => folder.id == folderId);
    await _persistFolders();
    await moveDocumentsToFolder(
      _documents
          .where((document) => document.folderId == folderId)
          .map((document) => document.id)
          .toList(growable: false),
      null,
    );
  }

  Future<void> moveDocumentsToFolder(
    List<String> documentIds,
    String? folderId,
  ) async {
    final idSet = documentIds.toSet();
    _documents = [
      for (final document in _documents)
        if (idSet.contains(document.id))
          document.copyWith(folderId: folderId, clearFolderId: folderId == null)
        else
          document,
    ];
    await _persist();
  }

  Future<void> deleteDocuments(List<String> documentIds) async {
    final idSet = documentIds.toSet();
    final documentsToDelete = _documents
        .where((document) => idSet.contains(document.id))
        .toList(growable: false);
    _documents = [
      for (final document in _documents)
        if (!idSet.contains(document.id)) document,
    ];
    for (final document in documentsToDelete) {
      _chunksByDocument.remove(document.id);
      _extractedItemsByDocument.remove(document.id);
      _embeddingModelByDocument.remove(document.id);
      _flowchartsByDocument.remove(document.id);
      await _deleteLocalFileIfPresent(document.localPath);
    }
    await _persist();
  }

  Future<KnowledgeBaseState> state() async {
    return KnowledgeBaseState.fromDocuments(_documents);
  }

  Future<KnowledgeDocument> addDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    required DateTime importedAt,
    String? sha256,
    String? folderId,
  }) async {
    final document = KnowledgeDocument(
      id: 'document-${_nextDocumentId++}',
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      importedAt: importedAt,
      status: KnowledgeDocumentStatus.imported,
      folderId: folderId,
      sha256: sha256,
    );
    _documents.insert(0, document);
    await _persist();
    return document;
  }

  Future<KnowledgeDocument> updateStatus(
    String documentId,
    KnowledgeDocumentStatus status, {
    String? backendDocumentId,
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  }) async {
    final index = _documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (index == -1) {
      throw StateError('knowledge document not found: $documentId');
    }
    final updated = _documents[index].copyWith(
      status: status,
      backendDocumentId: backendDocumentId,
      errorMessage: errorMessage,
      clearErrorMessage: errorMessage == null,
      activeProvider: activeProvider,
      activeModel: activeModel,
      lastErrorCode: lastErrorCode,
      retryable: retryable,
      clearLastErrorCode: clearLastErrorCode,
    );
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  Future<KnowledgeDocument> reconcileBackendDocument({
    required String localDocumentId,
    required KnowledgeDocument backendDocument,
  }) async {
    final index = _documents.indexWhere(
      (document) => document.id == localDocumentId,
    );
    if (index == -1) {
      throw StateError('knowledge document not found: $localDocumentId');
    }
    final current = _documents[index];
    final updated = current.copyWith(
      filename: backendDocument.filename.isEmpty
          ? current.filename
          : backendDocument.filename,
      sizeBytes: backendDocument.sizeBytes == 0
          ? current.sizeBytes
          : backendDocument.sizeBytes,
      status: backendDocument.status,
      backendDocumentId:
          backendDocument.backendDocumentId ?? backendDocument.id,
      errorMessage: backendDocument.errorMessage,
      clearErrorMessage: backendDocument.errorMessage == null,
    );
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  KnowledgeDocument? findByBackendDocumentId(String backendDocumentId) {
    for (final document in _documents) {
      if (document.backendDocumentId == backendDocumentId) {
        return document;
      }
    }
    return null;
  }

  @override
  Future<String> localPathForDocument(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    return document.localPath;
  }

  @override
  Future<void> markState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  }) async {
    await updateStatus(
      documentPublicId,
      _statusFromProcessingState(state),
      errorMessage: errorMessage,
      activeProvider: activeProvider,
      activeModel: activeModel,
      lastErrorCode: lastErrorCode,
      retryable: retryable,
      clearLastErrorCode: clearLastErrorCode,
    );
  }

  @override
  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  }) {
    return saveExtractedEvidence(
      documentPublicId: documentPublicId,
      evidence: AiExtractedEvidence(
        id: chunk.id,
        text: chunk.text,
        pageNumber: chunk.pageNumber,
        sectionTitle: chunk.sectionTitle,
        sourceType: AiEvidenceSourceType.textChunk,
      ),
      embedding: embedding,
      embeddingModel: embeddingModel,
    );
  }

  @override
  Future<void> clearGeneratedKnowledge(String documentPublicId) async {
    _chunksByDocument.remove(documentPublicId);
    final existing = _extractedItemsByDocument[documentPublicId];
    if (existing == null) {
      _extractedItemsByDocument.remove(documentPublicId);
    } else {
      final locals = existing
          .where((item) => item.pipeline != LocalExtractionPipeline.ai)
          .toList(growable: false);
      if (locals.isEmpty) {
        _extractedItemsByDocument.remove(documentPublicId);
      } else {
        _extractedItemsByDocument[documentPublicId] = locals;
      }
    }
    _embeddingModelByDocument.remove(documentPublicId);
    _flowchartsByDocument.remove(documentPublicId);
  }

  @override
  Future<void> saveExtractedEvidence({
    required String documentPublicId,
    required AiExtractedEvidence evidence,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    final sourceType = _evidenceSourceType(evidence.sourceType);
    if (sourceType == EvidenceSourceType.flowchartNode ||
        sourceType == EvidenceSourceType.flowchartEdge) {
      _embeddingModelByDocument[documentPublicId] = embeddingModel;
      return;
    }
    final items = _chunksByDocument.putIfAbsent(documentPublicId, () => []);
    items.removeWhere((item) => item.id == evidence.id);
    items.add(
      ChunkPackageItem(
        id: evidence.id,
        text: evidence.text,
        pageNumber: evidence.pageNumber,
        sectionTitle: evidence.sectionTitle,
        embedding: embedding,
      ),
    );
    final extractedItems = _extractedItemsByDocument.putIfAbsent(
      documentPublicId,
      () => [],
    );
    extractedItems.removeWhere((item) => item.id == evidence.id);
    extractedItems.add(
      ExtractedKnowledgeItem(
        id: evidence.id,
        documentId: documentPublicId,
        sourceType: sourceType,
        text: evidence.text,
        pageNumber: evidence.pageNumber,
        sectionTitle: evidence.sectionTitle,
        embeddingModel: embeddingModel,
        pipeline: LocalExtractionPipeline.ai,
        chunkKind: _localKindForSourceType(sourceType),
        auditState: LocalAuditState.accepted,
      ),
    );
    _embeddingModelByDocument[documentPublicId] = embeddingModel;
  }

  @override
  Future<void> saveFlowchartCandidate({
    required String documentPublicId,
    required AiFlowchartCandidate flowchart,
  }) async {
    final items = _flowchartsByDocument.putIfAbsent(documentPublicId, () => []);
    items.removeWhere((item) => item.id == flowchart.id);
    items.add(flowchart);
  }

  Future<EditableFlowchart?> loadEditableFlowchart({
    required String documentId,
    required String flowchartId,
  }) async {
    final flowcharts = _flowchartsByDocument[documentId] ?? const [];
    for (final flowchart in flowcharts) {
      if (flowchart.id == flowchartId) {
        return EditableFlowchart(
          id: flowchart.id,
          documentId: documentId,
          pageNumber: flowchart.pageNumber,
          title: flowchart.title,
          nodes: [
            for (final node in flowchart.nodes)
              EditableFlowchartNode(
                id: node.id,
                label: node.label,
                shape: node.shape,
                order: node.order,
              ),
          ],
          edges: [
            for (final edge in flowchart.edges)
              EditableFlowchartEdge(
                id: edge.id,
                fromNodeId: edge.fromNodeId,
                toNodeId: edge.toNodeId,
                label: edge.label,
                order: edge.order,
              ),
          ],
        );
      }
    }
    return null;
  }

  Future<void> saveEditableFlowchart(EditableFlowchart flowchart) async {
    await saveFlowchartCandidate(
      documentPublicId: flowchart.documentId,
      flowchart: AiFlowchartCandidate(
        id: flowchart.id,
        pageNumber: flowchart.pageNumber,
        title: flowchart.title,
        nodes: [
          for (final node in flowchart.nodes)
            AiFlowchartNode(
              id: node.id,
              label: node.label,
              shape: node.shape,
              order: node.order,
            ),
        ],
        edges: [
          for (final edge in flowchart.edges)
            AiFlowchartEdge(
              id: edge.id,
              fromNodeId: edge.fromNodeId,
              toNodeId: edge.toNodeId,
              label: edge.label,
              order: edge.order,
            ),
        ],
      ),
    );
  }

  Future<List<ExtractedKnowledgeItem>> listExtractedKnowledgeItems(
    String documentPublicId, {
    LocalExtractionPipeline? pipeline,
  }) async {
    final items = [
      ...?_extractedItemsByDocument[documentPublicId],
      for (final flowchart
          in _flowchartsByDocument[documentPublicId] ?? const [])
        ..._flowchartItems(documentPublicId, flowchart),
    ];
    final filtered = pipeline == null
        ? items
        : items.where((item) => item.pipeline == pipeline).toList();
    filtered.sort(_compareExtractedItems);
    return List.unmodifiable(filtered);
  }

  Future<void> saveLocalChunks(
    String documentPublicId,
    List<LocalChunk> chunks, {
    bool replaceExisting = true,
  }) async {
    final extractedItems = _extractedItemsByDocument.putIfAbsent(
      documentPublicId,
      () => [],
    );
    if (replaceExisting) {
      extractedItems.removeWhere(
        (item) => _isGeneratedLocalPipeline(item.pipeline),
      );
    }
    for (final chunk in chunks) {
      extractedItems.removeWhere(
        (item) => item.id == chunk.id && item.pipeline == chunk.pipeline,
      );
      extractedItems.add(_itemFromLocalChunk(documentPublicId, chunk));
    }
  }

  Future<void> updateExtractedKnowledgeAuditState(
    String documentPublicId,
    String itemId,
    LocalAuditState auditState, {
    String? text,
    String? reason,
  }) async {
    final extractedItems = _extractedItemsByDocument[documentPublicId];
    if (extractedItems == null) {
      return;
    }
    final index = extractedItems.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    extractedItems[index] = extractedItems[index].copyWith(
      auditState: auditState,
      text: text,
    );
  }

  Future<void> updateExtractedKnowledgeItem(
    String documentPublicId,
    String itemId, {
    String? text,
    String? sectionTitle,
    LocalChunkKind? chunkKind,
    LocalAuditState? auditState,
    List<NoteKnowledgeTag>? tags,
  }) async {
    final extractedItems = _extractedItemsByDocument[documentPublicId];
    if (extractedItems == null) {
      return;
    }
    final index = extractedItems.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    final kind = chunkKind ?? extractedItems[index].chunkKind;
    extractedItems[index] = extractedItems[index].copyWith(
      text: text,
      sectionTitle: sectionTitle,
      chunkKind: kind,
      sourceType: _sourceTypeForLocalKind(kind),
      auditState: auditState,
      tags: tags,
    );
  }

  Future<void> updateExtractedKnowledgeTags(
    String documentPublicId,
    String itemId,
    List<NoteKnowledgeTag> tags,
  ) async {
    final extractedItems = _extractedItemsByDocument[documentPublicId];
    if (extractedItems == null) {
      return;
    }
    final index = extractedItems.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      return;
    }
    extractedItems[index] = extractedItems[index].copyWith(tags: tags);
  }

  Future<ChunkComparison> compareExtractedChunks(
    String documentPublicId,
  ) async {
    final aiItems = await listExtractedKnowledgeItems(
      documentPublicId,
      pipeline: LocalExtractionPipeline.ai,
    );
    final localItems = (await listExtractedKnowledgeItems(documentPublicId))
        .where((item) => _isGeneratedLocalPipeline(item.pipeline))
        .toList(growable: false);
    return ChunkComparison(
      rows: _compareChunkLists(aiItems: aiItems, localItems: localItems),
    );
  }

  Future<ChunkPackage> exportChunkPackage(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    final chunks = _chunksByDocument[documentPublicId] ?? const [];
    final embeddingDimension = chunks.isEmpty
        ? 0
        : chunks.first.embedding.length;
    return ChunkPackage(
      schemaVersion: 1,
      documentHash: document.sha256 ?? '',
      filename: document.filename,
      provider: document.activeProvider ?? '',
      extractionModel: document.activeModel ?? '',
      embeddingModel: _embeddingModelByDocument[documentPublicId] ?? '',
      embeddingDimension: embeddingDimension,
      chunks: List<ChunkPackageItem>.unmodifiable(chunks),
    );
  }

  Future<void> importChunkPackage(
    String documentPublicId,
    ChunkPackage package,
  ) async {
    final document = _findDocument(documentPublicId);
    const service = ChunkPackageService();
    service.validateForImport(
      package,
      documentHash: document.sha256 ?? '',
      expectedDimension: package.embeddingDimension,
    );
    _chunksByDocument[documentPublicId] = package.chunks;
    final localItems = (_extractedItemsByDocument[documentPublicId] ?? const [])
        .where((item) => item.pipeline != LocalExtractionPipeline.ai)
        .toList(growable: false);
    _extractedItemsByDocument[documentPublicId] = [
      for (final item in package.chunks)
        ExtractedKnowledgeItem(
          id: item.id,
          documentId: documentPublicId,
          sourceType: EvidenceSourceType.textChunk,
          text: item.text,
          pageNumber: item.pageNumber,
          sectionTitle: item.sectionTitle,
          embeddingModel: package.embeddingModel,
          pipeline: LocalExtractionPipeline.ai,
          chunkKind: LocalChunkKind.text,
          auditState: LocalAuditState.accepted,
        ),
      ...localItems,
    ];
    _embeddingModelByDocument[documentPublicId] = package.embeddingModel;
    await updateStatus(
      document.id,
      KnowledgeDocumentStatus.ready,
      activeProvider: package.provider.isEmpty ? null : package.provider,
      activeModel: package.extractionModel.isEmpty
          ? null
          : package.extractionModel,
      clearLastErrorCode: true,
    );
  }

  ExtractedKnowledgeItem _itemFromLocalChunk(
    String documentPublicId,
    LocalChunk chunk,
  ) {
    return ExtractedKnowledgeItem(
      id: chunk.id,
      documentId: documentPublicId,
      sourceType: _sourceTypeForLocalKind(chunk.kind),
      text: chunk.text,
      pageNumber: chunk.pageNumber,
      sectionTitle: chunk.sectionTitle,
      sourceRectJson: chunk.sourceRectJson,
      pipeline: chunk.pipeline,
      chunkKind: chunk.kind,
      auditState: chunk.auditState,
      endPageNumber: chunk.endPageNumber,
      confidence: chunk.confidence,
      sourcePageImagePath: chunk.sourcePageImagePath,
      tags: chunk.tags,
    );
  }

  EvidenceSourceType _sourceTypeForLocalKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.table => EvidenceSourceType.tableChunk,
      LocalChunkKind.flowchart => EvidenceSourceType.flowchartNode,
      LocalChunkKind.text ||
      LocalChunkKind.list => EvidenceSourceType.textChunk,
    };
  }

  bool _isGeneratedLocalPipeline(LocalExtractionPipeline pipeline) {
    return pipeline != LocalExtractionPipeline.ai &&
        pipeline != LocalExtractionPipeline.manual;
  }

  LocalChunkKind _localKindForSourceType(EvidenceSourceType sourceType) {
    return switch (sourceType) {
      EvidenceSourceType.textChunk => LocalChunkKind.text,
      EvidenceSourceType.tableChunk => LocalChunkKind.table,
      EvidenceSourceType.scoreChunk => LocalChunkKind.table,
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => LocalChunkKind.flowchart,
    };
  }

  List<ChunkComparisonRow> _compareChunkLists({
    required List<ExtractedKnowledgeItem> aiItems,
    required List<ExtractedKnowledgeItem> localItems,
  }) {
    final rows = <ChunkComparisonRow>[];
    final localByKey = <String, List<ExtractedKnowledgeItem>>{};
    for (final local in localItems) {
      localByKey.putIfAbsent(_comparisonKey(local), () => []).add(local);
    }
    final matchedLocalIds = <String>{};
    for (final ai in aiItems) {
      ExtractedKnowledgeItem? local;
      final candidates =
          localByKey[_comparisonKey(ai)] ?? const <ExtractedKnowledgeItem>[];
      for (final candidate in candidates) {
        if (!matchedLocalIds.contains(candidate.id)) {
          local = candidate;
          break;
        }
      }
      if (local == null) {
        rows.add(
          ChunkComparisonRow(status: ChunkComparisonStatus.aiOnly, aiChunk: ai),
        );
        continue;
      }
      matchedLocalIds.add(local.id);
      rows.add(
        ChunkComparisonRow(
          status: ChunkComparisonStatus.matched,
          aiChunk: ai,
          localChunk: local,
        ),
      );
    }
    for (final local in localItems) {
      if (matchedLocalIds.contains(local.id)) {
        continue;
      }
      rows.add(
        ChunkComparisonRow(
          status: ChunkComparisonStatus.localOnly,
          localChunk: local,
        ),
      );
    }
    rows.sort((a, b) {
      final page = (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
      if (page != 0) {
        return page;
      }
      return a.sectionTitle.compareTo(b.sectionTitle);
    });
    return rows;
  }

  String _comparisonKey(ExtractedKnowledgeItem item) {
    final section = (item.sectionTitle ?? '').trim().toLowerCase();
    if (section.isNotEmpty) {
      return '${item.pageNumber ?? 0}:$section';
    }
    return '${item.pageNumber ?? 0}:${item.sourceType.wireName}';
  }

  EvidenceSourceType _evidenceSourceType(AiEvidenceSourceType sourceType) {
    return switch (sourceType) {
      AiEvidenceSourceType.textChunk => EvidenceSourceType.textChunk,
      AiEvidenceSourceType.table => EvidenceSourceType.tableChunk,
      AiEvidenceSourceType.score => EvidenceSourceType.scoreChunk,
      AiEvidenceSourceType.flowchartNode => EvidenceSourceType.flowchartNode,
      AiEvidenceSourceType.flowchartEdge => EvidenceSourceType.flowchartEdge,
    };
  }

  int _compareExtractedItems(
    ExtractedKnowledgeItem a,
    ExtractedKnowledgeItem b,
  ) {
    final page = (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
    if (page != 0) {
      return page;
    }
    final type = a.sourceType.index.compareTo(b.sourceType.index);
    if (type != 0) {
      return type;
    }
    return a.id.compareTo(b.id);
  }

  List<ExtractedKnowledgeItem> _flowchartItems(
    String documentPublicId,
    AiFlowchartCandidate flowchart,
  ) {
    final title = (flowchart.title ?? 'Flowchart').trim();
    final sectionTitle = title.isEmpty ? 'Flowchart' : title;
    final nodeLabels = {
      for (final node in flowchart.nodes) node.id: node.label.trim(),
    };
    return [
      for (final node in flowchart.nodes)
        ExtractedKnowledgeItem(
          id: '${flowchart.id}:${node.id}',
          documentId: documentPublicId,
          sourceType: EvidenceSourceType.flowchartNode,
          text: node.label.trim(),
          pageNumber: flowchart.pageNumber,
          sectionTitle: sectionTitle,
          embeddingModel: _embeddingModelByDocument[documentPublicId],
          flowchartId: flowchart.id,
          flowchartElementId: node.id,
          flowchartShape: node.shape.wireName,
          flowchartOrder: node.order,
          sourceRectJson: _sourceRectJson(node.sourceRect),
          chunkKind: LocalChunkKind.flowchart,
          auditState: LocalAuditState.unreviewed,
        ),
      for (final edge in flowchart.edges)
        ExtractedKnowledgeItem(
          id: '${flowchart.id}:${edge.id}',
          documentId: documentPublicId,
          sourceType: EvidenceSourceType.flowchartEdge,
          text: _flowchartEdgeText(edge, nodeLabels),
          pageNumber: flowchart.pageNumber,
          sectionTitle: '$sectionTitle kapcsolat',
          embeddingModel: _embeddingModelByDocument[documentPublicId],
          flowchartId: flowchart.id,
          flowchartElementId: edge.id,
          flowchartFromId: edge.fromNodeId,
          flowchartToId: edge.toNodeId,
          flowchartEdgeLabel: edge.label,
          flowchartOrder: edge.order,
          sourceRectJson: _sourceRectJson(edge.sourceRect),
          chunkKind: LocalChunkKind.flowchart,
          auditState: LocalAuditState.unreviewed,
        ),
    ];
  }

  String? _sourceRectJson(Map<String, Object?>? sourceRect) {
    if (sourceRect == null) {
      return null;
    }
    return jsonEncode(sourceRect);
  }

  String _flowchartEdgeText(
    AiFlowchartEdge edge,
    Map<String, String> nodeLabels,
  ) {
    final from = nodeLabels[edge.fromNodeId] ?? edge.fromNodeId;
    final to = nodeLabels[edge.toNodeId] ?? edge.toNodeId;
    final label = edge.label.trim();
    return label.isEmpty ? '$from -> $to' : '$from -> $to [$label]';
  }

  KnowledgeDocument _findDocument(String documentId) {
    for (final document in _documents) {
      if (document.id == documentId) {
        return document;
      }
    }
    throw StateError('knowledge document not found: $documentId');
  }

  KnowledgeDocumentStatus _statusFromProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.imported => KnowledgeDocumentStatus.imported,
      ProcessingState.blockedMissingApiKey =>
        KnowledgeDocumentStatus.blockedMissingApiKey,
      ProcessingState.blockedOffline => KnowledgeDocumentStatus.blockedOffline,
      ProcessingState.uploading => KnowledgeDocumentStatus.uploading,
      ProcessingState.processing => KnowledgeDocumentStatus.processing,
      ProcessingState.embedded => KnowledgeDocumentStatus.embedded,
      ProcessingState.ready => KnowledgeDocumentStatus.ready,
      ProcessingState.needsReview => KnowledgeDocumentStatus.needsReview,
      ProcessingState.failed => KnowledgeDocumentStatus.failed,
    };
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.writeList(
      _documents.map((document) => document.toJson()).toList(),
    );
  }

  Future<void> _persistFolders() async {
    final store = _folderStore;
    if (store == null) {
      return;
    }
    await store.writeList(_folders.map((folder) => folder.toJson()).toList());
  }

  Future<void> _deleteLocalFileIfPresent(String path) async {
    if (path.isEmpty) {
      return;
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // A missing or provider-owned file should not block database cleanup.
    }
  }

  int _nextNumericSuffix(Iterable<String> ids, String prefix) {
    var max = 0;
    for (final id in ids) {
      if (!id.startsWith(prefix)) {
        continue;
      }
      final value = int.tryParse(id.substring(prefix.length));
      if (value != null && value > max) {
        max = value;
      }
    }
    return max;
  }
}
