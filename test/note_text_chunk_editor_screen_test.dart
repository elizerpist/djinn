import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/native_selection_rail_bridge.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  setUp(DebugConsole.clear);

  const nativeRailChannel = MethodChannel('test.djinn.selection_rail/native');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, null);
  });

  testWidgets('selection sends native rail state and no inline rail', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (call) async {
          calls.add(call);
          return null;
        });
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      nativeSelectionRailController: controller,
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    final state = _lastNativeRailState(calls);
    expect(state, containsPair('visible', true));
    expect(state, containsPair('rangeStart', 6));
    expect(state, containsPair('rangeEnd', 10));
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
  });

  testWidgets('collapsed cursor inside tagged range sends native rail state', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (call) async {
          calls.add(call);
          return null;
        });
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);

    await _pumpTextChunkEditor(
      tester,
      NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
        rangeTags: const [
          NoteTextRangeTag(
            id: 'range-alpha',
            start: 0,
            end: 5,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Alpha',
              colorValue: 0xFF2563EB,
            ),
          ),
        ],
      ),
      nativeSelectionRailController: controller,
    );

    _setEditorSelection(tester, const TextSelection.collapsed(offset: 2));
    await tester.pumpAndSettle();

    final state = _lastNativeRailState(calls);
    expect(state, containsPair('visible', true));
    expect(state, containsPair('rangeStart', 0));
    expect(state, containsPair('rangeEnd', 5));
    expect(state['tags'], [
      {'id': 'topic:Alpha', 'label': 'Alpha', 'colorValue': 0xFF2563EB},
    ]);
  });

  testWidgets('ordinary untagged typing keeps native rail hidden', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (call) async {
          calls.add(call);
          return null;
        });
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: ''),
      nativeSelectionRailController: controller,
    );

    await tester.enterText(_editableTextFinder(), 'Alpha Beta');
    await tester.pumpAndSettle();

    final state = _lastNativeRailState(calls);
    expect(state, containsPair('visible', false));
    expect(
      calls.where(
        (call) =>
            call.method == 'setState' &&
            (call.arguments as Map<Object?, Object?>)['visible'] == true,
      ),
      isEmpty,
    );
  });

  testWidgets('native indent action uses paragraph indentation', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (call) async {
          calls.add(call);
          return null;
        });
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);
    NoteBlock? latest;

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      onChanged: (block) => latest = block,
      nativeSelectionRailController: controller,
    );
    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pumpAndSettle();

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          nativeRailChannel.name,
          nativeRailChannel.codec.encodeMethodCall(
            const MethodCall('performAction', {'action': 'indent'}),
          ),
          (_) {},
        );
    await tester.pumpAndSettle();

    expect(latest?.text, startsWith('  '));
    expect(DebugConsole.allText, contains('[TextChunkStep] delta=1'));
  });

  testWidgets('native outdent action uses paragraph indentation', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (_) async => null);
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);
    NoteBlock? latest;

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: '  Alpha Beta Gamma',
      ),
      onChanged: (block) => latest = block,
      nativeSelectionRailController: controller,
    );
    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 2, extentOffset: 7),
    );
    await tester.pumpAndSettle();

    await _performNativeRailAction(nativeRailChannel, 'outdent');
    await tester.pumpAndSettle();

    expect(latest?.text, startsWith('Alpha'));
    expect(DebugConsole.allText, contains('[TextChunkStep] delta=-1'));
  });

  testWidgets(
    'native clear and delete tag actions update selected range tags',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeRailChannel, (_) async => null);
      final controller = NativeSelectionRailController(
        methodChannel: nativeRailChannel,
      );
      addTearDown(controller.dispose);
      NoteBlock? latest;
      const primary = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'Primary',
        colorValue: 0xFF2563EB,
      );
      const secondary = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.state,
        label: 'Secondary',
        colorValue: 0xFFDC2626,
      );

      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha Beta Gamma',
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-beta',
              start: 6,
              end: 10,
              tag: primary,
              tags: [primary, secondary],
            ),
          ],
        ),
        onChanged: (block) => latest = block,
        nativeSelectionRailController: controller,
      );
      _setEditorSelection(tester, const TextSelection.collapsed(offset: 7));
      await tester.pumpAndSettle();

      await _performNativeRailAction(
        nativeRailChannel,
        'deleteTag',
        tagId: primary.metadataText,
      );
      await tester.pumpAndSettle();

      expect(latest?.rangeTags, hasLength(1));
      expect(latest!.rangeTags.single.resolvedTags, [secondary]);

      await _performNativeRailAction(nativeRailChannel, 'clearTags');
      await tester.pumpAndSettle();

      expect(latest?.rangeTags, isEmpty);
    },
  );

  testWidgets('native previous and next actions focus tagged ranges', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (call) async {
          calls.add(call);
          return null;
        });
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);
    const tag = NoteKnowledgeTag(
      type: NoteKnowledgeTagTypes.topic,
      label: 'Tag',
      colorValue: 0xFF2563EB,
    );

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
        rangeTags: [
          NoteTextRangeTag(id: 'range-alpha', start: 0, end: 5, tag: tag),
          NoteTextRangeTag(id: 'range-gamma', start: 11, end: 16, tag: tag),
        ],
      ),
      nativeSelectionRailController: controller,
    );
    _setEditorSelection(tester, const TextSelection.collapsed(offset: 2));
    await tester.pumpAndSettle();

    await _performNativeRailAction(nativeRailChannel, 'nextTag');
    await tester.pumpAndSettle();

    var state = _lastNativeRailState(calls);
    expect(state, containsPair('rangeStart', 11));
    expect(state, containsPair('rangeEnd', 16));

    await _performNativeRailAction(nativeRailChannel, 'previousTag');
    await tester.pumpAndSettle();

    state = _lastNativeRailState(calls);
    expect(state, containsPair('rangeStart', 0));
    expect(state, containsPair('rangeEnd', 5));
  });

  testWidgets('selection does not insert an inline rail into text layout', (
    tester,
  ) async {
    const text = 'Alpha\nBeta\nGamma';
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    expect(_nativeEditablePlainText(tester), text);
    expect(DebugConsole.allText, isNot(contains('rail-line-')));
    expect(DebugConsole.allText, contains('placeholderDelta=0'));
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
  });

  testWidgets(
    'selection keeps native editable text geometry unshifted by rail',
    (tester) async {
      const text = 'Alpha\nBeta\nGamma';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      await tester.pumpAndSettle();

      final alpha = _nativeEditableSubstringRect(tester, 'Alpha');
      final beta = _nativeEditableSubstringRect(tester, 'Beta');

      expect(beta.top, greaterThanOrEqualTo(alpha.bottom));
      expect(beta.top - alpha.bottom, lessThanOrEqualTo(24));
      expect(DebugConsole.allText, isNot(contains('rail-line-')));
      expect(DebugConsole.allText, contains('placeholderDelta=0'));
    },
  );

  testWidgets('soft-wrapped selection does not create rail placeholders', (
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
    final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
    final diagnostic =
        'target=$targetRect '
        'lineBounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)},${line.bottom.toStringAsFixed(1)}').join(';')} '
        'logs=${DebugConsole.allText}';

    expect(targetRect.width, greaterThan(0), reason: diagnostic);
    expect(lineBounds, isNotEmpty, reason: diagnostic);
    expect(DebugConsole.allText, isNot(contains('rail-line-')));
    expect(DebugConsole.allText, contains('placeholderDelta=0'));
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
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
    expect(DebugConsole.allText, contains('railLine=null'));
    expect(DebugConsole.allText, contains('placeholderCount='));
    expect(DebugConsole.allText, contains('railGap=null'));
    expect(DebugConsole.allText, contains('railHeight=null'));
    expect(DebugConsole.allText, contains('railTargetSpacer=null'));
    expect(DebugConsole.allText, contains('railNativeSpacer=null'));
    expect(DebugConsole.allText, contains('railRoundedGap=null'));
    expect(DebugConsole.allText, contains('railLineBreaks=0'));
    expect(DebugConsole.allText, contains('railLeadingUnderlineSpacer=false'));
    expect(DebugConsole.allText, contains('railSoftWrapTerminator=false'));
    expect(DebugConsole.allText, contains('railNativeLines=0'));
    expect(DebugConsole.allText, contains('railPlaceholderBreaks=0'));
    expect(DebugConsole.allText, contains('[TextChunkLayout] nativeGeometry'));
    expect(DebugConsole.allText, contains('nativeOrigins='));
    expect(DebugConsole.allText, contains('tightTagBoxes=true'));
    expect(DebugConsole.allText, contains('underlineRects='));
    expect(DebugConsole.allText, contains('placeholderDelta=0'));
    expect(DebugConsole.allText, isNot(contains('rail-line-')));
  });

  testWidgets(
    'multi-line selection keeps rail out of the Flutter text layout',
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

      final line2 = tester.getRect(
        find.byKey(const ValueKey('note-text-line-2')),
      );

      expect(line2.height, greaterThan(0));
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsNothing,
      );
      expect(DebugConsole.allText, isNot(contains('rail-line-')));
    },
  );

  testWidgets('selection handle drag keeps Flutter text layout rail-free', (
    tester,
  ) async {
    const text = 'Alpha\nBeta\nGamma\nDelta';
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    final gammaEnd = text.indexOf('Gamma') + 'Gamma'.length;
    await _simulateNativeSelectionDrag(
      tester,
      TextSelection(baseOffset: 0, extentOffset: gammaEnd),
    );

    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
      reason:
          'While a native selection handle is being dragged, the rail must not '
          'reserve space or move underneath the handle.',
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
      reason:
          'During native handle drag the EditableText span must contain only '
          'the real text; hidden rail placeholders break handle movement.',
    );
    expect(
      _nativeEditablePlainText(tester),
      text,
      reason: 'Drag hiding must remove rail placeholders from EditableText.',
    );

    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
      reason:
          'Sparse native drag updates must not let a timer reinsert the rail '
          'while the handle is still being held.',
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
    expect(_nativeEditablePlainText(tester), text);

    final editable = _editableText(tester);
    editable.onSelectionChanged?.call(
      TextSelection(baseOffset: 0, extentOffset: gammaEnd),
      SelectionChangedCause.tap,
    );
    await tester.pumpAndSettle();

    expect(
      _nativeEditableSubstringRect(tester, 'Gamma').height,
      greaterThan(0),
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
  });

  testWidgets('touching a native selection handle keeps inline rail absent', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma\nDelta',
      ),
    );

    await tester.longPressAt(
      _nativeEditableSubstringRect(tester, 'Alpha').center,
    );
    await tester.pumpAndSettle();

    expect(
      _editableTextState(tester).textEditingValue.selection.isCollapsed,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('note-text-native-selection-handle-right')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );

    final handle = find.byKey(
      const ValueKey('note-text-native-selection-handle-right'),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
      reason:
          'The rail must disappear as soon as the native handle is touched, '
          'before the first drag delta arrives.',
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );

    await gesture.up();
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
      reason: 'The rail is native Android UI, not a Flutter inline widget.',
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
  });

  testWidgets('native handle drag uses real text without rail placeholders', (
    tester,
  ) async {
    const text =
        'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda '
        'mu nu xi omicron';
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      surfaceSize: Size(420, 900),
    );

    await tester.longPressAt(
      _nativeEditableSubstringRect(tester, 'gamma').center,
    );
    await tester.pumpAndSettle();

    expect(
      _editableTextState(tester).textEditingValue.selection.isCollapsed,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
      reason: 'Rail no longer reserves native text-layout space.',
    );
    expect(DebugConsole.allText, isNot(contains('rail-line-')));

    DebugConsole.clear();
    final selection = _editableTextState(tester).textEditingValue.selection;
    await _simulateNativeSelectionDrag(
      tester,
      TextSelection(baseOffset: selection.start, extentOffset: text.length),
    );

    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
    expect(_nativeEditablePlainText(tester), text);
    expect(DebugConsole.allText, isNot(contains('rail-line-')));
    expect(DebugConsole.allText, contains('placeholderDelta=0'));
  });

  testWidgets(
    'native drag callback does not mutate selection or editable presentation',
    (tester) async {
      const text = 'Alpha\nBeta\nGamma\nDelta';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.pumpAndSettle();

      final editable = _editableText(tester);
      final beforeSelection = editable.controller.selection;

      editable.onSelectionChanged?.call(
        TextSelection(baseOffset: 0, extentOffset: text.length),
        SelectionChangedCause.drag,
      );
      await tester.pump();

      expect(
        editable.controller.selection,
        beforeSelection,
        reason:
            'During native handle drag, Flutter owns selection updates. The '
            'editor must not normalize and write controller.selection back.',
      );
      expect(
        _nativeEditablePlainText(tester),
        text,
        reason:
            'During native handle drag, hiding rail UI must remove rail '
            'placeholders from EditableText.',
      );
    },
  );

  testWidgets(
    'native rail row toggle does not resize the editable text layout',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeRailChannel, (call) async {
            calls.add(call);
            return null;
          });
      final controller = NativeSelectionRailController(
        methodChannel: nativeRailChannel,
      );
      addTearDown(controller.dispose);
      const text = 'Alpha\nBeta\nGamma';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        nativeSelectionRailController: controller,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      await tester.pumpAndSettle();

      final expandedBeta = _nativeEditableSubstringRect(tester, 'Beta');
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsNothing,
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            nativeRailChannel.name,
            nativeRailChannel.codec.encodeMethodCall(
              const MethodCall('performAction', {'action': 'toggleTags'}),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();

      final collapsedBeta = _nativeEditableSubstringRect(tester, 'Beta');
      final state = _lastNativeRailState(calls);
      final style = state['style'] as Map<Object?, Object?>;

      expect(style['bottomRowExpanded'], false);
      expect(collapsedBeta.top, expandedBeta.top);
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'continuous selection spans paragraphs without inline rail anchoring',
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
      final selectedLine = tester.getRect(
        find.byKey(const ValueKey('note-text-line-3')),
      );
      expect(selectedLine.height, greaterThan(0));
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
        findsNothing,
      );
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

    expect(editableRect.height, greaterThan(0));
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
    'native tag action saves primary and secondary tags to the selected range',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeRailChannel, (_) async => null);
      final controller = NativeSelectionRailController(
        methodChannel: nativeRailChannel,
      );
      addTearDown(controller.dispose);
      NoteBlock? latest;
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha Beta Gamma',
        ),
        onChanged: (block) => latest = block,
        nativeSelectionRailController: controller,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 6, extentOffset: 10),
      );
      await tester.pumpAndSettle();
      await _performNativeRailAction(nativeRailChannel, 'tagSelection');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (_) async => null);
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);
    NoteBlock? latest;
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      onChanged: (block) => latest = block,
      nativeSelectionRailController: controller,
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();
    await _performNativeRailAction(nativeRailChannel, 'tagSelection');
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

  testWidgets('rail is not hosted by the Flutter editable text layout', (
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
      findsNothing,
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

    Future<({Rect targetRect, Rect nextLine, String logs})>
    pumpWithSecondaryTags(int secondaryCount) async {
      DebugConsole.clear();
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
      return (
        targetRect: targetRect,
        nextLine: nextLine,
        logs: DebugConsole.allText,
      );
    }

    final none = await pumpWithSecondaryTags(0);
    final one = await pumpWithSecondaryTags(1);
    final five = await pumpWithSecondaryTags(5);
    final eight = await pumpWithSecondaryTags(8);
    final noneGap = none.nextLine.top - none.targetRect.top;
    final oneGap = one.nextLine.top - one.targetRect.top;
    final fiveGap = five.nextLine.top - five.targetRect.top;
    final eightGap = eight.nextLine.top - eight.targetRect.top;
    final diagnostic =
        'noneGap=${noneGap.toStringAsFixed(1)} '
        'oneGap=${oneGap.toStringAsFixed(1)} '
        'fiveGap=${fiveGap.toStringAsFixed(1)} '
        'eightGap=${eightGap.toStringAsFixed(1)} '
        'noneLogs=${none.logs} oneLogs=${one.logs} '
        'fiveLogs=${five.logs} eightLogs=${eight.logs}';

    expect(
      oneGap,
      closeTo(noneGap, 2),
      reason:
          'One secondary underline fits below the word and must not stretch '
          'the following native text line. $diagnostic',
    );
    expect(
      one.logs,
      isNot(contains('underline-line-')),
      reason:
          'A single underline must be drawn without an underline placeholder. '
          '$diagnostic',
    );
    expect(
      fiveGap,
      greaterThan(oneGap),
      reason:
          'Five underline lanes need some native spacing below the tagged '
          'line. $diagnostic',
    );
    expect(
      eightGap,
      greaterThan(fiveGap),
      reason:
          'Reducing many lanes down to five must shrink the reserved native '
          'spacing immediately. $diagnostic',
    );
    expect(
      five.logs,
      contains('underline-line-'),
      reason:
          'Five underline lanes should still use a native spacer, just a '
          'smaller one than eight lanes. $diagnostic',
    );
    expect(
      none.logs,
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
    'stacked underlines keep spacing while rail stays outside text layout',
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
      final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final diagnostic =
          'target=$targetRect lastUnderline=$lastUnderline '
          'lineBounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)},${line.bottom.toStringAsFixed(1)}').join(';')} '
          'logs=${DebugConsole.allText}';

      expect(lastUnderline.top, greaterThan(targetRect.bottom));
      expect(
        lineBounds.any((line) => line.top > lastUnderline.bottom),
        isTrue,
        reason: diagnostic,
      );
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'stacked underline spacer preserves indented soft-wrap continuation',
    (tester) async {
      const text =
          '    Holnap reggel holnap reggel holnap reggel reggel holnap reggel';
      final rangeStart = text.indexOf('Holnap');
      final rangeEnd = text.indexOf(' reggel reggel');
      await _pumpTextChunkEditor(
        tester,
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-holnap',
              start: rangeStart,
              end: rangeEnd,
              tag: _tagsWithSecondary(5).first,
              tags: _tagsWithSecondary(5),
            ),
          ],
        ),
        surfaceSize: const Size(300, 700),
      );

      final firstText = _nativeEditableRangeTightRect(
        tester,
        rangeStart,
        rangeStart + 1,
      );
      final lineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final diagnostic =
          'firstText=$firstText '
          'bounds=${lineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)}').join(';')} '
          'logs=${DebugConsole.allText}';

      expect(lineBounds.length, greaterThan(1), reason: diagnostic);
      expect(
        DebugConsole.allText,
        contains('underline-line-'),
        reason: diagnostic,
      );
      for (final line in lineBounds) {
        expect(
          line.left,
          greaterThanOrEqualTo(firstText.left - 1.5),
          reason:
              'Every real native row after an underline spacer must keep the '
              'paragraph indent. $diagnostic',
        );
      }
    },
  );

  testWidgets(
    'native rail paragraph step indents every visual line in the active paragraph',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativeRailChannel, (_) async => null);
      final controller = NativeSelectionRailController(
        methodChannel: nativeRailChannel,
      );
      addTearDown(controller.dispose);
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
        nativeSelectionRailController: controller,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      await tester.pumpAndSettle();
      await _performNativeRailAction(nativeRailChannel, 'indent');
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

  testWidgets(
    'native drag after repeated paragraph stepping keeps native margin stable',
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
      for (var index = 0; index < 8; index += 1) {
        await tester.tap(find.byKey(const ValueKey('note-text-indent')));
        await tester.pumpAndSettle();
      }
      for (var index = 0; index < 5; index += 1) {
        await tester.tap(find.byKey(const ValueKey('note-text-outdent')));
        await tester.pumpAndSettle();
      }

      final beforeBridgeLeft = tester
          .getRect(find.byKey(const ValueKey('note-text-input-bridge')))
          .left;
      final beforeLineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final activeMarginLeft = beforeLineBounds.first.left;

      expect(beforeLineBounds.length, greaterThan(2));
      for (final line in beforeLineBounds) {
        expect(line.left, greaterThanOrEqualTo(activeMarginLeft - 1.5));
      }

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsNothing,
      );

      final omegaEnd = latest!.text.indexOf('omega') + 'omega'.length;
      await _simulateNativeSelectionDrag(
        tester,
        TextSelection(baseOffset: 0, extentOffset: omegaEnd),
      );
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsNothing,
      );
      expect(
        _nativeEditablePlainText(tester),
        latest!.text,
        reason:
            'Native drag must remove the rail placeholder and keep only the '
            'real editor text after paragraph step reflow.',
      );

      final afterBridgeLeft = tester
          .getRect(find.byKey(const ValueKey('note-text-input-bridge')))
          .left;
      final afterLineBounds = _nativeEditableNonEmptyLineBounds(tester);
      final diagnostic =
          'beforeBridge=$beforeBridgeLeft afterBridge=$afterBridgeLeft '
          'activeMargin=$activeMarginLeft '
          'bounds=${afterLineBounds.map((line) => '${line.left.toStringAsFixed(1)},${line.top.toStringAsFixed(1)},${line.right.toStringAsFixed(1)}').join(';')} '
          'logs=${DebugConsole.allText}';

      expect(afterBridgeLeft, closeTo(beforeBridgeLeft, 0.5));
      expect(afterLineBounds.length, greaterThan(2), reason: diagnostic);
      for (final line in afterLineBounds) {
        expect(
          line.left,
          greaterThanOrEqualTo(activeMarginLeft - 1.5),
          reason:
              'Handle drag layout changes must not let any paragraph row '
              'jump left of the active indent. $diagnostic',
        );
      }
    },
  );

  testWidgets('native rail style toggles update serialized style state', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, (call) async {
          calls.add(call);
          return null;
        });
    final controller = NativeSelectionRailController(
      methodChannel: nativeRailChannel,
    );
    addTearDown(controller.dispose);
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      surfaceSize: const Size(260, 700),
      nativeSelectionRailController: controller,
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    await _performNativeRailAction(nativeRailChannel, 'toggleRounded');
    await tester.pumpAndSettle();
    var style = _lastNativeRailState(calls)['style'] as Map<Object?, Object?>;
    expect(style['roundedCard'], true);

    await _performNativeRailAction(nativeRailChannel, 'toggleGrey');
    await tester.pumpAndSettle();
    style = _lastNativeRailState(calls)['style'] as Map<Object?, Object?>;
    expect(style['greyBackground'], true);

    await _performNativeRailAction(nativeRailChannel, 'toggleBorder');
    await tester.pumpAndSettle();
    style = _lastNativeRailState(calls)['style'] as Map<Object?, Object?>;
    expect(style['borderVisible'], false);
  });
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
  NativeSelectionRailController? nativeSelectionRailController,
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
        nativeSelectionRailController: nativeSelectionRailController,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<Object?, Object?> _lastNativeRailState(List<MethodCall> calls) {
  final setStateCalls = calls
      .where((call) => call.method == 'setState')
      .toList(growable: false);
  expect(setStateCalls, isNotEmpty);
  return setStateCalls.last.arguments as Map<Object?, Object?>;
}

Future<void> _performNativeRailAction(
  MethodChannel channel,
  String action, {
  String? tagId,
}) {
  final payload = <String, String>{'action': action};
  if (tagId != null) {
    payload['tagId'] = tagId;
  }
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('performAction', payload)),
        (_) {},
      );
}

void _setEditorSelection(WidgetTester tester, TextSelection selection) {
  final editable = _editableText(tester);
  editable.controller.selection = selection;
  editable.focusNode.requestFocus();
}

Future<void> _simulateNativeSelectionDrag(
  WidgetTester tester,
  TextSelection selection,
) async {
  final editable = _editableText(tester);
  editable.controller.selection = selection;
  editable.focusNode.requestFocus();
  editable.onSelectionChanged?.call(selection, SelectionChangedCause.drag);
  await tester.pump();
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

String _nativeEditablePlainText(WidgetTester tester) {
  return _editableTextState(tester).renderEditable.text!.toPlainText();
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

Rect _nativeEditableRangeTightRect(WidgetTester tester, int start, int end) {
  final state = _editableTextState(tester);
  final renderEditable = state.renderEditable;
  final previousWidthStyle = renderEditable.selectionWidthStyle;
  final previousHeightStyle = renderEditable.selectionHeightStyle;
  renderEditable.selectionWidthStyle = ui.BoxWidthStyle.tight;
  renderEditable.selectionHeightStyle = ui.BoxHeightStyle.tight;
  try {
    return _nativeEditableSelectionRect(
      tester,
      TextSelection(baseOffset: start, extentOffset: end),
    );
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
    if (codeUnit == 10 ||
        codeUnit == 32 ||
        codeUnit == 0x00A0 ||
        codeUnit == 0x200B ||
        codeUnit == 0xFFFC) {
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
