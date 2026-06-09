import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';

void main() {
  setUp(DebugConsole.clear);

  test('retriever excludes rejected flowchart evidence', () async {
    final retriever = MemoryLocalRetriever(const [
      SourceEvidence(
        id: 'node-rejected',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Rejected',
        label: 'Nem validált flowchart',
        validationState: ValidationState.rejected,
        score: 0.99,
      ),
      SourceEvidence(
        id: 'chunk-accepted',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Accepted',
        label: 'Szöveges PDF-részlet',
        validationState: ValidationState.validated,
        score: 0.91,
      ),
    ]);

    final result = await retriever.retrieve(
      queryVector: List<double>.filled(3072, 0.1),
      limit: 5,
      minimumSimilarity: 0.7,
    );

    expect(result.map((item) => item.id), ['chunk-accepted']);
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] memory retrieval start dim=3072 limit=5 min=0.7'),
    );
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] memory skipped rejected source=node-rejected'),
    );
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] memory retrieval matches=1'),
    );
  });

  test('retriever excludes disabled documents and other collections', () async {
    final retriever = MemoryLocalRetriever(const [
      SourceEvidence(
        id: 'disabled',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Disabled',
        label: 'PDF',
        validationState: ValidationState.validated,
        documentId: 'doc-disabled',
        ragEnabled: false,
        collectionName: 'Stroke',
        score: 0.99,
      ),
      SourceEvidence(
        id: 'wrong-collection',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Wrong collection',
        label: 'PDF',
        validationState: ValidationState.validated,
        documentId: 'doc-other',
        collectionName: 'Trauma',
        score: 0.98,
      ),
      SourceEvidence(
        id: 'accepted',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Accepted',
        label: 'PDF',
        validationState: ValidationState.validated,
        documentId: 'doc-ok',
        collectionName: 'Stroke',
        score: 0.97,
      ),
    ]);

    final result = await retriever.retrieve(
      queryVector: List<double>.filled(3072, 0.1),
      limit: 5,
      minimumSimilarity: 0.7,
      collectionName: 'Stroke',
    );

    expect(result.map((item) => item.id), ['accepted']);
  });

  test(
    'objectbox retriever fetches extra nearest neighbors before filtering',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'djinn-ob-retriever-',
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

      final documents = objectBox.store.box<KnowledgeDocumentEntity>();
      final chunks = objectBox.store.box<DocumentChunkEntity>();
      final embeddings = objectBox.store.box<ChunkEmbeddingEntity>();
      documents.putMany([
        KnowledgeDocumentEntity(
          publicId: 'disabled-doc',
          filename: 'disabled.pdf',
          localPath: '/memory/disabled.pdf',
          sizeBytes: 1,
          importedAtMillis: 1,
          processingState: ProcessingState.ready.wireName,
          ragEnabled: false,
        ),
        KnowledgeDocumentEntity(
          publicId: 'enabled-doc',
          filename: 'enabled.pdf',
          localPath: '/memory/enabled.pdf',
          sizeBytes: 1,
          importedAtMillis: 1,
          processingState: ProcessingState.ready.wireName,
          ragEnabled: true,
        ),
      ]);
      chunks.putMany([
        DocumentChunkEntity(
          publicId: 'disabled-chunk',
          documentPublicId: 'disabled-doc',
          text: 'disabled',
          pageNumber: 1,
        ),
        DocumentChunkEntity(
          publicId: 'enabled-chunk',
          documentPublicId: 'enabled-doc',
          text: 'enabled',
          pageNumber: 1,
        ),
      ]);
      final query = List<double>.filled(3072, 0);
      query[0] = 1;
      final nearby = List<double>.filled(3072, 0);
      nearby[0] = 0.99;
      nearby[1] = 0.01;
      embeddings.putMany([
        ChunkEmbeddingEntity(
          sourceId: 'disabled-chunk',
          sourceType: EvidenceSourceType.textChunk.wireName,
          vector: query,
          model: 'text-embedding-3-large',
          createdAtMillis: 1,
        ),
        ChunkEmbeddingEntity(
          sourceId: 'enabled-chunk',
          sourceType: EvidenceSourceType.textChunk.wireName,
          vector: nearby,
          model: 'text-embedding-3-large',
          createdAtMillis: 1,
        ),
      ]);

      final result = await ObjectBoxLocalRetriever(
        store: objectBox.store,
      ).retrieve(queryVector: query, limit: 1, minimumSimilarity: 0.1);

      expect(result.map((item) => item.id), ['enabled-chunk']);
    },
  );
}
