import '../../chunks/models/chunk.dart';
import '../../notes/models/note_document.dart';
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
    if (package.schemaVersion != 1 && package.schemaVersion != 2) {
      throw const ChunkPackageException('Unsupported chunk package schema.');
    }
    if (package.documentHash != documentHash) {
      throw const ChunkPackageException(
        'Document hash does not match package.',
      );
    }
    if (package.embeddingDimension != 0 &&
        expectedDimension != 0 &&
        package.embeddingDimension != expectedDimension) {
      throw const ChunkPackageException('Embedding dimension mismatch.');
    }
    final chunkIds = <String>{};
    final requiredEmbeddingDimension = package.embeddingDimension != 0
        ? package.embeddingDimension
        : expectedDimension;
    for (final chunk in package.chunks) {
      if (chunk.id.isEmpty) {
        throw const ChunkPackageException('Chunk id is missing.');
      }
      if (!chunkIds.add(chunk.id)) {
        throw const ChunkPackageException('Duplicate chunk id in package.');
      }
      if (package.schemaVersion >= 2) {
        final content = chunk.content;
        if (content == null) {
          throw const ChunkPackageException(
            'Schema 2 chunk content is missing.',
          );
        }
        if (chunk.kind == ChunkKind.noteChunk &&
            content.type != NoteBlockType.mixed) {
          throw const ChunkPackageException(
            'Note chunk content must be mixed content.',
          );
        }
        if (chunk.kind == ChunkKind.flowchartChunk &&
            content.type != NoteBlockType.flowchart) {
          throw const ChunkPackageException(
            'Flowchart chunk content must be a flowchart.',
          );
        }
      }
      if (requiredEmbeddingDimension != 0 &&
          chunk.embedding.isNotEmpty &&
          chunk.embedding.length != requiredEmbeddingDimension) {
        throw const ChunkPackageException(
          'Chunk embedding dimension mismatch.',
        );
      }
      if (package.schemaVersion == 1 &&
          chunk.embedding.length != package.embeddingDimension) {
        throw const ChunkPackageException(
          'Chunk embedding dimension mismatch.',
        );
      }
      final embeddingKeys = <String>{};
      for (final embedding in chunk.embeddingRecords) {
        if (embedding.sourceId.trim().isEmpty ||
            embedding.sourceType.trim().isEmpty ||
            embedding.model.trim().isEmpty ||
            embedding.vector.isEmpty) {
          throw const ChunkPackageException(
            'Chunk embedding record is incomplete.',
          );
        }
        if (!embeddingKeys.add(
          '${embedding.sourceType}:${embedding.sourceId}',
        )) {
          throw const ChunkPackageException(
            'Duplicate chunk embedding record.',
          );
        }
        if (requiredEmbeddingDimension != 0 &&
            embedding.vector.length != requiredEmbeddingDimension) {
          throw const ChunkPackageException(
            'Chunk embedding dimension mismatch.',
          );
        }
      }
    }
  }
}
