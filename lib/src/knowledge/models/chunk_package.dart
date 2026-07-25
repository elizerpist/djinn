import '../../chunks/models/chunk.dart';
import '../../notes/models/note_document.dart';
import 'local_extraction.dart';

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
      'chunks': chunks
          .map((chunk) => chunk.toJson(schemaVersion: schemaVersion))
          .toList(),
    };
  }

  factory ChunkPackage.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    final chunks = json['chunks'];
    if (chunks is! List) {
      throw const FormatException('Chunk package chunks must be a list.');
    }
    return ChunkPackage(
      schemaVersion: schemaVersion,
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
            return ChunkPackageItem.fromJson(
              Map<String, Object?>.from(item),
              schemaVersion: schemaVersion,
            );
          })
          .toList(growable: false),
    );
  }
}

/// One portable embedding attached to a canonical chunk or one of its
/// structured flowchart elements.
///
/// [sourceId] is package-local. The parent uses the package chunk id; node and
/// edge records use their portable element id. This lets import remap global
/// ObjectBox ids without losing per-element model metadata.
class ChunkPackageEmbedding {
  const ChunkPackageEmbedding({
    required this.sourceId,
    required this.sourceType,
    required this.vector,
    required this.model,
  });

  final String sourceId;
  final String sourceType;
  final List<double> vector;
  final String model;

  Map<String, Object?> toJson() {
    return {
      'source_id': sourceId,
      'source_type': sourceType,
      'vector': vector,
      'model': model,
    };
  }

  factory ChunkPackageEmbedding.fromJson(Map<String, Object?> json) {
    final rawVector = json['vector'];
    if (rawVector is! List) {
      throw const FormatException(
        'Chunk package embedding vector must be a list.',
      );
    }
    return ChunkPackageEmbedding(
      sourceId: _requiredString(json, 'source_id'),
      sourceType: _requiredString(json, 'source_type'),
      vector: rawVector
          .map((value) {
            if (value is! num) {
              throw const FormatException(
                'Chunk package embedding values must be numeric.',
              );
            }
            return value.toDouble();
          })
          .toList(growable: false),
      model: _requiredString(json, 'model'),
    );
  }
}

/// One portable chunk row.
///
/// Schema v2 persists the complete, editable canonical chunk. The legacy
/// scalar fields remain present so v1 packages and older callers continue to
/// round-trip without a destructive migration.
class ChunkPackageItem {
  const ChunkPackageItem({
    required this.id,
    required this.text,
    required this.pageNumber,
    required this.sectionTitle,
    required this.embedding,
    this.kind = ChunkKind.noteChunk,
    this.creationMethod = ChunkCreationMethod.imported,
    this.validationState = LocalAuditState.accepted,
    this.source = const ChunkSource(),
    this.content,
    this.embeddingRecords = const [],
  });

  final String id;
  final String text;
  final int pageNumber;
  final String? sectionTitle;
  final List<double> embedding;
  final ChunkKind kind;
  final ChunkCreationMethod creationMethod;
  final LocalAuditState validationState;
  final ChunkSource source;
  final NoteBlock? content;
  final List<ChunkPackageEmbedding> embeddingRecords;

  NoteBlock get canonicalContent {
    final stored = content;
    if (kind == ChunkKind.flowchartChunk) {
      if (stored?.type == NoteBlockType.flowchart) {
        return stored!.copyWith(id: id);
      }
      return NoteBlock(
        id: id,
        type: NoteBlockType.flowchart,
        title: sectionTitle,
        text: stored?.plainText ?? text,
        tags: stored?.knownTags ?? const [],
      );
    }
    return normalizeLegacyNoteBlock(
      stored ?? NoteBlock(id: id, type: NoteBlockType.paragraph, text: text),
    ).copyWith(id: id);
  }

  ChunkPackageItem copyWith({
    String? id,
    String? text,
    int? pageNumber,
    String? sectionTitle,
    List<double>? embedding,
    ChunkKind? kind,
    ChunkCreationMethod? creationMethod,
    LocalAuditState? validationState,
    ChunkSource? source,
    NoteBlock? content,
    List<ChunkPackageEmbedding>? embeddingRecords,
  }) {
    return ChunkPackageItem(
      id: id ?? this.id,
      text: text ?? this.text,
      pageNumber: pageNumber ?? this.pageNumber,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      embedding: embedding ?? this.embedding,
      kind: kind ?? this.kind,
      creationMethod: creationMethod ?? this.creationMethod,
      validationState: validationState ?? this.validationState,
      source: source ?? this.source,
      content: content ?? this.content,
      embeddingRecords: embeddingRecords ?? this.embeddingRecords,
    );
  }

  Map<String, Object?> toJson({int schemaVersion = 2}) {
    final json = <String, Object?>{
      'id': id,
      'text': text,
      'page_number': pageNumber,
      'section_title': sectionTitle,
      'embedding': embedding,
    };
    if (schemaVersion >= 2) {
      final canonical = canonicalContent;
      json.addAll({
        'kind': kind.wireName,
        'creation_method': creationMethod.wireName,
        'validation_state': validationState.wireName,
        if (!source.isEmpty) 'source': source.toJson(),
        'content': canonical.toJson(),
        'plain_text': canonical.plainText,
        if (embeddingRecords.isNotEmpty)
          'embedding_records': embeddingRecords
              .map((embedding) => embedding.toJson())
              .toList(growable: false),
      });
    }
    return json;
  }

  factory ChunkPackageItem.fromJson(
    Map<String, Object?> json, {
    int schemaVersion = 1,
  }) {
    final embedding = json['embedding'];
    if (embedding is! List) {
      throw const FormatException('Chunk package embedding must be a list.');
    }
    final id = _requiredString(json, 'id');
    final text =
        _optionalString(json, 'plain_text') ?? _requiredString(json, 'text');
    final pageNumber = _requiredInt(json, 'page_number');
    final sectionTitle = _optionalString(json, 'section_title');
    final rawKind = _optionalString(json, 'kind');
    if (schemaVersion >= 2 &&
        rawKind != ChunkKind.noteChunk.wireName &&
        rawKind != ChunkKind.flowchartChunk.wireName) {
      throw const FormatException(
        'Schema 2 chunk kind must be note_chunk or flowchart_chunk.',
      );
    }
    final kind = ChunkKind.fromWireName(rawKind);
    final contentValue = json['content'];
    final content = schemaVersion >= 2
        ? _requiredCanonicalContent(contentValue, id: id, kind: kind)
        : _legacyContent(
            contentValue,
            id: id,
            text: text,
            sectionTitle: sectionTitle,
            legacyKind: rawKind,
            canonicalKind: kind,
          );
    final rawEmbeddingRecords = json['embedding_records'];
    final embeddingRecords = rawEmbeddingRecords == null
        ? const <ChunkPackageEmbedding>[]
        : rawEmbeddingRecords is List
        ? rawEmbeddingRecords
              .map((item) {
                if (item is! Map) {
                  throw const FormatException(
                    'Chunk package embedding record must be a map.',
                  );
                }
                return ChunkPackageEmbedding.fromJson(
                  Map<String, Object?>.from(item),
                );
              })
              .toList(growable: false)
        : throw const FormatException(
            'Chunk package embedding records must be a list.',
          );
    return ChunkPackageItem(
      id: id,
      text: text,
      pageNumber: pageNumber,
      sectionTitle: sectionTitle,
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
      kind: kind,
      creationMethod: schemaVersion >= 2
          ? ChunkCreationMethod.fromWireName(
              _requiredString(json, 'creation_method'),
            )
          : ChunkCreationMethod.imported,
      validationState: schemaVersion >= 2
          ? LocalAuditState.fromWireName(
              _requiredString(json, 'validation_state'),
            )
          : LocalAuditState.accepted,
      source: schemaVersion >= 2
          ? ChunkSource.fromJson(json['source'])
          : ChunkSource(
              sourceType: ChunkSourceType.pdf,
              pageStart: pageNumber > 0 ? pageNumber : null,
              originalText: text,
            ),
      content: content,
      embeddingRecords: embeddingRecords,
    );
  }
}

NoteBlock _requiredCanonicalContent(
  Object? value, {
  required String id,
  required ChunkKind kind,
}) {
  if (value is! Map) {
    throw const FormatException(
      'Schema 2 chunk content must be a JSON object.',
    );
  }
  final parsed = NoteBlock.fromJson(Map<String, Object?>.from(value));
  if (kind == ChunkKind.flowchartChunk) {
    if (parsed.type != NoteBlockType.flowchart) {
      throw const FormatException(
        'Flowchart chunk content must be a flowchart.',
      );
    }
    return parsed.copyWith(id: id);
  }
  if (parsed.type != NoteBlockType.mixed) {
    throw const FormatException('Note chunk content must be mixed content.');
  }
  return normalizeLegacyNoteBlock(parsed).copyWith(id: id);
}

NoteBlock _legacyContent(
  Object? value, {
  required String id,
  required String text,
  required String? sectionTitle,
  required String? legacyKind,
  required ChunkKind canonicalKind,
}) {
  if (value is Map) {
    final parsed = NoteBlock.fromJson(Map<String, Object?>.from(value));
    if (canonicalKind == ChunkKind.flowchartChunk) {
      return parsed.type == NoteBlockType.flowchart
          ? parsed.copyWith(id: id)
          : NoteBlock(
              id: id,
              type: NoteBlockType.flowchart,
              title: sectionTitle,
              text: parsed.plainText,
              tags: parsed.knownTags,
            );
    }
    if (parsed.type != NoteBlockType.flowchart) {
      return normalizeLegacyNoteBlock(parsed).copyWith(id: id);
    }
  }
  if (canonicalKind == ChunkKind.flowchartChunk) {
    return NoteBlock(
      id: id,
      type: NoteBlockType.flowchart,
      title: sectionTitle,
      text: text,
    );
  }
  final normalizedKind = legacyKind?.trim().toLowerCase();
  final legacyBlock = switch (normalizedKind) {
    'table' || 'table_chunk' || 'score' || 'score_chunk' => NoteBlock(
      id: id,
      type: NoteBlockType.table,
      rows: _legacyTableRows(text),
    ),
    'list' || 'list_item' => NoteBlock(
      id: id,
      type: NoteBlockType.listItem,
      listItems: [
        for (var index = 0; index < _legacyLines(text).length; index += 1)
          NoteListItem(
            id: '$id-item-${index + 1}',
            text: _legacyLines(text)[index],
          ),
      ],
    ),
    _ => NoteBlock(id: id, type: NoteBlockType.paragraph, text: text),
  };
  return normalizeLegacyNoteBlock(legacyBlock);
}

List<String> _legacyLines(String text) {
  return text
      .split('\n')
      .map(
        (line) =>
            line.trim().replaceFirst(RegExp(r'^([\-*•]|\d+[\.)])\s*'), ''),
      )
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

List<List<String>> _legacyTableRows(String text) {
  return text
      .split('\n')
      .map(
        (line) => line
            .split(RegExp(r'\s*\|\s*|\t'))
            .map((cell) => cell.trim())
            .toList(growable: false),
      )
      .where((row) => row.any((cell) => cell.isNotEmpty))
      .toList(growable: false);
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
