import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/native_selection_rail_bridge.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nativeRailChannel = MethodChannel('test.djinn.selection_rail/native');

  setUp(DebugConsole.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRailChannel, null);
  });

  testWidgets('plain editor text stays identical to block text', (
    tester,
  ) async {
    const text = 'Alpha Beta\nGamma\n\nDelta';
    final calls = <MethodCall>[];
    final controller = _installNativeRailController(calls, nativeRailChannel);
    addTearDown(controller.dispose);

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      nativeSelectionRailController: controller,
    );

    final editable = tester.widget<EditableText>(_editableTextFinder());
    expect(editable.controller.text, text);
    expect(DebugConsole.allText, isNot(contains('rail-line-')));
    expect(DebugConsole.allText, isNot(contains('underline-line-')));
    expect(DebugConsole.allText, isNot(contains('placeholderDelta=')));
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      findsNothing,
    );
  });

  testWidgets('selection can span the whole text chunk and shows native rail', (
    tester,
  ) async {
    const text = 'Alpha Beta\nGamma\n\nDelta';
    final calls = <MethodCall>[];
    final controller = _installNativeRailController(calls, nativeRailChannel);
    addTearDown(controller.dispose);

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      nativeSelectionRailController: controller,
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    await tester.pumpAndSettle();

    final state = _lastNativeRailState(calls);
    expect(state, containsPair('visible', true));
    expect(state, containsPair('rangeStart', 0));
    expect(state, containsPair('rangeEnd', text.length));
  });

  testWidgets('collapsed cursor inside tagged range shows native rail', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final controller = _installNativeRailController(calls, nativeRailChannel);
    addTearDown(controller.dispose);

    await _pumpTextChunkEditor(
      tester,
      NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
        rangeTags: const [
          NoteTextRangeTag(id: 'range-beta', start: 6, end: 10, tag: _topicTag),
        ],
      ),
      nativeSelectionRailController: controller,
    );

    _setEditorSelection(tester, const TextSelection.collapsed(offset: 8));
    await tester.pumpAndSettle();

    final state = _lastNativeRailState(calls);
    expect(state, containsPair('visible', true));
    expect(state, containsPair('rangeStart', 6));
    expect(state, containsPair('rangeEnd', 10));
    expect(state['tags'], [
      {'id': 'topic:Topic', 'label': 'Topic', 'colorValue': 0xFF2563EB},
    ]);
  });

  testWidgets('ordinary untagged typing keeps native rail hidden', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    final controller = _installNativeRailController(calls, nativeRailChannel);
    addTearDown(controller.dispose);
    NoteBlock? latest;

    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: ''),
      onChanged: (block) => latest = block,
      nativeSelectionRailController: controller,
    );

    await tester.enterText(_editableTextFinder(), 'Alpha Beta');
    await tester.pumpAndSettle();

    expect(latest?.text, 'Alpha Beta');
    final visibleCalls = calls.where(
      (call) =>
          call.method == 'setState' &&
          (call.arguments as Map<Object?, Object?>)['visible'] == true,
    );
    expect(visibleCalls, isEmpty);
  });

  testWidgets(
    'secondary underlines paint over native glyph boxes and expand content height',
    (tester) async {
      const text = 'Alpha Beta Gamma';
      final calls = <MethodCall>[];
      final controller = _installNativeRailController(calls, nativeRailChannel);
      addTearDown(controller.dispose);

      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        nativeSelectionRailController: controller,
      );
      final plainHeight = tester.getSize(_editableTextFinder()).height;

      await _pumpTextChunkEditor(
        tester,
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
          rangeTags: const [
            NoteTextRangeTag(
              id: 'range-beta',
              start: 6,
              end: 10,
              tag: _topicTag,
              tags: [_topicTag, _stateTag, _customTag, _warningTag],
            ),
          ],
        ),
        nativeSelectionRailController: controller,
      );

      final editable = tester.widget<EditableText>(_editableTextFinder());
      expect(editable.controller.text, text);
      expect(
        find.byKey(const ValueKey('note-text-secondary-underline-overlay')),
        findsOneWidget,
      );
      expect(
        tester.getSize(_editableTextFinder()).height,
        greaterThan(plainHeight),
      );
    },
  );
}

const _topicTag = NoteKnowledgeTag(
  type: NoteKnowledgeTagTypes.topic,
  label: 'Topic',
  colorValue: 0xFF2563EB,
);

const _stateTag = NoteKnowledgeTag(
  type: NoteKnowledgeTagTypes.state,
  label: 'State',
  colorValue: 0xFFDC2626,
);

const _customTag = NoteKnowledgeTag(
  type: NoteKnowledgeTagTypes.custom,
  label: 'Custom',
  colorValue: 0xFF059669,
);

const _warningTag = NoteKnowledgeTag(
  type: NoteKnowledgeTagTypes.symbol,
  label: 'Risk',
  colorValue: 0xFFF59E0B,
);

NativeSelectionRailController _installNativeRailController(
  List<MethodCall> calls,
  MethodChannel channel,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
  return NativeSelectionRailController(methodChannel: channel);
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
  NativeSelectionRailController? nativeSelectionRailController,
}) async {
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

Finder _editableTextFinder() => find.descendant(
  of: find.byKey(const ValueKey('note-text-native-editor')),
  matching: find.byType(EditableText),
);

void _setEditorSelection(WidgetTester tester, TextSelection selection) {
  final editable = tester.widget<EditableText>(_editableTextFinder());
  editable.controller.selection = selection;
}

Map<Object?, Object?> _lastNativeRailState(List<MethodCall> calls) {
  return calls
      .where((call) => call.method == 'setState')
      .map((call) => call.arguments as Map<Object?, Object?>)
      .last;
}
