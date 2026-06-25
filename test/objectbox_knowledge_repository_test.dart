import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/objectbox_knowledge_repository.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';

void main() {
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
      expect(chunk.chunkKind, LocalChunkKind.table.wireName);
      expect(chunk.auditState, LocalAuditState.edited.wireName);

      final audit = objectBox.store
          .box<ExtractionAuditItemEntity>()
          .getAll()
          .singleWhere((item) => item.sourceId == sourceId);
      expect(audit.previewText, 'Új táblázat');
      expect(audit.title, 'Új cím');
      expect(audit.itemKind, LocalChunkKind.table.wireName);

      final node = objectBox.store
          .box<KnowledgeNodeEntity>()
          .getAll()
          .singleWhere((item) => item.publicId == '$sourceId:node');
      expect(node.label, 'Új cím');
      expect(node.nodeType, LocalChunkKind.table.wireName);

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
    'keeps edited AI table chunks typed as tables without embeddings',
    () async {
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
      expect(edited.sourceType, EvidenceSourceType.tableChunk);
      expect(edited.chunkKind, LocalChunkKind.table);
      expect(edited.embeddingModel, isNull);
    },
  );
}

String _graphKey(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? 'section' : normalized;
}
