import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/objectbox_knowledge_repository.dart';
import 'package:djinn/src/knowledge/data/training_pack_service.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/local_store/objectbox_store.dart';

void main() {
  test('re-importing a pack replaces old ObjectBox evidence', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-ob-pack-');
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
    await repository.upsertDocumentPack(
      _pack(
        id: 'old-doc',
        filename: 'old.pdf',
        chunkId: 'old-doc:p1-main',
        chunkText: 'old chunk',
        flowchartId: 'old-flow',
      ),
    );

    await repository.upsertDocumentPack(
      _pack(
        id: 'new-doc',
        filename: 'new.pdf',
        chunkId: 'new-doc:p1-main',
        chunkText: 'new chunk',
        flowchartId: 'new-flow',
      ),
    );

    final documents = await repository.listDocumentPacks();

    expect(documents, hasLength(1));
    expect(documents.single.filename, 'new.pdf');
    expect(documents.single.chunks.map((chunk) => chunk.id), [
      'new-doc:p1-main',
    ]);
    expect(documents.single.embeddings.map((embedding) => embedding.sourceId), [
      'new-doc:p1-main',
    ]);
    expect(documents.single.flowcharts.map((flowchart) => flowchart.id), [
      'new-flow',
    ]);
  });
}

TrainingPackDocument _pack({
  required String id,
  required String filename,
  required String chunkId,
  required String chunkText,
  required String flowchartId,
}) {
  return TrainingPackDocument(
    id: id,
    filename: filename,
    localPath: '/memory/$filename',
    sizeBytes: 10,
    importedAtMillis: 1760000000000,
    processingState: ProcessingState.ready.wireName,
    contentHash: 'same-hash',
    ragEnabled: true,
    collectionName: 'Alap',
    ocrStatus: 'text_available',
    chunks: [TrainingPackChunk(id: chunkId, text: chunkText, pageNumber: 1)],
    embeddings: [
      TrainingPackEmbedding(
        sourceId: chunkId,
        sourceType: EvidenceSourceType.textChunk.wireName,
        vector: List<double>.filled(3072, 0.1),
        model: 'text-embedding-3-large',
        createdAtMillis: 1760000000001,
      ),
    ],
    flowcharts: [
      TrainingPackFlowchart(
        id: flowchartId,
        pageNumber: 2,
        validationState: ValidationState.unreviewed.wireName,
        nodes: const [],
        edges: const [],
      ),
    ],
  );
}
