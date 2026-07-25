import '../../knowledge/models/local_extraction.dart';
import '../../notes/models/note_document.dart';

/// The only two persisted, user-visible chunk kinds in Djinn.
enum ChunkKind {
  noteChunk('note_chunk'),
  flowchartChunk('flowchart_chunk');

  const ChunkKind(this.wireName);

  final String wireName;

  static ChunkKind fromWireName(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'flowchart' ||
      'flowchart_chunk' ||
      'flowchart_node' ||
      'flowchart_edge' => ChunkKind.flowchartChunk,
      'note_chunk' ||
      'text' ||
      'text_chunk' ||
      'paragraph' ||
      'heading' ||
      'list' ||
      'list_item' ||
      'table' ||
      'table_chunk' ||
      'score' ||
      'score_chunk' ||
      'mixed' ||
      'image_region' ||
      'visual_fact' ||
      null ||
      _ => ChunkKind.noteChunk,
    };
  }
}

/// Describes how the initial chunk boundary/content was produced.
///
/// This is provenance metadata only. It must never select a different chunk
/// store, card, editor, or validation flow.
enum ChunkCreationMethod {
  manualSelection('manual_selection'),
  assistedSelection('assisted_selection'),
  aiGenerated('ai_generated'),
  imported('imported');

  const ChunkCreationMethod(this.wireName);

  final String wireName;

  static ChunkCreationMethod fromWireName(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'manual' || 'manual_selection' => ChunkCreationMethod.manualSelection,
      'assisted' ||
      'assisted_selection' ||
      'local_pdf_text' ||
      'local_ocr' ||
      'local_table' ||
      'local_flowchart' ||
      'local_visual' => ChunkCreationMethod.assistedSelection,
      'ai' || 'ai_generated' => ChunkCreationMethod.aiGenerated,
      'import' || 'imported' || null || _ => ChunkCreationMethod.imported,
    };
  }
}

enum ChunkSourceType {
  none('none'),
  note('note'),
  pdf('pdf'),
  image('image'),
  importedFile('imported_file');

  const ChunkSourceType(this.wireName);

  final String wireName;

  static ChunkSourceType fromWireName(String? value) {
    return ChunkSourceType.values.firstWhere(
      (item) => item.wireName == value,
      orElse: () => ChunkSourceType.none,
    );
  }
}

class ChunkSource {
  const ChunkSource({
    this.sourceType = ChunkSourceType.none,
    this.sourceId,
    this.pageStart,
    this.pageEnd,
    this.sourceRectJson,
    this.originalText,
  });

  final ChunkSourceType sourceType;
  final String? sourceId;
  final int? pageStart;
  final int? pageEnd;
  final String? sourceRectJson;
  final String? originalText;

  bool get isEmpty =>
      sourceType == ChunkSourceType.none &&
      sourceId == null &&
      pageStart == null &&
      pageEnd == null &&
      sourceRectJson == null &&
      originalText == null;

  factory ChunkSource.fromJson(Object? value) {
    if (value is! Map) {
      return const ChunkSource();
    }
    final json = Map<Object?, Object?>.from(value);
    return ChunkSource(
      sourceType: ChunkSourceType.fromWireName(
        json['source_type']?.toString() ?? json['sourceType']?.toString(),
      ),
      sourceId: _optionalString(json['source_id'] ?? json['sourceId']),
      pageStart: _optionalInt(json['page_start'] ?? json['pageStart']),
      pageEnd: _optionalInt(json['page_end'] ?? json['pageEnd']),
      sourceRectJson: _optionalString(
        json['source_rect_json'] ?? json['sourceRectJson'],
      ),
      originalText: _optionalString(
        json['original_text'] ?? json['originalText'],
      ),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'source_type': sourceType.wireName,
      if (sourceId != null) 'source_id': sourceId,
      if (pageStart != null) 'page_start': pageStart,
      if (pageEnd != null) 'page_end': pageEnd,
      if (sourceRectJson != null) 'source_rect_json': sourceRectJson,
      if (originalText != null) 'original_text': originalText,
    };
  }
}

sealed class Chunk {
  const Chunk({
    required this.id,
    required this.creationMethod,
    required this.validationState,
    this.source = const ChunkSource(),
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final ChunkCreationMethod creationMethod;
  final LocalAuditState validationState;
  final ChunkSource source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChunkKind get kind;
  NoteBlock get content;
  String get plainText => content.plainText;

  Map<String, Object?> toJson();

  static Chunk fromJson(Map<String, Object?> json) {
    final kind = ChunkKind.fromWireName(json['kind']?.toString());
    final contentValue = json['content'];
    if (contentValue is! Map) {
      throw const FormatException('Chunk content must be a JSON object.');
    }
    final content = NoteBlock.fromJson(Map<String, Object?>.from(contentValue));
    final id = json['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Chunk id must not be empty.');
    }
    final creationMethod = ChunkCreationMethod.fromWireName(
      json['creation_method']?.toString() ?? json['creationMethod']?.toString(),
    );
    final validationState = LocalAuditState.fromWireName(
      json['validation_state']?.toString() ??
          json['validationState']?.toString(),
    );
    final source = ChunkSource.fromJson(json['source']);
    final createdAt = _optionalDateTime(
      json['created_at'] ?? json['createdAt'],
    );
    final updatedAt = _optionalDateTime(
      json['updated_at'] ?? json['updatedAt'],
    );
    return switch (kind) {
      ChunkKind.noteChunk => NoteChunk(
        id: id,
        creationMethod: creationMethod,
        validationState: validationState,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
        content: normalizeLegacyNoteBlock(content),
      ),
      ChunkKind.flowchartChunk => FlowchartChunk(
        id: id,
        creationMethod: creationMethod,
        validationState: validationState,
        source: source,
        createdAt: createdAt,
        updatedAt: updatedAt,
        content: content.type == NoteBlockType.flowchart
            ? content
            : NoteBlock(
                id: content.id,
                type: NoteBlockType.flowchart,
                title: content.title,
                text: content.plainText,
                tags: content.tags,
              ),
      ),
    };
  }

  Map<String, Object?> baseJson() {
    return {
      'schema_version': 2,
      'id': id,
      'kind': kind.wireName,
      'creation_method': creationMethod.wireName,
      'validation_state': validationState.wireName,
      if (!source.isEmpty) 'source': source.toJson(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'content': content.toJson(),
      'plain_text': plainText,
    };
  }
}

final class NoteChunk extends Chunk {
  NoteChunk({
    required super.id,
    required super.creationMethod,
    required super.validationState,
    required this.content,
    super.source,
    super.createdAt,
    super.updatedAt,
  }) : assert(content.type == NoteBlockType.mixed);

  @override
  final NoteBlock content;

  @override
  ChunkKind get kind => ChunkKind.noteChunk;

  factory NoteChunk.fromLegacyBlock({
    required NoteBlock block,
    required ChunkCreationMethod creationMethod,
    required LocalAuditState validationState,
    ChunkSource source = const ChunkSource(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    if (block.type == NoteBlockType.flowchart) {
      throw ArgumentError.value(
        block.type,
        'block.type',
        'Flowchart content must be stored in FlowchartChunk.',
      );
    }
    return NoteChunk(
      id: block.id,
      creationMethod: creationMethod,
      validationState: validationState,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
      content: normalizeLegacyNoteBlock(block),
    );
  }

  @override
  Map<String, Object?> toJson() => baseJson();
}

final class FlowchartChunk extends Chunk {
  FlowchartChunk({
    required super.id,
    required super.creationMethod,
    required super.validationState,
    required this.content,
    super.source,
    super.createdAt,
    super.updatedAt,
  }) : assert(content.type == NoteBlockType.flowchart);

  @override
  final NoteBlock content;

  @override
  ChunkKind get kind => ChunkKind.flowchartChunk;

  @override
  Map<String, Object?> toJson() => baseJson();
}

/// Converts every legacy non-flowchart block representation into one rich
/// NoteChunk payload without discarding its structure or search metadata.
NoteBlock normalizeLegacyNoteBlock(NoteBlock block) {
  if (block.type == NoteBlockType.flowchart) {
    throw ArgumentError.value(
      block.type,
      'block.type',
      'Flowchart content cannot be normalized as NoteChunk.',
    );
  }
  if (block.type == NoteBlockType.mixed) {
    final sections = block.mixedSections.isEmpty
        ? [
            NoteMixedSection(
              id: '${block.id}-section-1',
              type: NoteMixedSectionType.paragraph,
              text: block.text,
              rangeTags: block.rangeTags,
              textFills: block.textFills,
              paragraphStyles: block.paragraphStyles,
              scopedTags: block.scopedTags,
            ),
          ]
        : block.mixedSections;
    return block.copyWith(
      type: NoteBlockType.mixed,
      text: '',
      mixedSections: sections,
    );
  }

  final section = switch (block.type) {
    NoteBlockType.heading || NoteBlockType.paragraph => NoteMixedSection(
      id: '${block.id}-section-1',
      type: NoteMixedSectionType.paragraph,
      text: block.text,
      paragraphRole: block.type == NoteBlockType.heading
          ? NoteMixedParagraphRole.heading
          : NoteMixedParagraphRole.paragraph,
      paragraphIndentLevel: block.level,
      rangeTags: block.rangeTags,
      textFills: block.textFills,
      paragraphStyles: block.paragraphStyles,
      scopedTags: block.scopedTags,
    ),
    NoteBlockType.listItem => NoteMixedSection(
      id: '${block.id}-section-1',
      type: NoteMixedSectionType.list,
      text: block.text,
      listItems: block.listItems,
      listLayoutMode: block.listLayoutMode,
      textFills: block.textFills,
      scopedTags: block.scopedTags,
    ),
    NoteBlockType.table => NoteMixedSection(
      id: '${block.id}-section-1',
      type: NoteMixedSectionType.table,
      rows: block.rows,
      tableColumnWidths: block.tableColumnWidths,
      tableRowHeights: block.tableRowHeights,
      textFills: block.textFills,
      scopedTags: block.scopedTags,
    ),
    NoteBlockType.flowchart || NoteBlockType.mixed => throw StateError(
      'Unexpected block type during NoteChunk normalization.',
    ),
  };

  return NoteBlock(
    id: block.id,
    type: NoteBlockType.mixed,
    title: block.title,
    searchContext: block.searchContext,
    searchRole: block.searchRole,
    searchAliases: block.searchAliases,
    tags: block.tags,
    mixedSections: [section],
    indexedContentHash: block.indexedContentHash,
    indexedAt: block.indexedAt,
  );
}

String? _optionalString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

int? _optionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _optionalDateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '');
}
