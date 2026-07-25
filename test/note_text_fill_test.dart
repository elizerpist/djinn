import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/tagged_text_visual.dart';

void main() {
  test('text fill round-trips independently from knowledge tags', () {
    const fill = NoteTextFill(
      id: 'fill-1',
      start: 2,
      end: 8,
      colorValue: 0xFFFFF59D,
      targetKey: 'paragraph',
    );

    final parsed = NoteTextFill.fromJson(fill.toJson());

    expect(parsed.id, 'fill-1');
    expect(parsed.start, 2);
    expect(parsed.end, 8);
    expect(parsed.colorValue, 0xFFFFF59D);
    expect(parsed.targetKey, 'paragraph');
    expect(parsed.isValid, isTrue);
  });

  test(
    'text edit insertion shifts or expands fill ranges by edit position',
    () {
      const fill = NoteTextFill(
        id: 'fill-1',
        start: 6,
        end: 10,
        colorValue: 0xFFFFF59D,
      );

      final shifted = transformNoteTextFillsForEdit(
        const [fill],
        oldText: 'Alpha Beta',
        newText: 'Say Alpha Beta',
      ).single;
      final expanded = transformNoteTextFillsForEdit(
        const [fill],
        oldText: 'Alpha Beta',
        newText: 'Alpha Be--ta',
      ).single;

      expect((shifted.start, shifted.end), (10, 14));
      expect((expanded.start, expanded.end), (6, 12));
    },
  );

  test('text edit deletion shifts, shrinks, and drops fill ranges', () {
    const fill = NoteTextFill(
      id: 'fill-1',
      start: 10,
      end: 14,
      colorValue: 0xFFFFF59D,
    );

    final shifted = transformNoteTextFillsForEdit(
      const [fill],
      oldText: 'Say Alpha Beta',
      newText: 'Alpha Beta',
    ).single;
    final shrunk = transformNoteTextFillsForEdit(
      const [
        NoteTextFill(id: 'fill-2', start: 6, end: 12, colorValue: 0xFFFFF59D),
      ],
      oldText: 'Alpha Be--ta',
      newText: 'Alpha Beta',
    ).single;
    final dropped = transformNoteTextFillsForEdit(
      const [
        NoteTextFill(id: 'fill-3', start: 6, end: 10, colorValue: 0xFFFFF59D),
      ],
      oldText: 'Alpha Beta',
      newText: 'Alpha ',
    );

    expect((shifted.start, shifted.end), (6, 10));
    expect((shrunk.start, shrunk.end), (6, 10));
    expect(dropped, isEmpty);
  });

  test(
    'paragraph edits remap legacy null target fills without touching list fills',
    () {
      final remapped = transformNoteTextFillsForEdit(
        const [
          NoteTextFill(
            id: 'legacy-paragraph-fill',
            start: 6,
            end: 10,
            colorValue: 0xFFFFF59D,
          ),
          NoteTextFill(
            id: 'list-fill',
            start: 6,
            end: 10,
            colorValue: 0xFFC8E6C9,
            targetKey: 'list:item-1',
          ),
        ],
        oldText: 'Alpha Beta',
        newText: 'Say Alpha Beta',
        targetKey: 'paragraph',
      );

      final paragraph = remapped.singleWhere(
        (fill) => fill.id == 'legacy-paragraph-fill',
      );
      final list = remapped.singleWhere((fill) => fill.id == 'list-fill');
      expect((paragraph.start, paragraph.end), (10, 14));
      expect((list.start, list.end), (6, 10));
    },
  );

  test(
    'unified note chunk preserves fills for paragraph list and table text',
    () {
      const block = NoteBlock(
        id: 'note-chunk-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'section-1',
            type: NoteMixedSectionType.paragraph,
            text: 'Fontos mondat',
            textFills: [
              NoteTextFill(
                id: 'p-fill',
                start: 0,
                end: 6,
                colorValue: 0xFFFFF59D,
                targetKey: 'paragraph',
              ),
            ],
          ),
          NoteMixedSection(
            id: 'section-2',
            type: NoteMixedSectionType.list,
            listItems: [NoteListItem(id: 'item-1', text: 'Listaelem')],
            textFills: [
              NoteTextFill(
                id: 'l-fill',
                start: 0,
                end: 5,
                colorValue: 0xFFC8E6C9,
                targetKey: 'list:item-1',
              ),
            ],
          ),
          NoteMixedSection(
            id: 'section-3',
            type: NoteMixedSectionType.table,
            rows: [
              ['Cella'],
            ],
            textFills: [
              NoteTextFill(
                id: 't-fill',
                start: 0,
                end: 5,
                colorValue: 0xFFBBDEFB,
                targetKey: 'table:0:0',
              ),
            ],
          ),
        ],
      );

      final parsed = NoteBlock.fromJson(block.toJson());

      expect(parsed.mixedSections[0].textFills.single.targetKey, 'paragraph');
      expect(parsed.mixedSections[1].textFills.single.targetKey, 'list:item-1');
      expect(parsed.mixedSections[2].textFills.single.targetKey, 'table:0:0');
      expect(parsed.knownTags, isEmpty);
    },
  );

  test('flowchart node and edge labels preserve the same fill model', () {
    const block = NoteBlock(
      id: 'flow-1',
      type: NoteBlockType.flowchart,
      nodes: [
        NoteFlowchartNode(
          id: 'node-1',
          label: 'Kezdés',
          shape: AiFlowchartNodeShape.startEnd,
          labelFills: [
            NoteTextFill(
              id: 'node-fill',
              start: 0,
              end: 6,
              colorValue: 0xFFFFF59D,
            ),
          ],
        ),
      ],
      edges: [
        NoteFlowchartEdge(
          id: 'edge-1',
          fromNodeId: 'node-1',
          toNodeId: 'node-2',
          label: 'igen',
          labelFills: [
            NoteTextFill(
              id: 'edge-fill',
              start: 0,
              end: 4,
              colorValue: 0xFFC8E6C9,
            ),
          ],
        ),
      ],
    );

    final parsed = NoteBlock.fromJson(block.toJson());

    expect(parsed.nodes.single.labelFills.single.id, 'node-fill');
    expect(parsed.edges.single.labelFills.single.id, 'edge-fill');
    expect(parsed.knownTags, isEmpty);
  });

  test('fill span paints only the stored user-selected text range', () {
    final span = noteTextFillEditableTextSpan(
      text: 'Alpha Beta Gamma',
      fills: const [
        NoteTextFill(id: 'fill-1', start: 6, end: 10, colorValue: 0xFFFFF59D),
      ],
      baseStyle: const TextStyle(fontSize: 16),
    );

    expect(span.toPlainText(), 'Alpha Beta Gamma');
    expect(span.children, hasLength(3));
    final filledSpan = span.children![1] as TextSpan;
    expect(filledSpan.text, 'Beta');
    expect(filledSpan.style?.backgroundColor, const Color(0xFFFFF59D));
  });

  test('clearing a partial fill preserves its left and right fragments', () {
    var nextId = 0;
    final fills = replaceNoteTextFillRange(
      const [
        NoteTextFill(
          id: 'original',
          start: 0,
          end: 10,
          colorValue: 0xFFFFF59D,
          targetKey: 'paragraph',
        ),
      ],
      start: 3,
      end: 6,
      targetKey: 'paragraph',
      colorValue: null,
      idFactory: () => 'fragment-${nextId++}',
    );

    expect(
      fills.map((fill) => (fill.start, fill.end, fill.colorValue)).toList(),
      [(0, 3, 0xFFFFF59D), (6, 10, 0xFFFFF59D)],
    );
  });

  test('recoloring a partial fill replaces only the selected interval', () {
    var nextId = 0;
    final fills = replaceNoteTextFillRange(
      const [
        NoteTextFill(
          id: 'original',
          start: 0,
          end: 10,
          colorValue: 0xFFFFF59D,
          targetKey: 'paragraph',
        ),
      ],
      start: 3,
      end: 6,
      targetKey: 'paragraph',
      colorValue: 0xFFBBDEFB,
      idFactory: () => 'fill-${nextId++}',
    );

    expect(
      fills.map((fill) => (fill.start, fill.end, fill.colorValue)).toList(),
      [(0, 3, 0xFFFFF59D), (3, 6, 0xFFBBDEFB), (6, 10, 0xFFFFF59D)],
    );
  });

  test('text edits transform range tags and paragraph styles with fills', () {
    const tag = NoteKnowledgeTag(
      id: 'tag-1',
      type: NoteKnowledgeTagTypes.topic,
      label: 'Beta',
    );
    final rangeTags = transformNoteTextRangeTagsForEdit(
      const [NoteTextRangeTag(id: 'range-1', start: 6, end: 10, tag: tag)],
      oldText: 'Alpha Beta',
      newText: 'Say Alpha Beta',
    );
    final styles = transformNoteTextParagraphStylesForEdit(
      const [
        NoteTextParagraphStyle(id: 'style-1', start: 6, end: 10, level: 2),
      ],
      oldText: 'Alpha Beta',
      newText: 'Say Alpha Beta',
    );

    expect((rangeTags.single.start, rangeTags.single.end), (10, 14));
    expect((styles.single.start, styles.single.end), (10, 14));
  });

  test('partial retagging preserves tags outside the selected interval', () {
    const oldTag = NoteKnowledgeTag(
      id: 'old',
      type: NoteKnowledgeTagTypes.topic,
      label: 'Régi',
    );
    const newTag = NoteKnowledgeTag(
      id: 'new',
      type: NoteKnowledgeTagTypes.topic,
      label: 'Új',
    );
    var nextId = 0;
    final ranges = replaceNoteTextRangeTags(
      const [NoteTextRangeTag(id: 'original', start: 0, end: 10, tag: oldTag)],
      start: 3,
      end: 6,
      tags: const [newTag],
      idFactory: () => 'range-${nextId++}',
    );

    expect(ranges.map((range) => (range.start, range.end)).toList(), [
      (0, 3),
      (3, 6),
      (6, 10),
    ]);
    expect(ranges.map((range) => range.resolvedTags.single.label).toList(), [
      'Régi',
      'Új',
      'Régi',
    ]);
  });

  test('retagging removes scoped targets whose ranges are no longer valid', () {
    const rangeTag = NoteKnowledgeTag(
      id: 'range-tag',
      type: NoteKnowledgeTagTypes.topic,
      label: 'Range',
    );
    const scopedTag = NoteKnowledgeTag(
      id: 'scoped-tag',
      type: NoteKnowledgeTagTypes.custom,
      label: 'Scoped',
    );
    var nextRangeId = 0;
    var nextScopedId = 0;
    final replacement = replaceNoteTextRangeTagsAndRemapScopedTags(
      const [
        NoteTextRangeTag(id: 'valid-range', start: 0, end: 10, tag: rangeTag),
        NoteTextRangeTag(
          id: 'invalid-range',
          start: 12,
          end: 12,
          tag: rangeTag,
        ),
      ],
      scopedTags: const [
        NoteScopedTagAssignment(
          id: 'valid-scope',
          target: NoteTagTarget(
            kind: NoteTagTargetKind.textRange,
            rangeId: 'valid-range',
          ),
          tags: [scopedTag],
        ),
        NoteScopedTagAssignment(
          id: 'invalid-scope',
          target: NoteTagTarget(
            kind: NoteTagTargetKind.textRange,
            rangeId: 'invalid-range',
          ),
          tags: [scopedTag],
        ),
        NoteScopedTagAssignment(
          id: 'table-scope',
          target: NoteTagTarget(
            kind: NoteTagTargetKind.tableCell,
            rowIndex: 0,
            columnIndex: 0,
          ),
          tags: [scopedTag],
        ),
      ],
      start: 3,
      end: 6,
      tags: const [],
      rangeIdFactory: () => 'range-${nextRangeId++}',
      scopedTagIdFactory: () => 'scope-${nextScopedId++}',
    );

    final rangeIds = replacement.rangeTags.map((range) => range.id).toSet();
    final textRangeAssignments = replacement.scopedTags.where(
      (assignment) => assignment.target.kind == NoteTagTargetKind.textRange,
    );
    expect(
      textRangeAssignments.every(
        (assignment) => rangeIds.contains(assignment.target.rangeId),
      ),
      isTrue,
    );
    expect(
      textRangeAssignments.map((assignment) => assignment.id),
      isNot(contains('invalid-scope')),
    );
    expect(
      replacement.scopedTags
          .where(
            (assignment) =>
                assignment.target.kind == NoteTagTargetKind.tableCell,
          )
          .single
          .id,
      'table-scope',
    );
  });
}
