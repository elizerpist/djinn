import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chunks/data/chunk_entity_codec.dart';
import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('legacy table storage row becomes canonical rich NoteChunk', () {
    final entity = DocumentChunkEntity(
      publicId: 'pdf-1:table-1',
      documentPublicId: 'pdf-1',
      text: 'Név | Érték\nPulzus | 80',
      pageNumber: 3,
      pipeline: 'local_table',
      chunkKind: 'table',
      auditState: 'unreviewed',
      structuredContentJson: jsonEncode(
        const NoteBlock(
          id: 'table-1',
          type: NoteBlockType.table,
          rows: [
            ['Név', 'Érték'],
            ['Pulzus', '80'],
          ],
        ).toJson(),
      ),
    );

    final chunk = const ChunkEntityCodec().decode(entity);

    expect(chunk, isA<NoteChunk>());
    expect(chunk.kind, ChunkKind.noteChunk);
    expect(chunk.creationMethod, ChunkCreationMethod.assistedSelection);
    expect(chunk.content.type, NoteBlockType.mixed);
    expect(chunk.content.mixedSections.single.type, NoteMixedSectionType.table);
    expect(chunk.source.sourceType, ChunkSourceType.pdf);
    expect(chunk.source.sourceId, 'pdf-1');
    expect(chunk.source.pageStart, 3);
  });

  test(
    'canonicalization is idempotent and keeps the legacy entity identity',
    () {
      final entity = DocumentChunkEntity(
        id: 42,
        publicId: 'pdf-1:text-1',
        documentPublicId: 'pdf-1',
        text: 'Szöveg',
        pageNumber: 1,
        pipeline: 'ai',
        chunkKind: 'text',
        auditState: 'accepted',
      );
      final codec = const ChunkEntityCodec();

      final firstChanged = codec.canonicalize(
        entity,
        now: DateTime.utc(2026, 7, 25),
      );
      final snapshot = jsonEncode({
        'id': entity.id,
        'publicId': entity.publicId,
        'kind': entity.chunkKind,
        'creationMethod': entity.creationMethod,
        'originalText': entity.originalText,
        'structured': entity.structuredContentJson,
        'createdAt': entity.createdAtMillis,
        'updatedAt': entity.updatedAtMillis,
      });
      final secondChanged = codec.canonicalize(
        entity,
        now: DateTime.utc(2030, 1, 1),
      );

      expect(firstChanged, isTrue);
      expect(secondChanged, isFalse);
      expect(entity.id, 42);
      expect(entity.publicId, 'pdf-1:text-1');
      expect(entity.chunkKind, 'note_chunk');
      expect(entity.creationMethod, 'ai_generated');
      expect(
        jsonEncode({
          'id': entity.id,
          'publicId': entity.publicId,
          'kind': entity.chunkKind,
          'creationMethod': entity.creationMethod,
          'originalText': entity.originalText,
          'structured': entity.structuredContentJson,
          'createdAt': entity.createdAtMillis,
          'updatedAt': entity.updatedAtMillis,
        }),
        snapshot,
      );
    },
  );

  test('non-PDF source metadata survives the ObjectBox entity round trip', () {
    final entity = DocumentChunkEntity(
      publicId: 'note-1:chunk-1',
      documentPublicId: '',
      text: '',
      pageNumber: 0,
    );
    const codec = ChunkEntityCodec();
    final chunk = NoteChunk(
      id: entity.publicId,
      creationMethod: ChunkCreationMethod.imported,
      validationState: LocalAuditState.edited,
      source: const ChunkSource(
        sourceType: ChunkSourceType.note,
        sourceId: 'note-1',
        originalText: 'Eredeti jegyzetszöveg',
      ),
      content: const NoteBlock(
        id: 'note-1:chunk-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'section-1',
            type: NoteMixedSectionType.paragraph,
            text: 'Szerkesztett jegyzetszöveg',
          ),
        ],
      ),
    );

    codec.write(entity, chunk, now: DateTime.utc(2026, 7, 25));
    final decoded = codec.decode(entity);

    expect(entity.sourceType, ChunkSourceType.note.wireName);
    expect(entity.sourcePublicId, 'note-1');
    expect(decoded.source.sourceType, ChunkSourceType.note);
    expect(decoded.source.sourceId, 'note-1');
    expect(decoded.source.originalText, 'Eredeti jegyzetszöveg');
  });

  test(
    'canonicalization keeps a linked PDF chunk detached from a deleted source',
    () {
      final entity = DocumentChunkEntity(
        publicId: 'deleted-pdf:chunk-1',
        documentPublicId: '',
        text: 'Megőrzött tudás',
        pageNumber: 4,
        pipeline: LocalExtractionPipeline.manual.wireName,
        chunkKind: ChunkKind.noteChunk.wireName,
        auditState: LocalAuditState.edited.wireName,
        sourceType: ChunkSourceType.pdf.wireName,
        sourcePublicId: 'deleted-pdf',
      );
      const codec = ChunkEntityCodec();

      codec.canonicalize(entity, now: DateTime.utc(2026, 7, 25));
      final decoded = codec.decode(entity);

      expect(entity.documentPublicId, isEmpty);
      expect(decoded.source.sourceType, ChunkSourceType.pdf);
      expect(decoded.source.sourceId, 'deleted-pdf');
      expect(decoded.source.pageStart, 4);
    },
  );

  test(
    'structured scoped tags never become top-level tags during round trip',
    () {
      const scopedTag = NoteKnowledgeTag(
        id: 'tag-range',
        type: NoteKnowledgeTagTypes.topic,
        label: 'Csak kijelölt rész',
      );
      final content = const NoteBlock(
        id: 'note-1:chunk-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'section-1',
            type: NoteMixedSectionType.paragraph,
            text: 'Kijelölt szöveg',
            rangeTags: [
              NoteTextRangeTag(id: 'range-1', start: 0, end: 8, tag: scopedTag),
            ],
          ),
        ],
      );
      final entity = DocumentChunkEntity(
        publicId: content.id,
        documentPublicId: '',
        text: content.plainText,
        pageNumber: 0,
        chunkKind: ChunkKind.noteChunk.wireName,
        structuredContentJson: jsonEncode(content.toJson()),
        // Simulates a row written by the previously faulty aggregate projection.
        tagsJson: jsonEncode([scopedTag.toJson()]),
      );
      const codec = ChunkEntityCodec();

      final decoded = codec.decode(entity);
      expect(decoded.content.tags, isEmpty);
      expect(
        decoded.content.mixedSections.single.rangeTags.single.resolvedTags
            .map((item) => item.toJson())
            .toList(),
        [scopedTag.toJson()],
      );

      codec.write(entity, decoded, now: DateTime.utc(2026, 7, 25));
      expect(entity.tagsJson, isNotNull);

      final restarted = codec.decode(entity);
      expect(restarted.content.tags, isEmpty);
      expect(
        restarted.content.mixedSections.single.rangeTags.single.resolvedTags
            .map((item) => item.toJson())
            .toList(),
        [scopedTag.toJson()],
      );
    },
  );

  test('legacy unstructured tags remain top-level chunk tags', () {
    const tag = NoteKnowledgeTag(
      id: 'legacy-tag',
      type: NoteKnowledgeTagTypes.topic,
      label: 'Legacy',
    );
    final entity = DocumentChunkEntity(
      publicId: 'legacy-text',
      documentPublicId: '',
      text: 'Régi szöveg',
      pageNumber: 0,
      chunkKind: 'text',
      tagsJson: jsonEncode([tag.toJson()]),
    );

    final decoded = const ChunkEntityCodec().decode(entity);

    expect(decoded.content.tags.map((item) => item.toJson()).toList(), [
      tag.toJson(),
    ]);
  });
}
