import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';

void main() {
  setUp(DebugConsole.clear);

  test('expands vector hits through graph edges without keyword fallback', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-local-retriever-test-',
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

    final store = objectBox.store;
    store.box<DocumentChunkEntity>().putMany([
      DocumentChunkEntity(
        publicId: 'chunk-seed',
        documentPublicId: 'doc-1',
        text: 'Légzési elégtelenség fő szabály.',
        pageNumber: 1,
        pipeline: 'manual',
      ),
      DocumentChunkEntity(
        publicId: 'chunk-linked',
        documentPublicId: 'doc-1',
        text: 'Oxigénadás részletes szabálya.',
        pageNumber: 1,
        pipeline: 'manual',
      ),
    ]);
    store.box<ChunkEmbeddingEntity>().put(
      ChunkEmbeddingEntity(
        sourceId: 'chunk-seed',
        sourceType: EvidenceSourceType.textChunk.wireName,
        vector: List<double>.filled(3072, 0.1),
        model: 'test-embedding',
        createdAtMillis: 1,
      ),
    );
    store.box<KnowledgeEvidenceEntity>().putMany([
      KnowledgeEvidenceEntity(
        publicId: 'ev-seed',
        documentPublicId: 'doc-1',
        nodePublicId: 'node-seed',
        sourceId: 'chunk-seed',
        pipeline: 'manual',
      ),
      KnowledgeEvidenceEntity(
        publicId: 'ev-linked',
        documentPublicId: 'doc-1',
        nodePublicId: 'node-linked',
        sourceId: 'chunk-linked',
        pipeline: 'manual',
      ),
    ]);
    store.box<KnowledgeEdgeEntity>().put(
      KnowledgeEdgeEntity(
        publicId: 'edge-seed-linked',
        documentPublicId: 'doc-1',
        fromNodePublicId: 'node-seed',
        toNodePublicId: 'node-linked',
        relationType: 'continues',
        sourceId: 'chunk-seed',
      ),
    );

    final retriever = ObjectBoxLocalRetriever(store: store);
    final results = await retriever.retrieve(
      queryVector: List<double>.filled(3072, 0.1),
      limit: 4,
      minimumSimilarity: 0.7,
      query: 'random szó ami nem kulcsszavas egyezés',
    );

    expect(
      results.map((item) => item.id),
      containsAll(['chunk-seed', 'chunk-linked']),
    );
    expect(DebugConsole.allText, contains('[VectorGraph] graph expansion'));
    expect(
      DebugConsole.allText,
      contains('[VectorGraph] keyword expansion skipped reason=not_selected'),
    );
    expect(DebugConsole.allText, contains('graph=1'));
    expect(DebugConsole.allText, isNot(contains('[Offline] search start')));
  });

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
}
