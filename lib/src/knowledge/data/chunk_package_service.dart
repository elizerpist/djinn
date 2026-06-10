import '../models/chunk_package.dart';

class ChunkPackageException implements Exception {
  const ChunkPackageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChunkPackageService {
  const ChunkPackageService();

  void validateForImport(
    ChunkPackage package, {
    required String documentHash,
    required int expectedDimension,
  }) {
    if (package.schemaVersion != 1) {
      throw const ChunkPackageException('Unsupported chunk package schema.');
    }
    if (package.documentHash != documentHash) {
      throw const ChunkPackageException(
        'Document hash does not match package.',
      );
    }
    if (package.embeddingDimension != expectedDimension) {
      throw const ChunkPackageException('Embedding dimension mismatch.');
    }
    final chunkIds = <String>{};
    for (final chunk in package.chunks) {
      if (chunk.id.isEmpty) {
        throw const ChunkPackageException('Chunk id is missing.');
      }
      if (!chunkIds.add(chunk.id)) {
        throw const ChunkPackageException('Duplicate chunk id in package.');
      }
      if (chunk.embedding.length != package.embeddingDimension) {
        throw const ChunkPackageException(
          'Chunk embedding dimension mismatch.',
        );
      }
    }
  }
}
