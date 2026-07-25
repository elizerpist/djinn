import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  group('canonical chunk model', () {
    test('exposes exactly NoteChunk and FlowchartChunk kinds', () {
      expect(ChunkKind.values, const [
        ChunkKind.noteChunk,
        ChunkKind.flowchartChunk,
      ]);
      expect(ChunkKind.fromWireName('text'), ChunkKind.noteChunk);
      expect(ChunkKind.fromWireName('list'), ChunkKind.noteChunk);
      expect(ChunkKind.fromWireName('table'), ChunkKind.noteChunk);
      expect(ChunkKind.fromWireName('mixed'), ChunkKind.noteChunk);
      expect(ChunkKind.fromWireName('score'), ChunkKind.noteChunk);
      expect(ChunkKind.fromWireName('flowchart'), ChunkKind.flowchartChunk);
    });

    test('creation method is metadata and maps legacy pipelines', () {
      expect(
        ChunkCreationMethod.fromWireName('manual'),
        ChunkCreationMethod.manualSelection,
      );
      expect(
        ChunkCreationMethod.fromWireName('local_ocr'),
        ChunkCreationMethod.assistedSelection,
      );
      expect(
        ChunkCreationMethod.fromWireName('ai'),
        ChunkCreationMethod.aiGenerated,
      );
      expect(
        ChunkCreationMethod.fromWireName('imported'),
        ChunkCreationMethod.imported,
      );
    });

    test('legacy paragraph, list and table become rich NoteChunk sections', () {
      final cases = <NoteBlock>[
        const NoteBlock(
          id: 'paragraph',
          type: NoteBlockType.paragraph,
          text: 'Bekezdés',
        ),
        const NoteBlock(
          id: 'list',
          type: NoteBlockType.listItem,
          listItems: [NoteListItem(id: 'item-1', text: 'Első')],
        ),
        const NoteBlock(
          id: 'table',
          type: NoteBlockType.table,
          rows: [
            ['A', 'B'],
          ],
        ),
      ];

      final migrated = cases
          .map(
            (block) => NoteChunk.fromLegacyBlock(
              block: block,
              creationMethod: ChunkCreationMethod.manualSelection,
              validationState: LocalAuditState.accepted,
            ),
          )
          .toList();

      expect(migrated.map((chunk) => chunk.kind).toSet(), {
        ChunkKind.noteChunk,
      });
      expect(migrated.map((chunk) => chunk.content.type).toSet(), {
        NoteBlockType.mixed,
      });
      expect(migrated.map((chunk) => chunk.content.mixedSections.single.type), [
        NoteMixedSectionType.paragraph,
        NoteMixedSectionType.list,
        NoteMixedSectionType.table,
      ]);
      expect(migrated.map((chunk) => chunk.plainText), [
        'Bekezdés',
        'Első',
        'A | B',
      ]);
    });

    test('legacy block title is retained once as chunk metadata', () {
      final chunk = NoteChunk.fromLegacyBlock(
        block: const NoteBlock(
          id: 'titled-paragraph',
          type: NoteBlockType.paragraph,
          title: 'Fejezetcím',
          text: 'Tartalom',
        ),
        creationMethod: ChunkCreationMethod.imported,
        validationState: LocalAuditState.accepted,
      );

      expect(chunk.content.title, 'Fejezetcím');
      expect(chunk.content.mixedSections.single.title, isNull);
      expect(RegExp('Fejezetcím').allMatches(chunk.plainText), hasLength(1));
      expect(chunk.plainText, 'Fejezetcím\n\nTartalom');
    });

    test('canonical JSON round-trip never exports legacy chunk kinds', () {
      final chunk = NoteChunk.fromLegacyBlock(
        block: const NoteBlock(
          id: 'legacy-table',
          type: NoteBlockType.table,
          rows: [
            ['Név', 'Érték'],
            ['Pulzus', '80'],
          ],
        ),
        creationMethod: ChunkCreationMethod.aiGenerated,
        validationState: LocalAuditState.unreviewed,
        source: const ChunkSource(
          sourceType: ChunkSourceType.pdf,
          sourceId: 'document-1',
          pageStart: 4,
          pageEnd: 5,
        ),
      );

      final payload = chunk.toJson();
      final encoded = jsonEncode(payload);
      final decoded = Chunk.fromJson(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );

      expect(payload['kind'], 'note_chunk');
      expect(encoded, isNot(contains('"kind":"table"')));
      expect(encoded, isNot(contains('"kind":"text"')));
      expect(decoded, isA<NoteChunk>());
      expect(decoded.creationMethod, ChunkCreationMethod.aiGenerated);
      expect(decoded.source.pageStart, 4);
      expect(decoded.plainText, contains('Pulzus | 80'));
    });

    test('flowchart remains the only second chunk kind', () {
      final chunk = FlowchartChunk(
        id: 'flow-1',
        creationMethod: ChunkCreationMethod.assistedSelection,
        validationState: LocalAuditState.edited,
        content: const NoteBlock(
          id: 'flow-1',
          type: NoteBlockType.flowchart,
          nodes: [
            NoteFlowchartNode(id: 'start', label: 'Kezdés'),
            NoteFlowchartNode(id: 'end', label: 'Vége'),
          ],
          edges: [
            NoteFlowchartEdge(
              id: 'edge-1',
              fromNodeId: 'start',
              toNodeId: 'end',
              label: 'következő',
            ),
          ],
        ),
      );

      final decoded = Chunk.fromJson(chunk.toJson());

      expect(chunk.kind, ChunkKind.flowchartChunk);
      expect(chunk.toJson()['kind'], 'flowchart_chunk');
      expect(decoded, isA<FlowchartChunk>());
      expect(decoded.plainText, contains('Kezdés -> Vége [következő]'));
    });
  });
}
