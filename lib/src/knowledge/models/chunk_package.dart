class ChunkPackage {
  const ChunkPackage({
    required this.schemaVersion,
    required this.documentHash,
    required this.filename,
    required this.provider,
    required this.extractionModel,
    required this.embeddingModel,
    required this.embeddingDimension,
    required this.chunks,
  });

  final int schemaVersion;
  final String documentHash;
  final String filename;
  final String provider;
  final String extractionModel;
  final String embeddingModel;
  final int embeddingDimension;
  final List<ChunkPackageItem> chunks;

  Map<String, Object?> toJson() {
    return {
      'schema_version': schemaVersion,
      'document_hash': documentHash,
      'filename': filename,
      'provider': provider,
      'extraction_model': extractionModel,
      'embedding_model': embeddingModel,
      'embedding_dimension': embeddingDimension,
      'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
    };
  }

  factory ChunkPackage.fromJson(Map<String, Object?> json) {
    final chunks = json['chunks'];
    if (chunks is! List) {
      throw const FormatException('Chunk package chunks must be a list.');
    }
    return ChunkPackage(
      schemaVersion: _requiredInt(json, 'schema_version'),
      documentHash: _requiredString(json, 'document_hash'),
      filename: _requiredString(json, 'filename'),
      provider: _requiredString(json, 'provider'),
      extractionModel: _requiredString(json, 'extraction_model'),
      embeddingModel: _requiredString(json, 'embedding_model'),
      embeddingDimension: _requiredInt(json, 'embedding_dimension'),
      chunks: chunks
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Chunk package item must be a map.');
            }
            return ChunkPackageItem.fromJson(Map<String, Object?>.from(item));
          })
          .toList(growable: false),
    );
  }
}

class ChunkPackageItem {
  const ChunkPackageItem({
    required this.id,
    required this.text,
    required this.pageNumber,
    required this.sectionTitle,
    required this.embedding,
  });

  final String id;
  final String text;
  final int pageNumber;
  final String? sectionTitle;
  final List<double> embedding;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'text': text,
      'page_number': pageNumber,
      'section_title': sectionTitle,
      'embedding': embedding,
    };
  }

  factory ChunkPackageItem.fromJson(Map<String, Object?> json) {
    final embedding = json['embedding'];
    if (embedding is! List) {
      throw const FormatException('Chunk package embedding must be a list.');
    }
    return ChunkPackageItem(
      id: _requiredString(json, 'id'),
      text: _requiredString(json, 'text'),
      pageNumber: _requiredInt(json, 'page_number'),
      sectionTitle: _optionalString(json, 'section_title'),
      embedding: embedding
          .map((value) {
            if (value is! num) {
              throw const FormatException(
                'Chunk package embedding values must be numeric.',
              );
            }
            return value.toDouble();
          })
          .toList(growable: false),
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Chunk package field "$key" must be a string.');
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('Chunk package field "$key" must be a string.');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Chunk package field "$key" must be an integer.');
}
