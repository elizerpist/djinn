import 'dart:convert';

import '../../knowledge/models/local_extraction.dart';
import '../../local_store/entities.dart';
import '../../notes/models/note_document.dart';
import '../models/chunk.dart';

/// Compatibility codec over the UID-stable ObjectBox chunk entity.
///
/// `DocumentChunkEntity` intentionally keeps its physical name for one
/// migration window. It is the single global chunk table for both notes and
/// imported sources; its legacy name does not imply a PDF-only data model.
class ChunkEntityCodec {
  const ChunkEntityCodec();

  Chunk decode(DocumentChunkEntity entity) {
    final kind = ChunkKind.fromWireName(entity.chunkKind);
    final decodedContent = _contentFromEntity(entity, kind);
    var content = decodedContent.content;
    final storedTags = _tagsFromJson(entity.tagsJson);
    if (!decodedContent.wasStructured && storedTags.isNotEmpty) {
      content = content.copyWith(tags: storedTags);
    }
    final storedSourceType = ChunkSourceType.fromWireName(entity.sourceType);
    final hasPdfProjection = entity.documentPublicId.trim().isNotEmpty;
    final sourceType =
        storedSourceType == ChunkSourceType.none && hasPdfProjection
        ? ChunkSourceType.pdf
        : storedSourceType;
    final source = ChunkSource(
      sourceType: sourceType,
      sourceId:
          entity.sourcePublicId ??
          (hasPdfProjection ? entity.documentPublicId : null),
      pageStart: entity.pageNumber > 0 ? entity.pageNumber : null,
      pageEnd: entity.endPageNumber,
      sourceRectJson: entity.sourceRectJson,
      originalText: entity.originalText ?? entity.text,
    );
    final creationMethod = ChunkCreationMethod.fromWireName(
      entity.creationMethod ?? entity.pipeline,
    );
    final validationState = LocalAuditState.fromWireName(entity.auditState);
    final createdAt = _dateFromMillis(entity.createdAtMillis);
    final updatedAt = _dateFromMillis(entity.updatedAtMillis);
    return switch (kind) {
      ChunkKind.noteChunk => NoteChunk.fromLegacyBlock(
        block: content.type == NoteBlockType.flowchart
            ? NoteBlock(
                id: entity.publicId,
                type: NoteBlockType.paragraph,
                text: content.plainText,
                tags: content.tags,
              )
            : content,
        creationMethod: creationMethod,
        validationState: validationState,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      ChunkKind.flowchartChunk => FlowchartChunk(
        id: entity.publicId,
        creationMethod: creationMethod,
        validationState: validationState,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
        content: content.type == NoteBlockType.flowchart
            ? content.copyWith(id: entity.publicId)
            : NoteBlock(
                id: entity.publicId,
                type: NoteBlockType.flowchart,
                title: entity.sectionTitle,
                text: content.plainText,
                tags: content.tags,
              ),
      ),
    };
  }

  /// Mutates a legacy entity into canonical wire values.
  ///
  /// Returns true exactly when persistence is required, making migration
  /// retries deterministic and cheap.
  bool canonicalize(DocumentChunkEntity entity, {required DateTime now}) {
    final before = _entityFingerprint(entity);
    final chunk = decode(entity);
    write(
      entity,
      chunk,
      now: now,
      keepExistingOriginalText: true,
      keepExistingCreatedAt: true,
      keepExistingUpdatedAt: true,
    );
    return before != _entityFingerprint(entity);
  }

  void write(
    DocumentChunkEntity entity,
    Chunk chunk, {
    required DateTime now,
    bool keepExistingOriginalText = true,
    bool keepExistingCreatedAt = true,
    bool keepExistingUpdatedAt = false,
  }) {
    final timestamp = now.millisecondsSinceEpoch;
    entity.publicId = chunk.id;
    entity.chunkKind = chunk.kind.wireName;
    entity.creationMethod = chunk.creationMethod.wireName;
    entity.sourceType = chunk.source.sourceType.wireName;
    entity.sourcePublicId = chunk.source.sourceId;
    entity.auditState = chunk.validationState.wireName;
    entity.text = chunk.plainText;
    entity.sectionTitle = chunk.content.title;
    // `tagsJson` is an aggregate compatibility/search projection. Explicit
    // chunk-level versus scoped assignments remain authoritative inside
    // structuredContentJson; decode never overlays this aggregate onto valid
    // structured content.
    entity.tagsJson = _tagsToJson(chunk.content.knownTags);
    entity.structuredContentJson = jsonEncode(chunk.content.toJson());
    entity.originalText = keepExistingOriginalText
        ? entity.originalText ?? chunk.source.originalText ?? entity.text
        : chunk.source.originalText ?? entity.text;
    entity.createdAtMillis = keepExistingCreatedAt
        ? entity.createdAtMillis ??
              chunk.createdAt?.millisecondsSinceEpoch ??
              timestamp
        : chunk.createdAt?.millisecondsSinceEpoch ?? timestamp;
    entity.updatedAtMillis = keepExistingUpdatedAt
        ? entity.updatedAtMillis ??
              chunk.updatedAt?.millisecondsSinceEpoch ??
              timestamp
        : chunk.updatedAt?.millisecondsSinceEpoch ?? timestamp;
    entity.endPageNumber = chunk.source.pageEnd;
    entity.sourceRectJson = chunk.source.sourceRectJson;
    if (chunk.source.sourceType == ChunkSourceType.pdf) {
      // `documentPublicId` is the live source-projection relation, while
      // `sourcePublicId` above is immutable provenance. Never reconstruct the
      // former from the latter: linked chunks deliberately retain provenance
      // after their source document has been deleted.
      entity.pageNumber = chunk.source.pageStart ?? entity.pageNumber;
    }
  }

  ({NoteBlock content, bool wasStructured}) _contentFromEntity(
    DocumentChunkEntity entity,
    ChunkKind kind,
  ) {
    final structured = entity.structuredContentJson;
    if (structured != null && structured.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(structured);
        if (decoded is Map) {
          final json = Map<String, Object?>.from(decoded);
          if (json.containsKey('kind') && json['content'] is Map) {
            return (
              content: Chunk.fromJson(
                json,
              ).content.copyWith(id: entity.publicId),
              wasStructured: true,
            );
          }
          return (
            content: NoteBlock.fromJson(json).copyWith(id: entity.publicId),
            wasStructured: true,
          );
        }
      } catch (_) {
        // Corrupt legacy structured data falls back to its plain-text
        // projection; the original string remains untouched until a verified
        // canonical row is written.
      }
    }
    if (kind == ChunkKind.flowchartChunk) {
      return (
        content: NoteBlock(
          id: entity.publicId,
          type: NoteBlockType.flowchart,
          title: entity.sectionTitle,
          text: entity.text,
        ),
        wasStructured: false,
      );
    }
    final legacyKind = entity.chunkKind.trim().toLowerCase();
    if (legacyKind == 'table' ||
        legacyKind == 'table_chunk' ||
        legacyKind == 'score' ||
        legacyKind == 'score_chunk') {
      return (
        content: NoteBlock(
          id: entity.publicId,
          type: NoteBlockType.table,
          title: entity.sectionTitle,
          rows: _tableRows(entity.text),
        ),
        wasStructured: false,
      );
    }
    if (legacyKind == 'list' || legacyKind == 'list_item') {
      final lines = entity.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return (
        content: NoteBlock(
          id: entity.publicId,
          type: NoteBlockType.listItem,
          title: entity.sectionTitle,
          listItems: [
            for (var index = 0; index < lines.length; index += 1)
              NoteListItem(
                id: '${entity.publicId}-item-${index + 1}',
                text: lines[index].replaceFirst(
                  RegExp(r'^([\-*•]|\d+[\.)])\s*'),
                  '',
                ),
              ),
          ],
        ),
        wasStructured: false,
      );
    }
    return (
      content: NoteBlock(
        id: entity.publicId,
        type: NoteBlockType.paragraph,
        title: entity.sectionTitle,
        text: entity.text,
      ),
      wasStructured: false,
    );
  }

  List<List<String>> _tableRows(String value) {
    return value
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

  String? _tagsToJson(List<NoteKnowledgeTag> tags) {
    if (tags.isEmpty) {
      return null;
    }
    return jsonEncode([for (final tag in tags) tag.toJson()]);
  }

  List<NoteKnowledgeTag> _tagsFromJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .map(NoteKnowledgeTag.fromJson)
          .where((tag) => tag.label.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _entityFingerprint(DocumentChunkEntity entity) {
    return jsonEncode({
      'id': entity.id,
      'publicId': entity.publicId,
      'documentPublicId': entity.documentPublicId,
      'text': entity.text,
      'pageNumber': entity.pageNumber,
      'endPageNumber': entity.endPageNumber,
      'sectionTitle': entity.sectionTitle,
      'sourceRectJson': entity.sourceRectJson,
      'pipeline': entity.pipeline,
      'chunkKind': entity.chunkKind,
      'auditState': entity.auditState,
      'tagsJson': entity.tagsJson,
      'structuredContentJson': entity.structuredContentJson,
      'creationMethod': entity.creationMethod,
      'sourceType': entity.sourceType,
      'sourcePublicId': entity.sourcePublicId,
      'originalText': entity.originalText,
      'createdAtMillis': entity.createdAtMillis,
      'updatedAtMillis': entity.updatedAtMillis,
    });
  }
}

DateTime? _dateFromMillis(int? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(value);
}
