import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('embedding entity keeps 3072 dimensional vectors', () {
    final entity = ChunkEmbeddingEntity(
      sourceId: 'chunk-1',
      sourceType: EvidenceSourceType.textChunk.wireName,
      vector: List<double>.filled(3072, 0.25),
      model: 'text-embedding-3-large',
      createdAtMillis: 1760000000000,
    );

    expect(entity.vector, hasLength(3072));
    expect(entity.sourceType, 'text_chunk');
    expect(entity.model, 'text-embedding-3-large');
  });

  test('validation state wire names are stable', () {
    expect(ValidationState.unreviewed.wireName, 'unreviewed');
    expect(ValidationState.partiallyValidated.wireName, 'partially_validated');
    expect(ValidationState.validated.wireName, 'validated');
    expect(ValidationState.rejected.wireName, 'rejected');
  });

  test('knowledge document entity carries folder hash and retry metadata', () {
    final entity = KnowledgeDocumentEntity(
      publicId: 'doc-1',
      filename: 'a.pdf',
      localPath: '/memory/a.pdf',
      sizeBytes: 10,
      importedAtMillis: 1760000000000,
      processingState: ProcessingState.imported.wireName,
      folderPublicId: 'folder-1',
      sha256: 'hash-a',
      activeProvider: 'gemini',
      activeModel: 'gemini-2.5-flash',
      lastErrorCode: 'networkAbort',
      retryable: true,
    );

    expect(entity.folderPublicId, 'folder-1');
    expect(entity.sha256, 'hash-a');
    expect(entity.activeProvider, 'gemini');
    expect(entity.activeModel, 'gemini-2.5-flash');
    expect(entity.lastErrorCode, 'networkAbort');
    expect(entity.retryable, isTrue);
  });

  test('knowledge folder entity stores stable public id and timestamps', () {
    final entity = KnowledgeFolderEntity(
      publicId: 'folder-1',
      name: 'Eljárásrendek',
      createdAtMillis: 1760000000000,
      updatedAtMillis: 1760000000100,
    );

    expect(entity.publicId, 'folder-1');
    expect(entity.name, 'Eljárásrendek');
    expect(entity.sortOrder, 0);
  });
}
