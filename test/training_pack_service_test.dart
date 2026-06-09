import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/training_pack_service.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('exports documents, chunks, embeddings, and flowcharts', () async {
    final repository = MemoryTrainingPackRepository.seeded();
    final service = TrainingPackService(
      repository: repository,
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );

    final jsonText = await service.exportPack();
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;
    final documents = decoded['documents'] as List;
    final document = documents.single as Map<String, Object?>;

    expect(decoded['schema_version'], 1);
    expect(decoded['exported_at'], '2026-01-01T12:00:00.000Z');
    expect(document['content_hash'], 'hash-1');
    expect(document['chunks'], isNotEmpty);
    expect(document['embeddings'], isNotEmpty);
    expect(document['flowcharts'], isNotEmpty);
  });

  test(
    'imports matching content hash by updating instead of duplicating',
    () async {
      final source = MemoryTrainingPackRepository.seeded();
      final target = MemoryTrainingPackRepository.empty();
      await target.upsertDocumentPack(
        TrainingPackDocument(
          id: 'existing',
          filename: 'old.pdf',
          localPath: '',
          sizeBytes: 1,
          importedAtMillis: 1,
          processingState: ProcessingState.imported.wireName,
          contentHash: 'hash-1',
          ragEnabled: false,
          collectionName: 'Old',
          ocrStatus: 'unknown',
          chunks: const [],
          embeddings: const [],
          flowcharts: const [],
        ),
      );

      final exported = await TrainingPackService(
        repository: source,
      ).exportPack();
      await TrainingPackService(repository: target).importPack(exported);

      expect(target.documents, hasLength(1));
      expect(target.documents.single.filename, 'protocol.pdf');
      expect(
        target.documents.single.processingState,
        ProcessingState.ready.wireName,
      );
      expect(target.documents.single.chunks, hasLength(1));
    },
  );
}

class MemoryTrainingPackRepository implements TrainingPackRepository {
  MemoryTrainingPackRepository._(this.documents);

  factory MemoryTrainingPackRepository.empty() {
    return MemoryTrainingPackRepository._([]);
  }

  factory MemoryTrainingPackRepository.seeded() {
    return MemoryTrainingPackRepository._([
      TrainingPackDocument(
        id: 'doc-1',
        filename: 'protocol.pdf',
        localPath: '/memory/protocol.pdf',
        sizeBytes: 123,
        importedAtMillis: 1760000000000,
        processingState: ProcessingState.ready.wireName,
        contentHash: 'hash-1',
        ragEnabled: true,
        collectionName: 'Stroke',
        ocrStatus: 'text_available',
        trainedAtMillis: 1760000000100,
        packVersion: 1,
        chunks: const [
          TrainingPackChunk(
            id: 'doc-1:p1-main',
            text: 'ABCDE protocol',
            pageNumber: 1,
            sectionTitle: 'ABCDE',
          ),
        ],
        embeddings: [
          TrainingPackEmbedding(
            sourceId: 'doc-1:p1-main',
            sourceType: EvidenceSourceType.textChunk.wireName,
            vector: List<double>.filled(3072, 0.1),
            model: 'text-embedding-3-large',
            createdAtMillis: 1760000000200,
          ),
        ],
        flowcharts: const [
          TrainingPackFlowchart(
            id: 'flow-1',
            pageNumber: 2,
            validationState: 'unreviewed',
            extractionConfidence: 0.8,
            nodes: [
              TrainingPackFlowchartNode(
                id: 'node-1',
                label: 'Airway',
                validationState: 'unreviewed',
              ),
            ],
            edges: [],
          ),
        ],
      ),
    ]);
  }

  final List<TrainingPackDocument> documents;

  @override
  Future<List<TrainingPackDocument>> listDocumentPacks() async {
    return List.unmodifiable(documents);
  }

  @override
  Future<void> upsertDocumentPack(TrainingPackDocument document) async {
    final index = documents.indexWhere(
      (item) => item.contentHash == document.contentHash,
    );
    if (index == -1) {
      documents.add(document);
    } else {
      documents[index] = document;
    }
  }
}
