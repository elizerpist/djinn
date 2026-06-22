import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('serializes mixed note document and derives searchable text', () {
    final document = NoteDocument(
      blocks: [
        const NoteBlock(
          id: 'h1',
          type: NoteBlockType.heading,
          text: 'COPD kiváltó okok',
          level: 1,
        ),
        const NoteBlock(
          id: 'p1',
          type: NoteBlockType.paragraph,
          text: 'A kiváltó ok gyakran infekció.',
        ),
        const NoteBlock(
          id: 'l1',
          type: NoteBlockType.listItem,
          text: 'Virális fertőzés',
          level: 1,
        ),
        const NoteBlock(
          id: 't1',
          type: NoteBlockType.table,
          title: 'Célértékek',
          rows: [
            ['Elem', 'Érték'],
            ['SpO2', '88-92%'],
          ],
        ),
        const NoteBlock(
          id: 'f1',
          type: NoteBlockType.flowchart,
          title: 'Ellátási ág',
          nodes: [
            NoteFlowchartNode(
              id: 'n1',
              label: 'Légzési elégtelenség?',
              shape: AiFlowchartNodeShape.decision,
              order: 1,
            ),
            NoteFlowchartNode(id: 'n2', label: 'Oxigén', order: 2),
          ],
          edges: [
            NoteFlowchartEdge(
              id: 'e1',
              fromNodeId: 'n1',
              toNodeId: 'n2',
              label: 'Igen',
              order: 1,
            ),
          ],
        ),
      ],
    );

    final reparsed = NoteDocument.fromPayload(document.toPayloadJson());

    expect(reparsed.blocks, hasLength(5));
    expect(reparsed.plainText, contains('COPD kiváltó okok'));
    expect(reparsed.plainText, contains('SpO2 | 88-92%'));
    expect(reparsed.plainText, contains('Légzési elégtelenség?'));
    expect(reparsed.plainText, contains('Igen'));
    expect(reparsed.preview, contains('COPD'));
  });

  test('migrates legacy table payload into a table block', () {
    final document = NoteDocument.fromPayload(
      '{"rows":[["Gyógyszer","Dózis"],["ASA","250 mg"]]}',
      legacyType: 'table',
      legacyText: 'ASA 250 mg',
      title: 'Gyógyszerek',
    );

    expect(document.blocks.single.type, NoteBlockType.table);
    expect(document.plainText, contains('ASA | 250 mg'));
  });

  test(
    'serializes table layout dimensions without affecting searchable text',
    () {
      const block = NoteBlock(
        id: 'table-layout',
        type: NoteBlockType.table,
        rows: [
          ['Állapot', 'Teendő'],
          ['Súlyos', 'High flow'],
        ],
        tableColumnWidths: [180, 220],
        tableRowHeights: [60, 88],
      );

      final parsed = NoteBlock.fromJson(block.toJson());

      expect(parsed.tableColumnWidths, [180, 220]);
      expect(parsed.tableRowHeights, [60, 88]);
      expect(parsed.plainText, contains('Súlyos | High flow'));
      expect(parsed.plainText, isNot(contains('180')));
      expect(parsed.plainText, isNot(contains('88')));
    },
  );

  test('migrates legacy text into one paragraph block', () {
    final document = NoteDocument.fromPayload(
      '{}',
      legacyType: 'text',
      legacyText: 'SpO2 cél 88-92%',
      title: 'Oxigén',
    );

    expect(document.blocks.single.type, NoteBlockType.paragraph);
    expect(document.plainText, 'SpO2 cél 88-92%');
  });

  test('serializes note block indexing metadata and detects stale index', () {
    final block = NoteBlock(
      id: 'block-1',
      type: NoteBlockType.paragraph,
      text: 'COPD kivaltok',
      indexedContentHash: 'old-hash',
      indexedAt: DateTime.utc(2026, 6, 15),
    );

    final parsed = NoteBlock.fromJson(block.toJson());

    expect(parsed.indexedContentHash, 'old-hash');
    expect(parsed.indexedAt, DateTime.utc(2026, 6, 15));
    expect(parsed.contentHash, isNotEmpty);
    expect(parsed.isIndexFresh, isFalse);
    expect(parsed.needsReindex, isTrue);
  });

  test(
    'serializes note block search metadata without polluting display text',
    () {
      const block = NoteBlock(
        id: 'block-1',
        type: NoteBlockType.listItem,
        title: 'Magyarázat',
        searchContext: 'légzési elégtelenség',
        searchRole: NoteSearchRoles.definition,
        searchAliases: ['DO2', 'VO2'],
        listItems: [NoteListItem(id: 'do2', text: 'DO2 = oxygénkínálat')],
      );

      final parsed = NoteBlock.fromJson(block.toJson());

      expect(parsed.searchContext, 'légzési elégtelenség');
      expect(parsed.searchRole, NoteSearchRoles.definition);
      expect(parsed.searchAliases, ['DO2', 'VO2']);
      expect(parsed.plainText, contains('Magyarázat'));
      expect(parsed.plainText, isNot(contains('légzési elégtelenség')));
      expect(parsed.displayTextForIndexing, contains('DO2 = oxygénkínálat'));
      expect(parsed.searchMetadataText, contains('légzési elégtelenség'));
      expect(parsed.searchMetadataText, contains('definition'));
    },
  );

  test('serializes typed document and block tags as search metadata only', () {
    const document = NoteDocument(
      tags: [
        NoteKnowledgeTag(
          type: NoteKnowledgeTagTypes.topic,
          label: 'légzési elégtelenség',
        ),
      ],
      blocks: [
        NoteBlock(
          id: 'block-1',
          type: NoteBlockType.paragraph,
          text: 'Súlyos esetben high flow oxygen.',
          tags: [
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.state,
              label: 'súlyos',
            ),
          ],
        ),
      ],
    );

    final parsed = NoteDocument.fromPayload(document.toPayloadJson());
    final block = parsed.blocks.single;

    expect(parsed.tags.single.type, NoteKnowledgeTagTypes.topic);
    expect(parsed.tags.single.label, 'légzési elégtelenség');
    expect(block.tags.single.type, NoteKnowledgeTagTypes.state);
    expect(block.tags.single.label, 'súlyos');
    expect(parsed.searchMetadataText, contains('topic:légzési elégtelenség'));
    expect(block.searchMetadataText, contains('state:súlyos'));
    expect(parsed.plainText, isNot(contains('topic:')));
    expect(block.plainText, isNot(contains('state:')));
  });

  test('serializes list item tags without polluting list display text', () {
    const item = NoteListItem(
      id: 'i1',
      text: 'magas áramlású oxygén',
      tags: [
        NoteKnowledgeTag(type: NoteKnowledgeTagTypes.state, label: 'súlyos'),
      ],
    );

    final parsed = NoteListItem.fromJson(item.toJson());

    expect(parsed.tags.single.type, NoteKnowledgeTagTypes.state);
    expect(parsed.tags.single.label, 'súlyos');
    expect(parsed.searchMetadataText, contains('state:súlyos'));
    expect(parsed.text, isNot(contains('state:')));
  });

  test(
    'serializes colored text range tags without block-level metadata leakage',
    () {
      const block = NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Enyhe esetben célzott oxygén, súlyos esetben high flow.',
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-1',
            start: 31,
            end: 37,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.state,
              label: 'súlyos',
              colorValue: 0xFFDC2626,
            ),
          ),
        ],
      );

      final parsed = NoteBlock.fromJson(block.toJson());

      expect(parsed.rangeTags.single.start, 31);
      expect(parsed.rangeTags.single.end, 37);
      expect(parsed.rangeTags.single.tag.colorValue, 0xFFDC2626);
      expect(parsed.searchMetadataText, isNot(contains('state:súlyos')));
      expect(parsed.plainText, contains('súlyos esetben high flow'));
      expect(parsed.plainText, isNot(contains('state:')));
    },
  );

  test('text paragraph styles round trip through note block json', () {
    const block = NoteBlock(
      id: 'block-1',
      type: NoteBlockType.paragraph,
      text: 'Alpha\nBeta\n\nGamma',
      paragraphStyles: [
        NoteTextParagraphStyle(id: 'p-1', start: 0, end: 10, level: 2),
        NoteTextParagraphStyle(id: 'p-2', start: 12, end: 17, level: 1),
      ],
    );

    final parsed = NoteBlock.fromJson(block.toJson());

    expect(parsed.paragraphStyles, hasLength(2));
    expect(parsed.paragraphStyles.first.id, 'p-1');
    expect(parsed.paragraphStyles.first.start, 0);
    expect(parsed.paragraphStyles.first.end, 10);
    expect(parsed.paragraphStyles.first.level, 2);
    expect(parsed.paragraphStyles.last.id, 'p-2');
    expect(parsed.paragraphStyles.last.start, 12);
    expect(parsed.paragraphStyles.last.end, 17);
    expect(parsed.paragraphStyles.last.level, 1);
  });

  test('invalid paragraph styles are ignored while parsing', () {
    final block = NoteBlock.fromJson({
      'id': 'block-1',
      'type': 'paragraph',
      'text': 'Alpha',
      'paragraphStyles': [
        {'id': 'bad', 'start': 5, 'end': 2, 'level': 1},
        {'id': 'ok', 'start': 0, 'end': 5, 'level': 20},
      ],
    });

    expect(block.paragraphStyles, hasLength(1));
    expect(block.paragraphStyles.single.id, 'ok');
    expect(block.paragraphStyles.single.level, 8);
  });

  test(
    'serializes multitag text ranges and scoped table flowchart tag assignments',
    () {
      const severe = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.state,
        label: 'súlyos',
        colorValue: 0xFFDC2626,
      );
      const respiratory = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'légzési elégtelenség',
        colorValue: 0xFF2563EB,
      );
      const document = NoteDocument(
        blocks: [
          NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Súlyos légzési elégtelenség.',
            rangeTags: [
              NoteTextRangeTag(
                id: 'range-1',
                start: 0,
                end: 29,
                tag: severe,
                tags: [severe, respiratory],
              ),
            ],
          ),
          NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'high flow'],
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'row-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableRow,
                  rowIndex: 1,
                ),
                tags: [severe],
              ),
              NoteScopedTagAssignment(
                id: 'column-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableColumn,
                  columnIndex: 1,
                ),
                tags: [respiratory],
              ),
              NoteScopedTagAssignment(
                id: 'cell-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableCell,
                  rowIndex: 1,
                  columnIndex: 1,
                ),
                tags: [severe, respiratory],
              ),
            ],
          ),
          NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(id: 'n1', label: 'Súlyos?'),
              NoteFlowchartNode(id: 'n2', label: 'Oxigén'),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'e1',
                fromNodeId: 'n1',
                toNodeId: 'n2',
                label: 'Igen',
              ),
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'node-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.flowchartNode,
                  elementId: 'n1',
                ),
                tags: [severe],
              ),
              NoteScopedTagAssignment(
                id: 'edge-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.flowchartEdge,
                  elementId: 'e1',
                ),
                tags: [respiratory],
              ),
            ],
          ),
        ],
      );

      final parsed = NoteDocument.fromPayload(document.toPayloadJson());
      final textBlock = parsed.blocks[0];
      final tableBlock = parsed.blocks[1];
      final flowBlock = parsed.blocks[2];

      expect(textBlock.rangeTags.single.tags.map((tag) => tag.label), [
        'súlyos',
        'légzési elégtelenség',
      ]);
      expect(
        tableBlock.scopedTags.map((assignment) => assignment.target.kind),
        containsAll([
          NoteTagTargetKind.tableRow,
          NoteTagTargetKind.tableColumn,
          NoteTagTargetKind.tableCell,
        ]),
      );
      expect(
        flowBlock.scopedTags.map((assignment) => assignment.target.kind),
        containsAll([
          NoteTagTargetKind.flowchartNode,
          NoteTagTargetKind.flowchartEdge,
        ]),
      );
      expect(
        parsed.knownTags.map((tag) => tag.metadataText),
        containsAll(['state:súlyos', 'topic:légzési elégtelenség']),
      );
      expect(
        tableBlock.knownTags.map((tag) => tag.metadataText),
        contains('state:súlyos'),
      );
      expect(tableBlock.searchMetadataText, isNot(contains('state:súlyos')));
      expect(
        flowBlock.searchMetadataText,
        isNot(contains('topic:légzési elégtelenség')),
      );
      expect(parsed.plainText, isNot(contains('state:')));
    },
  );

  test('list block preserves ordered list items and hierarchy', () {
    const block = NoteBlock(
      id: 'list-1',
      type: NoteBlockType.listItem,
      listLayoutMode: NoteListLayoutMode.hierarchy,
      listItems: [
        NoteListItem(id: 'i1', text: 'Elso', level: 0, checked: false),
        NoteListItem(id: 'i2', text: 'Alpont', level: 1, checked: true),
      ],
    );

    final parsed = NoteBlock.fromJson(block.toJson());

    expect(parsed.listItems.map((item) => item.text), ['Elso', 'Alpont']);
    expect(parsed.listLayoutMode, NoteListLayoutMode.hierarchy);
    expect(parsed.listItems[1].level, 1);
    expect(parsed.listItems[1].checked, isTrue);
    expect(parsed.plainTextForIndexing, contains('  Alpont'));
  });

  test('knowledge tag preserves registry fields while reading legacy json', () {
    final legacy = NoteKnowledgeTag.fromJson({
      'type': 'topic',
      'label': 'Légzés',
      'colorValue': 0xFF2563EB,
    });

    expect(legacy.id, isNull);
    expect(legacy.colorSlotId, isNull);
    expect(legacy.folderId, isNull);
    expect(legacy.resolvedColorValue, 0xFF2563EB);

    const registered = NoteKnowledgeTag(
      id: 'tag-1',
      type: NoteKnowledgeTagTypes.custom,
      label: 'Légzés',
      colorSlotId: 2,
      folderId: 'folder-1',
      colorValue: 0xFF7C3AED,
    );
    final json = registered.toJson();

    expect(json['id'], 'tag-1');
    expect(json['colorSlotId'], 2);
    expect(json['folderId'], 'folder-1');
    expect(json['type'], NoteKnowledgeTagTypes.custom);

    final parsed = NoteKnowledgeTag.fromJson(json);
    expect(parsed.id, 'tag-1');
    expect(parsed.colorSlotId, 2);
    expect(parsed.folderId, 'folder-1');
    expect(parsed.resolvedColorValue, noteTagColorSlots[2]);
  });

  test('flowchart node stores canvas coordinates', () {
    const node = NoteFlowchartNode(
      id: 'n1',
      label: 'Start',
      shape: AiFlowchartNodeShape.startEnd,
      x: 120,
      y: 80,
    );

    final parsed = NoteFlowchartNode.fromJson(node.toJson());

    expect(parsed.x, 120);
    expect(parsed.y, 80);
  });

  test(
    'flowchart node serializes logical kind role visual shape and ports',
    () {
      const node = NoteFlowchartNode(
        id: 'decision-1',
        label: 'Szaturáció?',
        kind: NoteFlowchartNodeKind.multiDecision,
        role: NoteFlowchartNodeRole.normal,
        visualShape: NoteFlowchartVisualShape.diamond,
        ports: [
          NoteFlowchartPort(
            id: 'p1',
            side: NoteFlowchartPortSide.right,
            label: '95 felett',
            semantic: NoteFlowchartPortSemantic.custom,
          ),
        ],
      );

      final parsed = NoteFlowchartNode.fromJson(node.toJson());

      expect(parsed.kind, NoteFlowchartNodeKind.multiDecision);
      expect(parsed.role, NoteFlowchartNodeRole.normal);
      expect(parsed.visualShape, NoteFlowchartVisualShape.diamond);
      expect(parsed.ports.single.id, 'p1');
      expect(parsed.ports.single.side, NoteFlowchartPortSide.right);
      expect(parsed.ports.single.label, '95 felett');
      expect(parsed.ports.single.semantic, NoteFlowchartPortSemantic.custom);
    },
  );

  test('legacy decision node derives default yes no ports', () {
    final node = NoteFlowchartNode.fromJson({
      'id': 'decision',
      'label': 'Javult?',
      'shape': 'decision',
    });

    expect(node.kind, NoteFlowchartNodeKind.binaryDecision);
    expect(node.visualShape, NoteFlowchartVisualShape.diamond);
    expect(
      node.ports.map((port) => port.semantic),
      containsAll([
        NoteFlowchartPortSemantic.yes,
        NoteFlowchartPortSemantic.no,
      ]),
    );
    expect(node.ports.map((port) => port.label), containsAll(['Igen', 'Nem']));
  });

  test('flowchart edge serializes port endpoints and routing mode', () {
    const edge = NoteFlowchartEdge(
      id: 'edge-1',
      fromNodeId: 'a',
      fromPortId: 'right-1',
      toNodeId: 'b',
      toPortId: 'left-1',
      label: 'vissza',
      routingMode: NoteFlowchartRoutingMode.manual,
      manualWaypoints: [NoteFlowchartWaypoint(10, 20)],
    );

    final parsed = NoteFlowchartEdge.fromJson(edge.toJson());

    expect(parsed.fromPortId, 'right-1');
    expect(parsed.toPortId, 'left-1');
    expect(parsed.routingMode, NoteFlowchartRoutingMode.manual);
    expect(parsed.manualWaypoints.single.x, 10);
    expect(parsed.manualWaypoints.single.y, 20);
  });
}
