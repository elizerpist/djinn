import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chunks/data/chunk_entity_codec.dart';
import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/notes/data/objectbox_note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';

void main() {
  test(
    'new note flowcharts project immediately on create and update',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-note-flowchart-projection-',
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

      final repository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
      );
      await repository.load();

      final created = await repository.createDocumentNote(
        title: 'Létrehozott flowchart',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'created-flow',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(id: 'start', label: 'Kezdés'),
                NoteFlowchartNode(id: 'end', label: 'Vége'),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'created-edge',
                  fromNodeId: 'start',
                  toNodeId: 'end',
                  label: 'tovább',
                ),
              ],
            ),
          ],
        ),
      );
      final createdChunk = (await repository.listChunksForNote(
        created.id,
      )).single;
      _expectFlowchartProjection(
        objectBox,
        chunkId: createdChunk.id,
        nodeLabels: const {'Kezdés', 'Vége'},
        edgeLabels: const {'tovább'},
      );

      final updated = await repository.createDocumentNote(
        title: 'Frissítendő flowchart',
        document: NoteDocument.empty(),
      );
      await repository.updateNoteDocument(
        updated.id,
        title: updated.title,
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'updated-flow',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(id: 'input', label: 'Bemenet'),
                NoteFlowchartNode(id: 'output', label: 'Kimenet'),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'updated-edge',
                  fromNodeId: 'input',
                  toNodeId: 'output',
                  label: 'eredmény',
                ),
              ],
            ),
          ],
        ),
      );
      final updatedChunk = (await repository.listChunksForNote(
        updated.id,
      )).single;
      _expectFlowchartProjection(
        objectBox,
        chunkId: updatedChunk.id,
        nodeLabels: const {'Bemenet', 'Kimenet'},
        edgeLabels: const {'eredmény'},
      );
    },
  );

  test(
    'legacy notes flowcharts project immediately during idempotent migration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-legacy-note-flowchart-projection-',
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

      final legacyFile = File('${directory.path}/notes/notes.json');
      await legacyFile.parent.create(recursive: true);
      await legacyFile.writeAsString(
        jsonEncode({
          'folders': const [],
          'notes': [
            NoteItem(
              id: 'legacy-flowchart-note',
              type: NoteItemType.document,
              title: 'Legacy flowchart',
              plainText: 'Régi kezdet Régi vég',
              payloadJson: const NoteDocument(
                blocks: [
                  NoteBlock(
                    id: 'legacy-flow',
                    type: NoteBlockType.flowchart,
                    nodes: [
                      NoteFlowchartNode(id: 'old-start', label: 'Régi kezdet'),
                      NoteFlowchartNode(id: 'old-end', label: 'Régi vég'),
                    ],
                    edges: [
                      NoteFlowchartEdge(
                        id: 'old-edge',
                        fromNodeId: 'old-start',
                        toNodeId: 'old-end',
                        label: 'régi út',
                      ),
                    ],
                  ),
                ],
              ).toPayloadJson(),
              auditState: LocalAuditState.accepted,
              createdAt: DateTime.utc(2025, 1, 1),
              updatedAt: DateTime.utc(2025, 1, 2),
            ).toJson(),
          ],
        }),
      );

      final repository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: legacyFile,
      );
      await repository.load();
      final migratedChunk = (await repository.listChunksForNote(
        'legacy-flowchart-note',
      )).single;
      _expectFlowchartProjection(
        objectBox,
        chunkId: migratedChunk.id,
        nodeLabels: const {'Régi kezdet', 'Régi vég'},
        edgeLabels: const {'régi út'},
      );

      await repository.load();
      expect(
        objectBox.store.box<ChunkNoteLinkEntity>().getAll().where(
          (link) =>
              link.notePublicId == 'legacy-flowchart-note' &&
              link.chunkPublicId == migratedChunk.id,
        ),
        hasLength(1),
      );
      _expectFlowchartProjection(
        objectBox,
        chunkId: migratedChunk.id,
        nodeLabels: const {'Régi kezdet', 'Régi vég'},
        edgeLabels: const {'régi út'},
      );
    },
  );

  test(
    'migrates legacy notes once and keeps one chunk row across collectors',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-unified-notes-',
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

      final legacyFile = File('${directory.path}/notes/notes.json');
      await legacyFile.parent.create(recursive: true);
      final legacyNote = NoteItem(
        id: 'legacy-note-1',
        type: NoteItemType.document,
        title: 'Legacy',
        plainText: 'A | B',
        payloadJson: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['A', 'B'],
              ],
            ),
          ],
        ).toPayloadJson(),
        auditState: LocalAuditState.edited,
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 2),
      );
      await legacyFile.writeAsString(
        jsonEncode({
          'folders': const [],
          'notes': [legacyNote.toJson()],
        }),
      );
      objectBox.store.box<DocumentChunkEntity>().put(
        DocumentChunkEntity(
          publicId: 'pdf-1:chunk-1',
          documentPublicId: 'pdf-1',
          text: 'PDF tartalom',
          pageNumber: 4,
          pipeline: 'ai',
          chunkKind: 'text',
          auditState: 'accepted',
        ),
      );

      final repository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: legacyFile,
        clock: () => DateTime.utc(2026, 7, 25),
      );
      await repository.load();
      await repository.load();

      final notes = await repository.listNotes();
      expect(notes.single.id, 'legacy-note-1');
      expect(notes.single.document.blocks.single.type, NoteBlockType.mixed);
      expect(
        notes.single.document.blocks.single.mixedSections.single.type,
        NoteMixedSectionType.table,
      );
      expect(
        objectBox.store.box<DataMigrationEntity>().getAll().where(
          (marker) =>
              marker.publicId == ObjectBoxNoteRepository.legacyMigrationKey,
        ),
        hasLength(1),
      );

      final second = await repository.createDocumentNote(
        title: 'Második',
        document: NoteDocument.empty(),
      );
      await repository.linkChunksToNote(notes.single.id, const [
        'pdf-1:chunk-1',
      ]);
      await repository.linkChunksToNote(second.id, const ['pdf-1:chunk-1']);
      await repository.linkChunksToNote(second.id, const ['pdf-1:chunk-1']);

      final secondWithLinkedPdf = (await repository.listNotes()).singleWhere(
        (note) => note.id == second.id,
      );
      await repository.updateNoteDocument(
        second.id,
        title: 'Átnevezett második',
        document: secondWithLinkedPdf.document,
      );

      expect(
        objectBox.store.box<DocumentChunkEntity>().getAll().where(
          (chunk) => chunk.publicId == 'pdf-1:chunk-1',
        ),
        hasLength(1),
      );
      expect(
        objectBox.store.box<ChunkNoteLinkEntity>().getAll().where(
          (link) => link.chunkPublicId == 'pdf-1:chunk-1',
        ),
        hasLength(2),
      );
      final canonicalPdf = objectBox.store
          .box<DocumentChunkEntity>()
          .getAll()
          .singleWhere((chunk) => chunk.publicId == 'pdf-1:chunk-1');
      expect(canonicalPdf.chunkKind, ChunkKind.noteChunk.wireName);
      expect(
        canonicalPdf.creationMethod,
        ChunkCreationMethod.aiGenerated.wireName,
      );
      expect(
        canonicalPdf.auditState,
        LocalAuditState.accepted.wireName,
        reason:
            'A collector note save must not overwrite a shared PDF chunk '
            'validation state.',
      );

      final importedNotes = await repository.importNotes([
        NoteItem(
          id: 'external-note-id',
          type: NoteItemType.document,
          title: 'Importált',
          plainText: 'Külső tartalom',
          payloadJson: const NoteDocument(
            blocks: [
              NoteBlock(
                id: 'external-block',
                type: NoteBlockType.paragraph,
                text: 'Külső tartalom',
              ),
            ],
          ).toPayloadJson(),
          auditState: LocalAuditState.accepted,
          createdAt: DateTime.utc(2024, 1, 1),
          updatedAt: DateTime.utc(2024, 1, 2),
        ),
      ]);
      final importedChunk = (await repository.listChunksForNote(
        importedNotes.single.id,
      )).single;
      expect(importedChunk.creationMethod, ChunkCreationMethod.imported);
      expect(importedChunk.source.sourceType, ChunkSourceType.importedFile);
      expect(importedChunk.source.sourceId, 'external-note-id');
    },
  );

  test(
    'editing a linked PDF chunk invalidates embeddings and refreshes projections',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-note-derived-data-',
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

      final repository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
        clock: () => DateTime.utc(2026, 7, 25),
      );
      await repository.load();
      final note = await repository.createDocumentNote(
        title: 'Gyűjtő',
        document: NoteDocument.empty(),
      );
      const sourceId = 'pdf-derived:chunk-1';
      final chunkEntity = DocumentChunkEntity(
        publicId: sourceId,
        documentPublicId: 'pdf-derived',
        text: '',
        pageNumber: 2,
      );
      const ChunkEntityCodec().write(
        chunkEntity,
        NoteChunk(
          id: sourceId,
          creationMethod: ChunkCreationMethod.assistedSelection,
          validationState: LocalAuditState.accepted,
          source: ChunkSource(
            sourceType: ChunkSourceType.pdf,
            sourceId: 'pdf-derived',
            pageStart: 2,
            originalText: 'Régi szöveg',
          ),
          content: NoteBlock(
            id: sourceId,
            type: NoteBlockType.mixed,
            title: 'Régi cím',
            mixedSections: [
              NoteMixedSection(
                id: 'section-1',
                type: NoteMixedSectionType.paragraph,
                text: 'Régi szöveg',
              ),
            ],
          ),
        ),
        now: DateTime.utc(2026, 7, 25),
      );
      objectBox.store.box<DocumentChunkEntity>().put(chunkEntity);
      await repository.linkChunksToNote(note.id, const [sourceId]);

      objectBox.store.box<ChunkEmbeddingEntity>().putMany([
        ChunkEmbeddingEntity(
          sourceId: sourceId,
          sourceType: EvidenceSourceType.textChunk.wireName,
          vector: List<double>.filled(3072, 0.1),
          model: 'stale-parent',
          createdAtMillis: 1,
        ),
        ChunkEmbeddingEntity(
          sourceId: '$sourceId:node-1',
          sourceType: EvidenceSourceType.flowchartNode.wireName,
          vector: List<double>.filled(3072, 0.2),
          model: 'stale-descendant',
          createdAtMillis: 1,
        ),
      ]);
      objectBox.store.box<KnowledgeNodeEntity>().put(
        KnowledgeNodeEntity(
          publicId: '$sourceId:node',
          documentPublicId: 'pdf-derived',
          label: 'Régi cím',
          nodeType: ChunkKind.noteChunk.wireName,
          pageNumber: 2,
          sourceId: sourceId,
        ),
      );
      objectBox.store.box<KnowledgeEvidenceEntity>().put(
        KnowledgeEvidenceEntity(
          publicId: '$sourceId:evidence',
          documentPublicId: 'pdf-derived',
          nodePublicId: '$sourceId:node',
          sourceId: sourceId,
          pipeline: ChunkCreationMethod.assistedSelection.wireName,
          pageNumber: 2,
          quote: 'Régi szöveg',
        ),
      );
      objectBox.store.box<ExtractionAuditItemEntity>().put(
        ExtractionAuditItemEntity(
          publicId: '$sourceId:audit',
          documentPublicId: 'pdf-derived',
          sourceId: sourceId,
          itemKind: ChunkKind.noteChunk.wireName,
          auditState: LocalAuditState.accepted.wireName,
          createdAtMillis: 1,
          pageNumber: 2,
          title: 'Régi cím',
          previewText: 'Régi szöveg',
        ),
      );

      final opened = (await repository.listNotes()).singleWhere(
        (item) => item.id == note.id,
      );
      final updatedDocument = opened.document.copyWith(
        blocks: [
          for (final block in opened.document.blocks)
            if (block.id == sourceId)
              block.copyWith(
                title: 'Új cím',
                mixedSections: const [
                  NoteMixedSection(
                    id: 'section-1',
                    type: NoteMixedSectionType.paragraph,
                    text: 'Új szöveg',
                  ),
                ],
                clearIndex: true,
              )
            else
              block,
        ],
      );

      await repository.updateNoteDocument(
        note.id,
        title: opened.title,
        document: updatedDocument,
      );

      expect(
        objectBox.store.box<ChunkEmbeddingEntity>().getAll().where(
          (embedding) =>
              embedding.sourceId == sourceId ||
              embedding.sourceId.startsWith('$sourceId:'),
        ),
        isEmpty,
      );
      expect(
        objectBox.store
            .box<KnowledgeNodeEntity>()
            .getAll()
            .singleWhere((node) => node.sourceId == sourceId)
            .label,
        'Új cím',
      );
      expect(
        objectBox.store
            .box<KnowledgeEvidenceEntity>()
            .getAll()
            .singleWhere((evidence) => evidence.sourceId == sourceId)
            .quote,
        'Új szöveg',
      );
      final audit = objectBox.store
          .box<ExtractionAuditItemEntity>()
          .getAll()
          .singleWhere((item) => item.sourceId == sourceId);
      expect(audit.title, 'Új cím');
      expect(audit.previewText, 'Új szöveg');
    },
  );

  test('note export omits page number together with source metadata', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-objectbox-note-source-free-export-',
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

    final repository = ObjectBoxNoteRepository(
      store: objectBox.store,
      legacyFile: File('${directory.path}/missing-notes.json'),
    );
    await repository.load();
    final note = await repository.createDocumentNote(
      title: 'Forrásos export',
      document: NoteDocument.empty(),
    );
    const sourceId = 'source-pdf:chunk-7';
    final chunkEntity = DocumentChunkEntity(
      publicId: sourceId,
      documentPublicId: 'source-pdf',
      text: 'Forrásos tartalom',
      pageNumber: 7,
    );
    const ChunkEntityCodec().write(
      chunkEntity,
      NoteChunk(
        id: sourceId,
        creationMethod: ChunkCreationMethod.assistedSelection,
        validationState: LocalAuditState.accepted,
        source: ChunkSource(
          sourceType: ChunkSourceType.pdf,
          sourceId: 'source-pdf',
          pageStart: 7,
          originalText: 'Forrásos tartalom',
        ),
        content: NoteBlock(
          id: sourceId,
          type: NoteBlockType.paragraph,
          text: 'Forrásos tartalom',
        ),
      ),
      now: DateTime.utc(2026, 7, 25),
    );
    objectBox.store.box<DocumentChunkEntity>().put(chunkEntity);
    await repository.linkChunksToNote(note.id, const [sourceId]);

    final package = await repository.exportChunkPackageForNote(
      note.id,
      includeSourceMetadata: false,
    );

    expect(package.chunks.single.source.isEmpty, isTrue);
    expect(package.chunks.single.pageNumber, 0);
  });

  test(
    'note export preserves parent and flowchart element embeddings',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-objectbox-note-export-',
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

      final repository = ObjectBoxNoteRepository(
        store: objectBox.store,
        legacyFile: File('${directory.path}/missing-notes.json'),
      );
      await repository.load();
      final note = await repository.createDocumentNote(
        title: 'Export',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'local-flow',
              type: NoteBlockType.flowchart,
              nodes: [NoteFlowchartNode(id: 'node-1', label: 'Kezdés')],
            ),
          ],
        ),
      );
      final chunk = (await repository.listChunksForNote(note.id)).single;
      objectBox.store.box<ChunkEmbeddingEntity>().putMany([
        ChunkEmbeddingEntity(
          sourceId: chunk.id,
          sourceType: 'flowchart',
          vector: List<double>.filled(3072, 0.1),
          model: 'parent-model',
          createdAtMillis: 1,
        ),
        ChunkEmbeddingEntity(
          sourceId: '${chunk.id}:node-1',
          sourceType: EvidenceSourceType.flowchartNode.wireName,
          vector: List<double>.filled(3072, 0.2),
          model: 'node-model',
          createdAtMillis: 1,
        ),
      ]);

      final package = await repository.exportChunkPackageForNote(
        note.id,
        includeSourceMetadata: false,
      );

      expect(package.embeddingDimension, 3072);
      expect(package.embeddingModel, isEmpty);
      expect(package.chunks.single.embedding, hasLength(3072));
      expect(package.chunks.single.embeddingRecords, hasLength(2));
      expect(
        package.chunks.single.embeddingRecords
            .map((item) => item.model)
            .toSet(),
        {'parent-model', 'node-model'},
      );
      expect(package.chunks.single.source.isEmpty, isTrue);
    },
  );
}

void _expectFlowchartProjection(
  ObjectBoxStore objectBox, {
  required String chunkId,
  required Set<String> nodeLabels,
  required Set<String> edgeLabels,
}) {
  expect(
    objectBox.store.box<FlowchartEntity>().getAll().where(
      (flowchart) => flowchart.publicId == chunkId,
    ),
    hasLength(1),
  );
  final nodes = objectBox.store
      .box<FlowchartNodeEntity>()
      .getAll()
      .where((node) => node.flowchartPublicId == chunkId)
      .toList(growable: false);
  expect(nodes.map((node) => node.label).toSet(), nodeLabels);
  final nodeIds = nodes.map((node) => node.publicId).toSet();
  final edges = objectBox.store
      .box<FlowchartEdgeEntity>()
      .getAll()
      .where((edge) => edge.flowchartPublicId == chunkId)
      .toList(growable: false);
  expect(edges.map((edge) => edge.label).toSet(), edgeLabels);
  expect(
    edges.every(
      (edge) =>
          nodeIds.contains(edge.fromNodePublicId) &&
          nodeIds.contains(edge.toNodePublicId),
    ),
    isTrue,
  );
}
