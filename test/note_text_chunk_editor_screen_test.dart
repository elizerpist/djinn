import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('single-line selection inserts the rail below that visual line', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    final line0 = tester.getRect(
      find.byKey(const ValueKey('note-text-line-0')),
    );
    final line1 = tester.getRect(
      find.byKey(const ValueKey('note-text-line-1')),
    );
    final rail = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
    );

    expect(rail.top, greaterThanOrEqualTo(line0.bottom));
    expect(line1.top, greaterThanOrEqualTo(rail.bottom));
  });

  testWidgets(
    'rail gap pushes the actual native editable text below the rail',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\nBeta\nGamma',
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      await tester.pumpAndSettle();

      final alpha = _nativeEditableSubstringRect(tester, 'Alpha');
      final beta = _nativeEditableSubstringRect(tester, 'Beta');
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );

      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsOneWidget,
      );
      final spacer = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      );
      expect(
        spacer.height,
        closeTo(rail.height + 8, 2),
        reason: 'The inline spacer must match the visible rail plus gap.',
      );

      expect(rail.top, greaterThanOrEqualTo(alpha.bottom));
      expect(beta.top, greaterThanOrEqualTo(rail.bottom));
      expect(
        beta.top - rail.bottom,
        lessThanOrEqualTo(20),
        reason:
            'The native newline spacer may round up by one line, but must not '
            'leave a large fixed gap.',
      );
    },
  );

  testWidgets('soft-wrapped rail opens enough native space below itself', (
    tester,
  ) async {
    const target = 'targetword';
    final text = [
      'alpha beta gamma delta epsilon zeta eta theta',
      target,
      'iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon',
    ].join(' ');
    final targetStart = text.indexOf(target);
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      surfaceSize: const Size(260, 900),
    );

    _setEditorSelection(
      tester,
      TextSelection(
        baseOffset: targetStart,
        extentOffset: targetStart + target.length,
      ),
    );
    await tester.pumpAndSettle();

    final targetRect = _nativeEditableSubstringTightRect(tester, target);
    final rail = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
    );
    final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
    final nextLine = lineBounds.firstWhere((line) => line.top > rail.top + 2);
    final diagnostic =
        'target=$targetRect rail=$rail nextLine=$nextLine '
        'lineBounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)},${line.bottom.toStringAsFixed(1)}').join(';')} '
        'logs=${DebugConsole.allText}';

    expect(rail.top, greaterThanOrEqualTo(targetRect.bottom));
    expect(
      nextLine.top,
      greaterThanOrEqualTo(rail.bottom),
      reason:
          'A rail inserted after a soft-wrapped visual line must reserve one '
          'terminating native line plus the measured rail rows. $diagnostic',
    );
    expect(
      nextLine.top - rail.bottom,
      lessThanOrEqualTo(24),
      reason:
          'The rail gap may round to the native line grid but must not leave '
          'a large stale spacer. $diagnostic',
    );
  });

  testWidgets('textchunk layout writes detailed debug geometry logs', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    expect(DebugConsole.allText, contains('[TextChunkLayout] textLen='));
    expect(DebugConsole.allText, contains('selection=1-4'));
    expect(DebugConsole.allText, contains('railLine=0'));
    expect(DebugConsole.allText, contains('placeholderCount='));
    expect(DebugConsole.allText, contains('railGap='));
    expect(DebugConsole.allText, contains('railHeight='));
    expect(DebugConsole.allText, contains('railTargetSpacer='));
    expect(DebugConsole.allText, contains('railNativeSpacer='));
    expect(DebugConsole.allText, contains('railRoundedGap='));
    expect(DebugConsole.allText, contains('railLineBreaks='));
    expect(DebugConsole.allText, contains('railLeadingUnderlineSpacer='));
    expect(DebugConsole.allText, contains('railSoftWrapTerminator='));
    expect(DebugConsole.allText, contains('railNativeLines='));
    expect(DebugConsole.allText, contains('railPlaceholderBreaks='));
    expect(DebugConsole.allText, contains('[TextChunkLayout] nativeGeometry'));
    expect(DebugConsole.allText, contains('nativeOrigins='));
    expect(DebugConsole.allText, contains('tightTagBoxes=true'));
    expect(DebugConsole.allText, contains('underlineRects='));
    expect(DebugConsole.allText, contains('placeholderDelta='));
  });

  testWidgets(
    'multi-line selection inserts the rail below the lowest selected visual line',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\nBeta\nGamma',
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 1, extentOffset: 8),
      );
      await tester.pumpAndSettle();

      final line1 = tester.getRect(
        find.byKey(const ValueKey('note-text-line-1')),
      );
      final line2 = tester.getRect(
        find.byKey(const ValueKey('note-text-line-2')),
      );
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );

      expect(rail.top, greaterThanOrEqualTo(line1.bottom));
      expect(line2.top, greaterThanOrEqualTo(rail.bottom));
    },
  );

  testWidgets('rail spacer follows collapsed and expanded rail height', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    final expandedRail = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
    );
    final expandedSpacer = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
    );
    final expandedBeta = _nativeEditableSubstringRect(tester, 'Beta');

    await tester.tap(
      find.byKey(const ValueKey('note-selection-rail-toggle-tags')),
    );
    await tester.pumpAndSettle();

    final collapsedRail = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
    );
    final collapsedSpacer = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
    );
    final collapsedBeta = _nativeEditableSubstringRect(tester, 'Beta');

    expect(collapsedRail.height, lessThan(expandedRail.height));
    expect(collapsedSpacer.height, closeTo(collapsedRail.height + 8, 2));
    expect(expandedSpacer.height, closeTo(expandedRail.height + 8, 2));
    expect(collapsedBeta.top, lessThan(expandedBeta.top));
    expect(collapsedBeta.top, greaterThanOrEqualTo(collapsedRail.bottom));
    expect(collapsedBeta.top - collapsedRail.bottom, lessThanOrEqualTo(20));
  });

  testWidgets(
    'continuous selection spans paragraphs and anchors rail at the last line',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\nBeta\n\nGamma',
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 0, extentOffset: 17),
      );
      await tester.pumpAndSettle();

      final editable = _editableText(tester);
      expect(editable.controller.selection.start, lessThan(5));
      expect(editable.controller.selection.end, greaterThan(12));
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );
      final selectedLine = tester.getRect(
        find.byKey(const ValueKey('note-text-line-3')),
      );
      expect(rail.top, greaterThanOrEqualTo(selectedLine.bottom));
    },
  );

  testWidgets(
    'collapsed selection is owned by the visible native EditableText',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\n\n',
        ),
      );

      _setEditorSelection(tester, const TextSelection.collapsed(offset: 7));
      await tester.pumpAndSettle();

      final editableRect = tester.getRect(
        find.byKey(const ValueKey('note-text-input-bridge')),
      );
      final editable = _editableText(tester);

      expect(editableRect.height, greaterThan(20));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(editable.controller.selection.isCollapsed, isTrue);
      expect(editable.selectionControls, isNotNull);
      expect(editable.contextMenuBuilder, isNotNull);
      expect(find.byKey(const ValueKey('note-text-line-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-text-line-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-text-line-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-text-caret-2')), findsNothing);
    },
  );

  testWidgets('selected range uses the native editable selection path', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    final editableRect = tester.getRect(
      find.byKey(const ValueKey('note-text-input-bridge')),
    );
    final editable = _editableText(tester);

    expect(editableRect.height, greaterThan(20));
    expect(editable.showSelectionHandles, isTrue);
    expect(editable.selectionControls, isNotNull);
    expect(editable.selectionControls, isA<TextSelectionHandleControls>());
    expect(editable.contextMenuBuilder, isNotNull);
    final editableState = _editableTextState(tester);
    expect(
      editableState.contextMenuButtonItems.map((item) => item.type),
      contains(ContextMenuButtonType.copy),
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-handle-start')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-handle-end')),
      findsNothing,
    );
    expect(editable.controller.selection.start, 6);
    expect(editable.controller.selection.end, 10);
  });

  testWidgets('long press selection can show the native clipboard toolbar', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
    );

    await tester.longPressAt(
      _nativeEditableSubstringRect(tester, 'Beta').center,
    );
    await tester.pumpAndSettle();

    final editableState = _editableTextState(tester);

    expect(editableState.textEditingValue.selection.isCollapsed, isFalse);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('long text scrolls without clipping the final line', (
    tester,
  ) async {
    final text = List.generate(40, (index) => 'Line $index').join('\n');
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      surfaceSize: const Size(360, 480),
    );

    expect(find.byKey(const ValueKey('note-text-line-39')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('note-text-scroll')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('note-text-line-39'))).bottom,
      lessThanOrEqualTo(480),
    );
  });

  testWidgets(
    'rail tag button saves primary and secondary tags to the selected range',
    (tester) async {
      NoteBlock? latest;
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha Beta Gamma',
        ),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 6, extentOffset: 10),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-text-selection-rail-tag')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tag-manager-name')),
        'primary',
      );
      await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-manager-name')),
        'secondary',
      );
      await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.rangeTags, hasLength(1));
      expect(latest!.rangeTags.single.start, 6);
      expect(latest!.rangeTags.single.end, 10);
      expect(latest!.rangeTags.single.resolvedTags.map((tag) => tag.label), [
        'primary',
        'secondary',
      ]);
    },
  );

  testWidgets('tapping text after tagging focuses input and shows caret', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      onChanged: (block) => latest = block,
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-text-selection-rail-tag')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'primary',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest!.rangeTags, hasLength(1));
    await tester.tapAt(_nativeEditableSubstringRect(tester, 'Alpha').center);
    await tester.pumpAndSettle();

    final editable = _editableText(tester);
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.selection.isCollapsed, isTrue);
    expect(find.byKey(const ValueKey('note-text-caret-0')), findsNothing);
  });

  testWidgets('rail is hosted by the native editable text layout', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-native-editable-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-custom-visible-layout')),
      findsNothing,
    );
  });

  testWidgets(
    'tag decoration uses native text geometry without duplicate highlight',
    (tester) async {
      const text = 'Alpha\nBeta\nGamma';
      final betaStart = text.indexOf('Beta');
      await _pumpTextChunkEditor(
        tester,
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-beta',
              start: betaStart,
              end: betaStart + 4,
              tag: const NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.state,
                label: 'primary',
                colorValue: 0xFFDC2626,
              ),
              tags: const [
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.state,
                  label: 'primary',
                  colorValue: 0xFFDC2626,
                ),
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.topic,
                  label: 'secondary-a',
                  colorValue: 0xFF2563EB,
                ),
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.custom,
                  label: 'secondary-b',
                  colorValue: 0xFF059669,
                ),
              ],
            ),
          ],
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('note-text-primary-highlight-range-beta-0-1'),
        ),
        findsNothing,
        reason: 'Primary tag background must come from native TextSpan only.',
      );
      final firstUnderline = tester.getRect(
        find.byKey(
          const ValueKey('note-text-secondary-underline-range-beta-1-0'),
        ),
      );
      final secondUnderline = tester.getRect(
        find.byKey(
          const ValueKey('note-text-secondary-underline-range-beta-2-0'),
        ),
      );
      final beta = _nativeEditableSubstringTightRect(tester, 'Beta');

      expect(firstUnderline.left, closeTo(beta.left, 1));
      expect(firstUnderline.width, closeTo(beta.width, 1));
      expect(firstUnderline.top, greaterThan(beta.top + 15));
      expect(secondUnderline.top, greaterThan(firstUnderline.top));
      expect(firstUnderline.top, lessThan(beta.bottom + 16));
    },
  );

  testWidgets('stacked underlines push following native editable text down', (
    tester,
  ) async {
    const text = 'Alpha\nBeta\nGamma';
    final betaStart = text.indexOf('Beta');
    final tags = [
      const NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.state,
        label: 'primary',
        colorValue: 0xFFDC2626,
      ),
      for (var index = 1; index <= 10; index += 1)
        NoteKnowledgeTag(
          type: NoteKnowledgeTagTypes.custom,
          label: 'secondary-$index',
          colorValue: 0xFF2563EB + index,
        ),
    ];
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: text,
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-beta',
            start: betaStart,
            end: betaStart + 4,
            tag: tags.first,
            tags: tags,
          ),
        ],
      ),
    );

    final lastUnderline = tester.getRect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-beta-10-0'),
      ),
    );
    final firstUnderline = tester.getRect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-beta-1-0'),
      ),
    );
    final beta = _nativeEditableSubstringRect(tester, 'Beta');
    final gamma = _nativeEditableSubstringRect(tester, 'Gamma');

    expect(firstUnderline.top, greaterThan(beta.top + 15));
    expect(lastUnderline.top, greaterThan(firstUnderline.top));
    expect(lastUnderline.top, lessThan(beta.bottom + 48));
    expect(gamma.top, greaterThanOrEqualTo(lastUnderline.bottom + 1));
  });

  testWidgets('stacked underline spacing is local to the tagged visual line', (
    tester,
  ) async {
    const text = 'Alpha\nBeta\nGamma';
    final betaStart = text.indexOf('Beta');
    final tags = [
      const NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.state,
        label: 'primary',
        colorValue: 0xFFDC2626,
      ),
      for (var index = 1; index <= 10; index += 1)
        NoteKnowledgeTag(
          type: NoteKnowledgeTagTypes.custom,
          label: 'secondary-$index',
          colorValue: 0xFF2563EB + index,
        ),
    ];
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: text,
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-beta',
            start: betaStart,
            end: betaStart + 4,
            tag: tags.first,
            tags: tags,
          ),
        ],
      ),
    );

    final alpha = _nativeEditableSubstringRect(tester, 'Alpha');
    final beta = _nativeEditableSubstringRect(tester, 'Beta');
    final gamma = _nativeEditableSubstringRect(tester, 'Gamma');
    final firstUnderline = tester.getRect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-beta-1-0'),
      ),
    );
    final lastUnderline = tester.getRect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-beta-10-0'),
      ),
    );

    expect(
      beta.top - alpha.top,
      lessThanOrEqualTo(28),
      reason:
          'Underline spacing belongs below the tagged line only; the line '
          'above it must keep the normal native line distance.',
    );
    expect(firstUnderline.top, greaterThan(beta.top + 15));
    expect(lastUnderline.top, greaterThan(firstUnderline.top));
    expect(gamma.top, greaterThanOrEqualTo(lastUnderline.bottom + 1));
  });

  testWidgets('underline spacer shrinks when secondary tags are removed', (
    tester,
  ) async {
    const target = 'targetword';
    final text = [
      'alpha beta gamma delta epsilon zeta',
      target,
      'theta iota kappa lambda mu nu xi omicron pi rho sigma',
    ].join(' ');
    final targetStart = text.indexOf(target);

    Future<(Rect targetRect, Rect nextLine)> pumpWithSecondaryTags(
      int secondaryCount,
    ) async {
      final tags = _tagsWithSecondary(secondaryCount);
      await _pumpTextChunkEditor(
        tester,
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-target',
              start: targetStart,
              end: targetStart + target.length,
              tag: tags.first,
              tags: tags,
            ),
          ],
        ),
        surfaceSize: const Size(260, 900),
      );
      final targetRect = _nativeEditableSubstringTightRect(tester, target);
      final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final nextLine = lineBounds.firstWhere(
        (line) => line.top > targetRect.top + 2,
      );
      return (targetRect, nextLine);
    }

    final many = await pumpWithSecondaryTags(10);
    expect(
      DebugConsole.allText,
      contains('underline-line-'),
      reason: 'The many-tag state must use native underline spacers.',
    );
    DebugConsole.clear();

    final one = await pumpWithSecondaryTags(1);
    final oneLogs = DebugConsole.allText;
    DebugConsole.clear();

    final none = await pumpWithSecondaryTags(0);
    final noneLogs = DebugConsole.allText;
    final manyGap = many.$2.top - many.$1.top;
    final oneGap = one.$2.top - one.$1.top;
    final noneGap = none.$2.top - none.$1.top;
    final diagnostic =
        'manyGap=${manyGap.toStringAsFixed(1)} '
        'oneGap=${oneGap.toStringAsFixed(1)} '
        'noneGap=${noneGap.toStringAsFixed(1)} '
        'oneLogs=$oneLogs noneLogs=$noneLogs';

    expect(
      oneGap,
      lessThan(manyGap),
      reason:
          'Removing most secondary underline lanes must shrink the native '
          'line gap. $diagnostic',
    );
    expect(
      noneGap,
      lessThanOrEqualTo(oneGap),
      reason:
          'Removing the final secondary underline must not keep the old '
          'larger spacer. $diagnostic',
    );
    expect(
      noneLogs,
      isNot(contains('underline-line-')),
      reason:
          'With only the primary tag left, there must be no underline '
          'placeholder. $diagnostic',
    );
  });

  testWidgets('stacked underline spacing opens the next soft-wrapped row', (
    tester,
  ) async {
    const target = 'targetword';
    final text = [
      'alpha beta gamma delta epsilon zeta',
      target,
      'theta iota kappa lambda mu nu xi omicron pi rho sigma',
    ].join(' ');
    final targetStart = text.indexOf(target);
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: text,
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-target',
            start: targetStart,
            end: targetStart + target.length,
            tag: _stackedTags().first,
            tags: _stackedTags(),
          ),
        ],
      ),
      surfaceSize: const Size(260, 900),
    );

    final targetRect = _nativeEditableSubstringTightRect(tester, target);
    final lastUnderline = tester.getRect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-target-10-0'),
      ),
    );
    final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
    final nextLine = lineBounds.firstWhere(
      (line) => line.top > targetRect.top + 2,
    );
    final diagnostic =
        'target=$targetRect lastUnderline=$lastUnderline nextLine=$nextLine '
        'lineBounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)},${line.bottom.toStringAsFixed(1)}').join(';')} '
        'logs=${DebugConsole.allText}';

    expect(lastUnderline.top, greaterThan(targetRect.bottom));
    expect(
      nextLine.top,
      greaterThanOrEqualTo(lastUnderline.bottom + 1),
      reason:
          'Many underline lanes must create downward spacing before the next '
          'soft-wrapped native row. $diagnostic',
    );
  });

  testWidgets(
    'rail opens below stacked underlines without covering following text',
    (tester) async {
      const target = 'targetword';
      final text = [
        'alpha beta gamma delta epsilon zeta',
        target,
        'theta iota kappa lambda mu nu xi omicron pi rho sigma',
      ].join(' ');
      final targetStart = text.indexOf(target);
      await _pumpTextChunkEditor(
        tester,
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-target',
              start: targetStart,
              end: targetStart + target.length,
              tag: _stackedTags().first,
              tags: _stackedTags(),
            ),
          ],
        ),
        surfaceSize: const Size(260, 900),
      );

      _setEditorSelection(
        tester,
        TextSelection(
          baseOffset: targetStart,
          extentOffset: targetStart + target.length,
        ),
      );
      await tester.pumpAndSettle();

      final targetRect = _nativeEditableSubstringTightRect(tester, target);
      final lastUnderline = tester.getRect(
        find.byKey(
          const ValueKey('note-text-secondary-underline-range-target-10-0'),
        ),
      );
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );
      final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final nextLine = lineBounds.firstWhere((line) => line.top > rail.top + 2);
      final diagnostic =
          'target=$targetRect lastUnderline=$lastUnderline rail=$rail '
          'nextLine=$nextLine '
          'lineBounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)},${line.bottom.toStringAsFixed(1)}').join(';')} '
          'logs=${DebugConsole.allText}';

      expect(lastUnderline.top, greaterThan(targetRect.bottom));
      expect(rail.top, greaterThanOrEqualTo(lastUnderline.bottom + 1));
      expect(
        nextLine.top,
        greaterThanOrEqualTo(rail.bottom),
        reason:
            'Opening the inline rail after a line with stacked underlines must '
            'move the following native text below the visible rail. '
            '$diagnostic',
      );
      expect(
        nextLine.top - rail.bottom,
        lessThanOrEqualTo(24),
        reason:
            'The gap below the rail may round to the native line grid but must '
            'not become a large fixed hole. $diagnostic',
      );
    },
  );

  testWidgets(
    'rail paragraph step indents every visual line in the active paragraph',
    (tester) async {
      NoteBlock? latest;
      const text =
          'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda\n'
          'manual continuation\n\n'
          'Next paragraph';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        surfaceSize: const Size(320, 700),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-text-selection-rail-indent')),
      );
      await tester.pumpAndSettle();

      expect(latest!.text.startsWith('  Alpha'), isTrue);
      expect(latest!.text.endsWith('\n\nNext paragraph'), isTrue);
      final firstParagraphLines = tester
          .widgetList<Padding>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Padding &&
                  widget.key.toString().contains('note-text-line-indent-') &&
                  widget.padding.resolve(TextDirection.ltr).left > 0,
            ),
          )
          .length;
      expect(firstParagraphLines, greaterThan(1));
    },
  );

  testWidgets(
    'paragraph step indents every native wrapped row in the active paragraph',
    (tester) async {
      NoteBlock? latest;
      const text =
          'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda '
          'mu nu xi omicron pi rho sigma tau';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        surfaceSize: const Size(260, 700),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(tester, const TextSelection.collapsed(offset: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-text-indent')));
      await tester.pumpAndSettle();

      expect(latest!.text.startsWith('  Alpha'), isTrue);
      expect(DebugConsole.allText, contains('[TextChunkStep] delta=1'));
      expect(DebugConsole.allText, contains('[TextChunkStepReflow] delta=1'));
      expect(DebugConsole.allText, contains('layoutLines='));
      expect(DebugConsole.allText, contains('indentEdits='));
      expect(DebugConsole.allText, contains('changed=true'));
      final editableLeft = tester
          .getRect(find.byKey(const ValueKey('note-text-input-bridge')))
          .left;
      final lineLefts = _nativeEditableNonEmptyLineLefts(tester);

      expect(lineLefts.length, greaterThan(2));
      expect(lineLefts.first - editableLeft, greaterThanOrEqualTo(20));
      for (final left in lineLefts.skip(1)) {
        expect(left, greaterThanOrEqualTo(lineLefts.first - 1));
      }
    },
  );

  testWidgets(
    'paragraph step keeps the right wrap edge at the editor right edge',
    (tester) async {
      NoteBlock? latest;
      final text = List.filled(180, 'm').join();
      await _pumpTextChunkEditor(
        tester,
        NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
        surfaceSize: const Size(260, 700),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(tester, const TextSelection.collapsed(offset: 2));
      await tester.pumpAndSettle();
      for (var index = 0; index < 3; index += 1) {
        await tester.tap(find.byKey(const ValueKey('note-text-indent')));
        await tester.pumpAndSettle();
      }

      expect(latest!.text.startsWith('      m'), isTrue);
      expect(
        latest!.text.split('\n').map((line) => line.trimLeft()).join(),
        text,
        reason: 'Synthetic paragraph wrap lines must not insert spaces.',
      );
      final editableRect = tester.getRect(
        find.byKey(const ValueKey('note-text-input-bridge')),
      );
      final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final diagnostic =
          'editable=$editableRect '
          'bounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)}-${line.right.toStringAsFixed(1)}').join(',')} '
          'textLen=${latest!.text.length}';

      expect(lineBounds.length, greaterThan(2));
      for (final line in lineBounds.take(lineBounds.length - 1)) {
        expect(
          line.right,
          greaterThanOrEqualTo(editableRect.right - 18),
          reason:
              'Step-in must move only the left margin; each full wrapped row '
              'must still be able to reach the editor right edge. $diagnostic',
        );
      }
    },
  );

  testWidgets(
    'paragraph step out restores every native wrapped row to the left margin',
    (tester) async {
      NoteBlock? latest;
      const text =
          'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda '
          'mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        surfaceSize: const Size(260, 700),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(tester, const TextSelection.collapsed(offset: 2));
      await tester.pumpAndSettle();
      for (var index = 0; index < 5; index += 1) {
        await tester.tap(find.byKey(const ValueKey('note-text-indent')));
        await tester.pumpAndSettle();
      }
      for (var index = 0; index < 5; index += 1) {
        await tester.tap(find.byKey(const ValueKey('note-text-outdent')));
        await tester.pumpAndSettle();
      }

      expect(latest!.text, text);
      final editableLeft = tester
          .getRect(find.byKey(const ValueKey('note-text-input-bridge')))
          .left;
      final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final diagnostic =
          'editableLeft=${editableLeft.toStringAsFixed(1)} '
          'bounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)}').join(';')} '
          'text=${latest!.text} logs=${DebugConsole.allText}';

      expect(lineBounds.length, greaterThan(2));
      for (final line in lineBounds) {
        expect(
          line.left,
          closeTo(editableLeft, 1.5),
          reason:
              'After returning to zero indent, every native wrapped row must '
              'start at the editor left edge. $diagnostic',
        );
      }
    },
  );

  testWidgets('text rail exposes table-like design toggles and scroll row', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      surfaceSize: const Size(260, 700),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-selection-action-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-white')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('note-text-rail-toggle-rounded')),
    );
    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-rounded')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-rounded')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('note-text-rail-toggle-grey')),
    );
    await tester.tap(find.byKey(const ValueKey('note-text-rail-toggle-grey')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-grey')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('note-text-rail-toggle-border')),
    );
    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-border')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-borderless')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
  Size surfaceSize = const Size(420, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surfaceSize;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: NoteTextChunkEditorScreen(
        block: block,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setEditorSelection(WidgetTester tester, TextSelection selection) {
  final editable = _editableText(tester);
  editable.controller.selection = selection;
  editable.focusNode.requestFocus();
}

Finder _editableTextFinder() {
  return find.descendant(
    of: find.byKey(const ValueKey('note-text-input-bridge')),
    matching: find.byType(EditableText),
  );
}

EditableText _editableText(WidgetTester tester) {
  return tester.widget<EditableText>(_editableTextFinder());
}

EditableTextState _editableTextState(WidgetTester tester) {
  return tester.state<EditableTextState>(_editableTextFinder());
}

Rect _nativeEditableSelectionRect(
  WidgetTester tester,
  TextSelection selection,
) {
  final state = _editableTextState(tester);
  final renderEditable = state.renderEditable;
  final boxes = renderEditable.getBoxesForSelection(selection);
  expect(boxes, isNotEmpty);
  final localRect = boxes
      .map((box) => box.toRect())
      .reduce((value, element) => value.expandToInclude(element));
  final topLeft = renderEditable.localToGlobal(Offset.zero);
  return localRect.shift(topLeft);
}

Rect _nativeEditableSubstringRect(WidgetTester tester, String text) {
  final state = _editableTextState(tester);
  final plainText = state.renderEditable.text!.toPlainText();
  final start = plainText.indexOf(text);
  expect(start, isNonNegative);
  return _nativeEditableSelectionRect(
    tester,
    TextSelection(baseOffset: start, extentOffset: start + text.length),
  );
}

Rect _nativeEditableSubstringTightRect(WidgetTester tester, String text) {
  final state = _editableTextState(tester);
  final renderEditable = state.renderEditable;
  final previousWidthStyle = renderEditable.selectionWidthStyle;
  final previousHeightStyle = renderEditable.selectionHeightStyle;
  renderEditable.selectionWidthStyle = ui.BoxWidthStyle.tight;
  renderEditable.selectionHeightStyle = ui.BoxHeightStyle.tight;
  try {
    return _nativeEditableSubstringRect(tester, text);
  } finally {
    renderEditable.selectionWidthStyle = previousWidthStyle;
    renderEditable.selectionHeightStyle = previousHeightStyle;
  }
}

List<NoteKnowledgeTag> _stackedTags() {
  return _tagsWithSecondary(10);
}

List<NoteKnowledgeTag> _tagsWithSecondary(int secondaryCount) {
  return [
    const NoteKnowledgeTag(
      type: NoteKnowledgeTagTypes.state,
      label: 'primary',
      colorValue: 0xFFDC2626,
    ),
    for (var index = 1; index <= secondaryCount; index += 1)
      NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.custom,
        label: 'secondary-$index',
        colorValue: 0xFF2563EB + index,
      ),
  ];
}

List<double> _nativeEditableNonEmptyLineLefts(WidgetTester tester) {
  return [
    for (final line in _nativeEditableNonEmptyLineBounds(tester)) line.left,
  ];
}

List<Rect> _nativeEditableNonEmptyLineBounds(WidgetTester tester) {
  final state = _editableTextState(tester);
  final renderEditable = state.renderEditable;
  final plainText = renderEditable.text!.toPlainText();
  final lineRects = <Rect>[];
  final lineTops = <double>[];
  for (var offset = 0; offset < plainText.length; offset += 1) {
    final codeUnit = plainText.codeUnitAt(offset);
    if (codeUnit == 10 || codeUnit == 32 || codeUnit == 0xFFFC) {
      continue;
    }
    final boxes = renderEditable.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    if (boxes.isEmpty) {
      continue;
    }
    final rect = boxes.first.toRect().shift(
      renderEditable.localToGlobal(Offset.zero),
    );
    final existingLine = lineTops.indexWhere(
      (top) => (top - rect.top).abs() < 2,
    );
    if (existingLine >= 0) {
      lineRects[existingLine] = lineRects[existingLine].expandToInclude(rect);
      continue;
    }
    lineTops.add(rect.top);
    lineRects.add(rect);
  }
  final ordered = [
    for (var index = 0; index < lineRects.length; index += 1)
      (top: lineTops[index], rect: lineRects[index]),
  ]..sort((a, b) => a.top.compareTo(b.top));
  return [for (final line in ordered) line.rect];
}
