import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/flowchart/data/objectbox_flowchart_projection.dart';
import 'package:djinn/src/flowchart/data/flowchart_validation_repository.dart';
import 'package:djinn/src/knowledge/data/objectbox_knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/objectbox_knowledge_repository.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/notes/data/objectbox_note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('detached note-linked flowcharts remain projectable', () {
    expect(
      canonicalFlowchartProjectionAction(
        documentPublicId: '',
        isNoteLinked: true,
      ),
      CanonicalFlowchartProjectionAction.project,
    );
    expect(
      canonicalFlowchartProjectionAction(
        documentPublicId: '',
        isNoteLinked: false,
      ),
      CanonicalFlowchartProjectionAction.remove,
    );
  });

  test('flowchart parent relation follows the live reprocessed source', () {
    final parent = DocumentChunkEntity(
      publicId: 'document-1:flow-1',
      documentPublicId: '',
      text: 'Detached',
      pageNumber: 1,
    );
    final flowchart = FlowchartEntity(
      publicId: parent.publicId,
      documentPublicId: 'document-1',
      pageNumber: 1,
      validationState: ValidationState.unreviewed.wireName,
    );

    synchronizeFlowchartParentDocumentRelation(
      parent: parent,
      flowchart: flowchart,
    );

    expect(parent.documentPublicId, 'document-1');
  });

  test(
    'ObjectBox document adapter delegates canonical top-level tag updates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-document-adapter-tags-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final adapter = ObjectBoxKnowledgeDocumentRepository(
        repository: repository,
      );
      final document = await adapter.addDocument(
        filename: 'adapter-tags.pdf',
        localPath: '/memory/adapter-tags.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 7, 25),
        sha256: 'adapter-tags-hash',
      );
      const scopedTag = NoteKnowledgeTag(
        id: 'tag-cell',
        type: NoteKnowledgeTagTypes.topic,
        label: 'Cell scope',
      );
      const topLevelTag = NoteKnowledgeTag(
        id: 'tag-chunk',
        type: NoteKnowledgeTagTypes.custom,
        label: 'Chunk scope',
      );
      const content = NoteBlock(
        id: 'adapter-tagged-chunk',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'table-1',
            type: NoteMixedSectionType.table,
            rows: [
              ['Scoped value'],
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'scope-cell',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableCell,
                  rowIndex: 0,
                  columnIndex: 0,
                ),
                tags: [scopedTag],
              ),
            ],
          ),
        ],
      );
      await adapter.saveLocalChunks(document.id, [
        LocalChunk(
          id: content.id,
          documentId: document.id,
          text: content.plainText,
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.text,
          tags: const [scopedTag],
          structuredContentJson: jsonEncode(content.toJson()),
        ),
      ], replaceExisting: false);

      await adapter.updateExtractedKnowledgeTags(
        document.id,
        content.id,
        const [topLevelTag],
      );

      final item = (await adapter.listExtractedKnowledgeItems(
        document.id,
      )).single;
      final storedContent = NoteBlock.fromJson(
        Map<String, Object?>.from(
          jsonDecode(item.structuredContentJson!) as Map,
        ),
      );
      expect(storedContent.tags.map((tag) => tag.metadataText), [
        topLevelTag.metadataText,
      ]);
      expect(
        storedContent.mixedSections.single.scopedTags.single.tags.map(
          (tag) => tag.metadataText,
        ),
        [scopedTag.metadataText],
      );
    },
  );

  test(
    'startup migration canonicalizes chunk-derived audit and graph rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-derived-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);
      const sourceId = 'document-1:legacy-table';
      objectBox.store.box<DocumentChunkEntity>().put(
        DocumentChunkEntity(
          publicId: sourceId,
          documentPublicId: 'document-1',
          text: 'A | B',
          pageNumber: 1,
          chunkKind: 'table',
          pipeline: 'local_table',
        ),
      );
      objectBox.store.box<ExtractionAuditItemEntity>().put(
        ExtractionAuditItemEntity(
          publicId: '$sourceId:audit',
          documentPublicId: 'document-1',
          sourceId: sourceId,
          itemKind: 'table',
          auditState: 'unreviewed',
          createdAtMillis: 1,
        ),
      );
      objectBox.store.box<KnowledgeNodeEntity>().put(
        KnowledgeNodeEntity(
          publicId: '$sourceId:node',
          documentPublicId: 'document-1',
          label: 'Régi táblázat',
          nodeType: 'table',
          sourceId: sourceId,
        ),
      );

      ObjectBoxKnowledgeRepository(store: objectBox.store);

      expect(
        objectBox.store.box<DocumentChunkEntity>().getAll().single.chunkKind,
        ChunkKind.noteChunk.wireName,
      );
      expect(
        objectBox.store
            .box<ExtractionAuditItemEntity>()
            .getAll()
            .single
            .itemKind,
        ChunkKind.noteChunk.wireName,
      );
      expect(
        objectBox.store.box<KnowledgeNodeEntity>().getAll().single.nodeType,
        ChunkKind.noteChunk.wireName,
      );
    },
  );

  test(
    'updates ObjectBox graph rows and invalidates stale embeddings',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-update-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'manual.pdf',
        localPath: '/memory/manual.pdf',
        sizeBytes: 4,
        sha256: 'hash-manual-update',
      );
      await repository.saveLocalChunks(document.publicId, const [
        LocalChunk(
          id: 'manual-1',
          documentId: 'document-1',
          text: 'Régi szöveg',
          pageNumber: 1,
          sectionTitle: 'Régi cím',
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.text,
        ),
      ], replaceExisting: false);
      objectBox.store.box<ChunkEmbeddingEntity>().put(
        ChunkEmbeddingEntity(
          sourceId: '${document.publicId}:manual-1',
          sourceType: EvidenceSourceType.textChunk.wireName,
          vector: List<double>.filled(3072, 0.1),
          model: 'stale-embedding',
          createdAtMillis: 1,
        ),
      );

      await repository.updateExtractedKnowledgeItem(
        document.publicId,
        'manual-1',
        text: 'Új táblázat',
        sectionTitle: 'Új cím',
        chunkKind: LocalChunkKind.table,
        auditState: LocalAuditState.edited,
      );

      final sourceId = '${document.publicId}:manual-1';
      final chunk = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere((item) => item.publicId == sourceId);
      expect(chunk.text, 'Új táblázat');
      expect(chunk.sectionTitle, 'Új cím');
      expect(chunk.chunkKind, ChunkKind.noteChunk.wireName);
      expect(chunk.auditState, LocalAuditState.edited.wireName);

      final audit = objectBox.store
          .box<ExtractionAuditItemEntity>()
          .getAll()
          .singleWhere((item) => item.sourceId == sourceId);
      expect(audit.previewText, 'Új táblázat');
      expect(audit.title, 'Új cím');
      expect(audit.itemKind, ChunkKind.noteChunk.wireName);

      final node = objectBox.store
          .box<KnowledgeNodeEntity>()
          .getAll()
          .singleWhere((item) => item.publicId == '$sourceId:node');
      expect(node.label, 'Új cím');
      expect(node.nodeType, ChunkKind.noteChunk.wireName);

      final evidence = objectBox.store
          .box<KnowledgeEvidenceEntity>()
          .getAll()
          .singleWhere((item) => item.sourceId == sourceId);
      expect(evidence.quote, 'Új táblázat');

      final sectionEdge = objectBox.store
          .box<KnowledgeEdgeEntity>()
          .getAll()
          .singleWhere(
            (item) =>
                item.fromNodePublicId == '$sourceId:node' &&
                item.relationType == 'part_of',
          );
      expect(
        sectionEdge.toNodePublicId,
        '${document.publicId}:section:${_graphKey('Új cím')}',
      );

      final embeddings = objectBox.store
          .box<ChunkEmbeddingEntity>()
          .getAll()
          .where((item) => item.sourceId == sourceId)
          .toList(growable: false);
      expect(embeddings, isEmpty);
    },
  );

  test('updates ObjectBox graph rows through audit text edits', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-objectbox-audit-update-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final ObjectBoxStore objectBox;
    try {
      objectBox = await ObjectBoxStore.open(directory: directory);
    } on ArgumentError catch (error) {
      markTestSkipped('Host ObjectBox library unavailable: $error');
      return;
    }
    addTearDown(objectBox.close);

    final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
    final document = await repository.addImportedDocument(
      filename: 'audit.pdf',
      localPath: '/memory/audit.pdf',
      sizeBytes: 4,
      sha256: 'hash-audit-update',
    );
    await repository.saveLocalChunks(document.publicId, const [
      LocalChunk(
        id: 'audit-1',
        documentId: 'document-1',
        text: 'Régi audit szöveg',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);
    objectBox.store.box<ChunkEmbeddingEntity>().put(
      ChunkEmbeddingEntity(
        sourceId: '${document.publicId}:audit-1',
        sourceType: EvidenceSourceType.textChunk.wireName,
        vector: List<double>.filled(3072, 0.1),
        model: 'stale-embedding',
        createdAtMillis: 1,
      ),
    );

    await repository.updateExtractedKnowledgeAuditState(
      document.publicId,
      'audit-1',
      LocalAuditState.accepted,
      text: 'Javított audit szöveg',
    );

    final sourceId = '${document.publicId}:audit-1';
    final node = objectBox.store
        .box<KnowledgeNodeEntity>()
        .getAll()
        .singleWhere((item) => item.publicId == '$sourceId:node');
    expect(node.label, 'Javított audit szöveg');

    final evidence = objectBox.store
        .box<KnowledgeEvidenceEntity>()
        .getAll()
        .singleWhere((item) => item.sourceId == sourceId);
    expect(evidence.quote, 'Javított audit szöveg');

    final embeddings = objectBox.store
        .box<ChunkEmbeddingEntity>()
        .getAll()
        .where((item) => item.sourceId == sourceId)
        .toList(growable: false);
    expect(embeddings, isEmpty);
  });

  test(
    'manual ObjectBox chunks preserve structured mixed content json',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-mixed-json-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'mixed.pdf',
        localPath: '/memory/mixed.pdf',
        sizeBytes: 4,
        sha256: 'hash-mixed-json',
      );

      await repository.saveLocalChunks(document.publicId, const [
        LocalChunk(
          id: 'mixed-1',
          documentId: 'ignored',
          text: 'Az eljárásrend célja:\naz ellátás során',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.text,
          structuredContentJson: '{"type":"mixed","mixedSections":[]}',
        ),
      ], replaceExisting: false);

      final items = await repository.listExtractedKnowledgeItems(
        document.publicId,
      );
      expect(items.single.structuredContentJson, contains('"type":"mixed"'));
    },
  );

  test(
    'manual ObjectBox flowchart parent is listed without a legacy projection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-manual-flowchart-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'manual-flowchart.pdf',
        localPath: '/memory/manual-flowchart.pdf',
        sizeBytes: 4,
        sha256: 'hash-manual-flowchart',
      );
      const content = NoteBlock(
        id: 'manual-flow-1',
        type: NoteBlockType.flowchart,
        title: 'Kézi flowchart',
        nodes: [
          NoteFlowchartNode(id: 'start', label: 'Kezdés', order: 1),
          NoteFlowchartNode(id: 'end', label: 'Vége', order: 2),
        ],
        edges: [
          NoteFlowchartEdge(
            id: 'edge-1',
            fromNodeId: 'start',
            toNodeId: 'end',
            label: '',
            order: 1,
          ),
        ],
      );
      await repository.saveLocalChunks(document.publicId, [
        LocalChunk(
          id: 'manual-flow-1',
          documentId: document.publicId,
          text: content.plainText,
          pageNumber: 2,
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.flowchart,
          structuredContentJson: jsonEncode(content.toJson()),
        ),
      ], replaceExisting: false);

      final items = await repository.listExtractedKnowledgeItems(
        document.publicId,
      );
      expect(items, hasLength(1));
      expect(items.single.id, 'manual-flow-1');
      expect(items.single.chunkKind, LocalChunkKind.flowchart);
      final storedContent = NoteBlock.fromJson(
        Map<String, Object?>.from(
          jsonDecode(items.single.structuredContentJson!) as Map,
        ),
      );
      expect(storedContent.nodes, hasLength(2));
      expect(storedContent.edges, hasLength(1));
    },
  );

  test(
    'canonical flowchart edit survives restart and refreshes legacy projection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-flowchart-authority-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      var repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'flowchart-authority.pdf',
        localPath: '/memory/flowchart-authority.pdf',
        sizeBytes: 4,
        sha256: 'hash-flowchart-authority',
      );
      await repository.saveFlowchartCandidate(
        documentPublicId: document.publicId,
        flowchart: const AiFlowchartCandidate(
          id: 'flow-1',
          pageNumber: 3,
          nodes: [AiFlowchartNode(id: 'start', label: 'Régi kezdet', order: 1)],
          edges: [],
        ),
      );
      const edited = NoteBlock(
        id: 'flow-1',
        type: NoteBlockType.flowchart,
        title: 'Szerkesztett folyamat',
        nodes: [
          NoteFlowchartNode(id: 'start', label: 'Új kezdet', order: 1),
          NoteFlowchartNode(id: 'end', label: 'Új vég', order: 2),
        ],
        edges: [
          NoteFlowchartEdge(
            id: 'edge-1',
            fromNodeId: 'start',
            toNodeId: 'end',
            label: 'tovább',
            order: 1,
          ),
        ],
      );
      await repository.updateExtractedKnowledgeItem(
        document.publicId,
        'flow-1',
        text: edited.plainText,
        sectionTitle: edited.title,
        chunkKind: LocalChunkKind.flowchart,
        auditState: LocalAuditState.edited,
        structuredContentJson: jsonEncode(edited.toJson()),
      );

      repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final item = (await repository.listExtractedKnowledgeItems(
        document.publicId,
      )).single;
      final restartedContent = NoteBlock.fromJson(
        Map<String, Object?>.from(
          jsonDecode(item.structuredContentJson!) as Map,
        ),
      );
      expect(restartedContent.title, 'Szerkesztett folyamat');
      expect(restartedContent.nodes.map((node) => node.label), [
        'Új kezdet',
        'Új vég',
      ]);
      expect(restartedContent.edges.single.label, 'tovább');

      final projectedNodes = objectBox.store
          .box<FlowchartNodeEntity>()
          .getAll()
          .where(
            (node) => node.flowchartPublicId == '${document.publicId}:flow-1',
          )
          .toList(growable: false);
      expect(projectedNodes.map((node) => node.label).toSet(), {
        'Új kezdet',
        'Új vég',
      });

      final validationRepository = ObjectBoxFlowchartValidationRepository(
        store: objectBox.store,
      );
      for (final node in projectedNodes) {
        await validationRepository.updateNodeValidation(
          nodePublicId: node.publicId,
          state: ValidationState.validated,
        );
      }
      final projectedEdge = objectBox.store
          .box<FlowchartEdgeEntity>()
          .getAll()
          .singleWhere(
            (edge) => edge.flowchartPublicId == '${document.publicId}:flow-1',
          );
      await validationRepository.updateEdgeValidation(
        edgePublicId: projectedEdge.publicId,
        state: ValidationState.validated,
      );
      final parent = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere(
            (chunk) => chunk.publicId == '${document.publicId}:flow-1',
          );
      expect(parent.auditState, LocalAuditState.accepted.wireName);
    },
  );

  test(
    'reprocessing and source deletion preserve linked chunks without dangling links',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-linked-lifecycle-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final noteRepository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
      );
      await noteRepository.load();
      final collector = await noteRepository.createDocumentNote(
        title: 'Gyűjtő',
        document: NoteDocument.empty(),
      );
      final document = await repository.addImportedDocument(
        filename: 'linked.pdf',
        localPath: '/memory/linked.pdf',
        sizeBytes: 4,
        sha256: 'hash-linked-lifecycle',
      );
      await repository.saveLocalChunks(document.publicId, const [
        LocalChunk(
          id: 'stable-1',
          documentId: 'ignored',
          text: 'Első változat',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localOcr,
        ),
      ], replaceExisting: false);
      await noteRepository.linkChunksToNote(collector.id, [
        '${document.publicId}:stable-1',
      ]);

      await repository.saveLocalChunks(document.publicId, const [
        LocalChunk(
          id: 'stable-1',
          documentId: 'ignored',
          text: 'Második változat',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localOcr,
        ),
      ]);
      objectBox.store.box<ChunkEmbeddingEntity>().put(
        ChunkEmbeddingEntity(
          sourceId: '${document.publicId}:stable-1',
          sourceType: EvidenceSourceType.textChunk.wireName,
          vector: const [0.25, 0.5],
          model: 'lifecycle-test',
          createdAtMillis: 1,
        ),
      );
      var linkedChunks = await noteRepository.listChunksForNote(collector.id);
      expect(
        linkedChunks
            .singleWhere((chunk) => chunk.id == '${document.publicId}:stable-1')
            .plainText,
        'Második változat',
      );
      expect(
        objectBox.store.box<DocumentChunkEntity>().getAll().where(
          (chunk) => chunk.publicId == '${document.publicId}:stable-1',
        ),
        hasLength(1),
      );

      await repository.deleteDocuments([document.publicId]);
      final retained = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere(
            (chunk) => chunk.publicId == '${document.publicId}:stable-1',
          );
      expect(retained.documentPublicId, isEmpty);
      expect(retained.sourceType, ChunkSourceType.pdf.wireName);
      expect(retained.sourcePublicId, document.publicId);
      expect(
        objectBox.store.box<ChunkNoteLinkEntity>().getAll().where(
          (link) =>
              link.notePublicId == collector.id &&
              link.chunkPublicId == retained.publicId,
        ),
        hasLength(1),
      );
      linkedChunks = await noteRepository.listChunksForNote(collector.id);
      expect(
        linkedChunks.any((chunk) => chunk.id == retained.publicId),
        isTrue,
      );
      expect(
        objectBox.store.box<ChunkEmbeddingEntity>().getAll().where(
          (embedding) => embedding.sourceId == retained.publicId,
        ),
        hasLength(1),
        reason:
            'A source deletion must retain the search vector while a note '
            'still references the detached chunk.',
      );

      await noteRepository.deleteNotes([collector.id]);
      expect(
        objectBox.store.box<DocumentChunkEntity>().getAll().where(
          (chunk) => chunk.publicId == retained.publicId,
        ),
        isEmpty,
      );
      expect(
        objectBox.store.box<ChunkEmbeddingEntity>().getAll().where(
          (embedding) => embedding.sourceId == retained.publicId,
        ),
        isEmpty,
        reason:
            'Deleting the final collector must also remove the detached '
            'chunk search vector.',
      );
    },
  );

  test(
    'linked flowchart keeps searchable element projections after source deletion',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-linked-flowchart-delete-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final noteRepository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
      );
      await noteRepository.load();
      final note = await noteRepository.createDocumentNote(
        title: 'Gyűjtő',
        document: NoteDocument.empty(),
      );
      final document = await repository.addImportedDocument(
        filename: 'linked-flow.pdf',
        localPath: '/memory/linked-flow.pdf',
        sizeBytes: 4,
        sha256: 'hash-linked-flow',
      );
      const content = NoteBlock(
        id: 'flow-1',
        type: NoteBlockType.flowchart,
        nodes: [NoteFlowchartNode(id: 'node-1', label: 'Kezdés')],
      );
      await repository.saveLocalChunks(document.publicId, [
        LocalChunk(
          id: 'flow-1',
          documentId: document.publicId,
          text: content.plainText,
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localFlowchart,
          kind: LocalChunkKind.flowchart,
          structuredContentJson: jsonEncode(content.toJson()),
        ),
      ], replaceExisting: false);
      final chunkId = '${document.publicId}:flow-1';
      await noteRepository.linkChunksToNote(note.id, [chunkId]);
      final projectedNode = objectBox.store
          .box<FlowchartNodeEntity>()
          .getAll()
          .singleWhere((node) => node.flowchartPublicId == chunkId);
      objectBox.store.box<ChunkEmbeddingEntity>().put(
        ChunkEmbeddingEntity(
          sourceId: projectedNode.publicId,
          sourceType: EvidenceSourceType.flowchartNode.wireName,
          vector: List<double>.filled(3072, 0.25),
          model: 'node-model',
          createdAtMillis: 1,
        ),
      );

      await repository.deleteDocuments([document.publicId]);
      ObjectBoxKnowledgeRepository(store: objectBox.store);

      final retainedChunk = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere((chunk) => chunk.publicId == chunkId);
      expect(retainedChunk.documentPublicId, isEmpty);
      expect(
        objectBox.store
            .box<FlowchartEntity>()
            .getAll()
            .singleWhere((flowchart) => flowchart.publicId == chunkId)
            .documentPublicId,
        isEmpty,
      );
      expect(
        objectBox.store.box<FlowchartNodeEntity>().getAll().where(
          (node) => node.publicId == projectedNode.publicId,
        ),
        hasLength(1),
      );
      expect(
        objectBox.store.box<ChunkEmbeddingEntity>().getAll().where(
          (embedding) => embedding.sourceId == projectedNode.publicId,
        ),
        hasLength(1),
      );
      final package = await noteRepository.exportChunkPackageForNote(note.id);
      expect(
        package.chunks
            .singleWhere((item) => item.id == chunkId)
            .embeddingRecords,
        hasLength(1),
      );

      await noteRepository.deleteNotes([note.id]);
      expect(
        objectBox.store.box<DocumentChunkEntity>().getAll().where(
          (chunk) => chunk.publicId == chunkId,
        ),
        isEmpty,
      );
      expect(
        objectBox.store.box<ChunkEmbeddingEntity>().getAll().where(
          (embedding) => embedding.sourceId.startsWith(chunkId),
        ),
        isEmpty,
      );
    },
  );

  test(
    'detached linked flowchart edits rebuild projections without reattaching source',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-detached-flowchart-edit-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final knowledgeRepository = ObjectBoxKnowledgeRepository(
        store: objectBox.store,
      );
      final noteRepository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
      );
      await noteRepository.load();
      final note = await noteRepository.createDocumentNote(
        title: 'Gyűjtő',
        document: NoteDocument.empty(),
      );
      final document = await knowledgeRepository.addImportedDocument(
        filename: 'detached-flowchart.pdf',
        localPath: '/memory/detached-flowchart.pdf',
        sizeBytes: 4,
        sha256: 'hash-detached-flowchart-edit',
      );
      await knowledgeRepository.saveFlowchartCandidate(
        documentPublicId: document.publicId,
        flowchart: const AiFlowchartCandidate(
          id: 'flow-1',
          pageNumber: 2,
          nodes: [
            AiFlowchartNode(id: 'keep', label: 'Megtartandó', order: 1),
            AiFlowchartNode(id: 'remove', label: 'Törlendő', order: 2),
          ],
          edges: [
            AiFlowchartEdge(
              id: 'route',
              fromNodeId: 'keep',
              toNodeId: 'remove',
              label: 'régi él',
              order: 1,
            ),
          ],
        ),
      );
      final chunkId = '${document.publicId}:flow-1';
      await noteRepository.linkChunksToNote(note.id, [chunkId]);
      final linkedChunk = (await noteRepository.listChunksForNote(
        note.id,
      )).single;
      final keepNode = linkedChunk.content.nodes.singleWhere(
        (node) => node.label == 'Megtartandó',
      );
      final removedNode = linkedChunk.content.nodes.singleWhere(
        (node) => node.label == 'Törlendő',
      );
      final retainedEdge = linkedChunk.content.edges.single;

      final validationRepository = ObjectBoxFlowchartValidationRepository(
        store: objectBox.store,
      );
      await validationRepository.updateNodeValidation(
        nodePublicId: keepNode.id,
        state: ValidationState.rejected,
        rejectionReason: 'Megőrzendő ellenőrzési állapot',
      );
      await validationRepository.updateEdgeValidation(
        edgePublicId: retainedEdge.id,
        state: ValidationState.rejected,
        rejectionReason: 'Megőrzendő élállapot',
      );

      await knowledgeRepository.deleteDocuments([document.publicId]);

      final edited = NoteBlock(
        id: chunkId,
        type: NoteBlockType.flowchart,
        title: 'Leválasztott, szerkesztett folyamat',
        nodes: [
          keepNode.copyWith(label: 'Frissített megtartott node'),
          NoteFlowchartNode(id: '$chunkId:new', label: 'Új node', order: 2),
        ],
        edges: [
          retainedEdge.copyWith(
            fromNodeId: keepNode.id,
            toNodeId: '$chunkId:new',
            label: 'frissített él',
          ),
        ],
      );
      await noteRepository.updateNoteDocument(
        note.id,
        title: note.title,
        document: NoteDocument(blocks: [edited]),
      );

      final parent = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere((chunk) => chunk.publicId == chunkId);
      expect(parent.documentPublicId, isEmpty);
      expect(
        objectBox.store
            .box<FlowchartEntity>()
            .getAll()
            .singleWhere((flowchart) => flowchart.publicId == chunkId)
            .documentPublicId,
        isEmpty,
      );

      final projectedNodes = objectBox.store
          .box<FlowchartNodeEntity>()
          .getAll()
          .where((node) => node.flowchartPublicId == chunkId)
          .toList(growable: false);
      expect(projectedNodes.map((node) => node.publicId).toSet(), {
        keepNode.id,
        '$chunkId:new',
      });
      expect(
        projectedNodes
            .singleWhere((node) => node.publicId == keepNode.id)
            .label,
        'Frissített megtartott node',
      );
      expect(
        projectedNodes
            .singleWhere((node) => node.publicId == keepNode.id)
            .validationState,
        ValidationState.rejected.wireName,
      );
      expect(
        projectedNodes.any((node) => node.publicId == removedNode.id),
        isFalse,
      );

      final projectedEdge = objectBox.store
          .box<FlowchartEdgeEntity>()
          .getAll()
          .singleWhere((edge) => edge.flowchartPublicId == chunkId);
      expect(projectedEdge.publicId, retainedEdge.id);
      expect(projectedEdge.fromNodePublicId, keepNode.id);
      expect(projectedEdge.toNodePublicId, '$chunkId:new');
      expect(projectedEdge.label, 'frissített él');
      expect(projectedEdge.validationState, ValidationState.rejected.wireName);
      expect(projectedEdge.rejectionReason, 'Megőrzendő élállapot');
    },
  );

  test(
    'same-id linked flowchart reprocessing reattaches canonical parent',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-flowchart-reattach-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final knowledgeRepository = ObjectBoxKnowledgeRepository(
        store: objectBox.store,
      );
      final noteRepository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
      );
      await noteRepository.load();
      final note = await noteRepository.createDocumentNote(
        title: 'Gyűjtő',
        document: NoteDocument.empty(),
      );
      final document = await knowledgeRepository.addImportedDocument(
        filename: 'reprocessed-flowchart.pdf',
        localPath: '/memory/reprocessed-flowchart.pdf',
        sizeBytes: 4,
        sha256: 'hash-reprocessed-flowchart',
      );
      await knowledgeRepository.saveFlowchartCandidate(
        documentPublicId: document.publicId,
        flowchart: const AiFlowchartCandidate(
          id: 'flow-1',
          pageNumber: 1,
          nodes: [AiFlowchartNode(id: 'start', label: 'Régi')],
          edges: [],
        ),
      );
      final chunkId = '${document.publicId}:flow-1';
      await noteRepository.linkChunksToNote(note.id, [chunkId]);

      await knowledgeRepository.clearGeneratedKnowledge(document.publicId);
      var parent = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere((chunk) => chunk.publicId == chunkId);
      expect(parent.documentPublicId, isEmpty);

      await knowledgeRepository.saveFlowchartCandidate(
        documentPublicId: document.publicId,
        flowchart: const AiFlowchartCandidate(
          id: 'flow-1',
          pageNumber: 3,
          nodes: [AiFlowchartNode(id: 'start', label: 'Újrafeldolgozott')],
          edges: [],
        ),
      );

      parent = objectBox.store.box<DocumentChunkEntity>().getAll().singleWhere(
        (chunk) => chunk.publicId == chunkId,
      );
      expect(parent.documentPublicId, document.publicId);
      expect(parent.sourcePublicId, document.publicId);
      expect(
        objectBox.store.box<ChunkNoteLinkEntity>().getAll().where(
          (link) =>
              link.notePublicId == note.id && link.chunkPublicId == chunkId,
        ),
        hasLength(1),
      );
      final canonical = (await noteRepository.listChunksForNote(
        note.id,
      )).single;
      expect(canonical.content.nodes.single.label, 'Újrafeldolgozott');
    },
  );

  test(
    'flowchart cleanup removes only projections for deleted canonical rows',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-flowchart-cleanup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'mixed-flowcharts.pdf',
        localPath: '/memory/mixed-flowcharts.pdf',
        sizeBytes: 4,
        sha256: 'hash-mixed-flowchart-cleanup',
      );
      const manualContent = NoteBlock(
        id: 'manual-flow',
        type: NoteBlockType.flowchart,
        nodes: [NoteFlowchartNode(id: 'manual-node', label: 'Kézi')],
      );
      const localContent = NoteBlock(
        id: 'local-flow',
        type: NoteBlockType.flowchart,
        nodes: [NoteFlowchartNode(id: 'local-node', label: 'Lokális')],
      );
      await repository.saveLocalChunks(document.publicId, [
        LocalChunk(
          id: 'manual-flow',
          documentId: document.publicId,
          text: manualContent.plainText,
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.flowchart,
          structuredContentJson: jsonEncode(manualContent.toJson()),
        ),
        LocalChunk(
          id: 'local-flow',
          documentId: document.publicId,
          text: localContent.plainText,
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localFlowchart,
          kind: LocalChunkKind.flowchart,
          structuredContentJson: jsonEncode(localContent.toJson()),
        ),
      ], replaceExisting: false);
      await repository.saveFlowchartCandidate(
        documentPublicId: document.publicId,
        flowchart: const AiFlowchartCandidate(
          id: 'ai-flow',
          pageNumber: 1,
          nodes: [AiFlowchartNode(id: 'ai-node', label: 'AI')],
          edges: [],
        ),
      );

      await repository.clearGeneratedKnowledge(document.publicId);
      var ids = (await repository.listExtractedKnowledgeItems(
        document.publicId,
      )).map((item) => item.id).toSet();
      expect(ids, containsAll(<String>{'manual-flow', 'local-flow'}));
      expect(ids, isNot(contains('ai-flow')));
      expect(
        objectBox.store
            .box<FlowchartEntity>()
            .getAll()
            .map((flowchart) => flowchart.publicId)
            .toSet(),
        containsAll(<String>{
          '${document.publicId}:manual-flow',
          '${document.publicId}:local-flow',
        }),
      );

      await repository.saveLocalChunks(document.publicId, const []);
      ids = (await repository.listExtractedKnowledgeItems(
        document.publicId,
      )).map((item) => item.id).toSet();
      expect(ids, contains('manual-flow'));
      expect(ids, isNot(contains('local-flow')));
      expect(
        objectBox.store
            .box<FlowchartEntity>()
            .getAll()
            .map((flowchart) => flowchart.publicId)
            .toSet(),
        contains('${document.publicId}:manual-flow'),
      );
      expect(
        objectBox.store
            .box<FlowchartEntity>()
            .getAll()
            .map((flowchart) => flowchart.publicId)
            .toSet(),
        isNot(contains('${document.publicId}:local-flow')),
      );
    },
  );

  test(
    'flowchart package import keeps semantic IDs tags and label fills aligned',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-flowchart-import-ids-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ObjectBoxStore objectBox;
      try {
        objectBox = await ObjectBoxStore.open(directory: directory);
      } on ArgumentError catch (error) {
        markTestSkipped('Host ObjectBox library unavailable: $error');
        return;
      }
      addTearDown(objectBox.close);

      final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
      final document = await repository.addImportedDocument(
        filename: 'import-flowchart.pdf',
        localPath: '/memory/import-flowchart.pdf',
        sizeBytes: 4,
        sha256: 'hash-flowchart-import',
      );
      const tag = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'fontos döntés',
      );
      const portableContent = NoteBlock(
        id: 'old-document:flow-main',
        type: NoteBlockType.flowchart,
        nodes: [
          NoteFlowchartNode(
            id: 'old-document:flow-main:decision',
            label: 'Döntés',
            ports: [
              NoteFlowchartPort(
                id: 'old-document:flow-main:decision:yes-port',
                side: NoteFlowchartPortSide.right,
              ),
            ],
            labelFills: [
              NoteTextFill(
                id: 'node-fill',
                start: 0,
                end: 6,
                colorValue: 0xFFFFE082,
              ),
            ],
          ),
          NoteFlowchartNode(
            id: 'old-document:flow-main:end',
            label: 'Vége',
            ports: [
              NoteFlowchartPort(
                id: 'old-document:flow-main:end:input-port',
                side: NoteFlowchartPortSide.left,
              ),
            ],
          ),
        ],
        edges: [
          NoteFlowchartEdge(
            id: 'old-document:flow-main:yes-edge',
            fromNodeId: 'old-document:flow-main:decision',
            toNodeId: 'old-document:flow-main:end',
            label: 'igen',
            fromPortId: 'old-document:flow-main:decision:yes-port',
            toPortId: 'old-document:flow-main:end:input-port',
            labelFills: [
              NoteTextFill(
                id: 'edge-fill',
                start: 0,
                end: 4,
                colorValue: 0xFFB3E5FC,
              ),
            ],
          ),
        ],
        scopedTags: [
          NoteScopedTagAssignment(
            id: 'node-tag',
            target: NoteTagTarget(
              kind: NoteTagTargetKind.flowchartNode,
              elementId: 'old-document:flow-main:decision',
            ),
            tags: [tag],
          ),
          NoteScopedTagAssignment(
            id: 'edge-tag',
            target: NoteTagTarget(
              kind: NoteTagTargetKind.flowchartEdge,
              elementId: 'old-document:flow-main:yes-edge',
            ),
            tags: [tag],
          ),
        ],
      );
      await repository.importChunkPackage(
        document.publicId,
        const ChunkPackage(
          schemaVersion: 2,
          documentHash: 'hash-flowchart-import',
          filename: 'import-flowchart.pdf',
          provider: '',
          extractionModel: '',
          embeddingModel: '',
          embeddingDimension: 0,
          chunks: [
            ChunkPackageItem(
              id: 'flow-main',
              text: 'Döntés',
              pageNumber: 1,
              sectionTitle: 'Folyamat',
              embedding: [],
              kind: ChunkKind.flowchartChunk,
              creationMethod: ChunkCreationMethod.imported,
              content: portableContent,
            ),
          ],
        ),
      );

      final exported = await repository.exportChunkPackage(document.publicId);
      final content = exported.chunks.single.content!;
      final decision = content.nodes.singleWhere(
        (node) => node.id.endsWith(':decision'),
      );
      final edge = content.edges.singleWhere(
        (item) => item.id.endsWith(':yes-edge'),
      );
      expect(edge.fromNodeId, decision.id);
      expect(
        edge.toNodeId,
        content.nodes.singleWhere((node) => node.id.endsWith(':end')).id,
      );
      expect(edge.fromPortId, decision.ports.single.id);
      expect(
        edge.toPortId,
        content.nodes
            .singleWhere((node) => node.id.endsWith(':end'))
            .ports
            .single
            .id,
      );
      expect(decision.labelFills.single.id, 'node-fill');
      expect(edge.labelFills.single.id, 'edge-fill');
      expect(
        content.scopedTags
            .singleWhere(
              (assignment) =>
                  assignment.target.kind == NoteTagTargetKind.flowchartNode,
            )
            .target
            .elementId,
        decision.id,
      );
      expect(
        content.scopedTags
            .singleWhere(
              (assignment) =>
                  assignment.target.kind == NoteTagTargetKind.flowchartEdge,
            )
            .target
            .elementId,
        edge.id,
      );
    },
  );

  test('keeps edited AI table content inside a canonical NoteChunk', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-objectbox-ai-table-update-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final ObjectBoxStore objectBox;
    try {
      objectBox = await ObjectBoxStore.open(directory: directory);
    } on ArgumentError catch (error) {
      markTestSkipped('Host ObjectBox library unavailable: $error');
      return;
    }
    addTearDown(objectBox.close);

    final repository = ObjectBoxKnowledgeRepository(store: objectBox.store);
    final document = await repository.addImportedDocument(
      filename: 'ai-table.pdf',
      localPath: '/memory/ai-table.pdf',
      sizeBytes: 4,
      sha256: 'hash-ai-table-update',
    );
    await repository.saveExtractedEvidence(
      documentPublicId: document.publicId,
      evidence: const AiExtractedEvidence(
        id: 'ai-table-1',
        text: 'A | B',
        pageNumber: 1,
        sourceType: AiEvidenceSourceType.table,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'test-embedding',
    );

    await repository.updateExtractedKnowledgeItem(
      document.publicId,
      'ai-table-1',
      text: 'A | B\n1 | 2',
    );

    final items = await repository.listExtractedKnowledgeItems(
      document.publicId,
    );
    final edited = items.singleWhere((item) => item.id == 'ai-table-1');
    expect(edited.sourceType, EvidenceSourceType.textChunk);
    expect(edited.chunkKind, LocalChunkKind.text);
    final stored = objectBox.store
        .box<DocumentChunkEntity>()
        .getAll()
        .singleWhere(
          (chunk) => chunk.publicId == '${document.publicId}:ai-table-1',
        );
    expect(stored.chunkKind, ChunkKind.noteChunk.wireName);
    expect(stored.structuredContentJson, contains('"type":"mixed"'));
    expect(edited.embeddingModel, isNull);
  });
}

String _graphKey(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? 'section' : normalized;
}
