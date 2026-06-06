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
}
