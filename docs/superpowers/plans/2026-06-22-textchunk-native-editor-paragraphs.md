# Text Chunk Native Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the text chunk runtime so native text selection works while retaining keyboard rail, tag coloring, secondary underline spacing, and paragraph metadata.

**Architecture:** Keep one native `EditableText` surface for the whole text chunk. Move paragraph behavior into metadata, keep tag styling in real text spans, and keep the rail outside the editable text layout through the existing native rail transport.

**Tech Stack:** Flutter/Dart, `EditableText`, `TextEditingController.buildTextSpan`, MethodChannel native rail bridge, Android Kotlin rail renderer, Flutter widget/unit tests, GitHub Actions Android build.

## Global Constraints

- Native text selection must remain the primary interaction model.
- The editable text string must stay semantically clean.
- Paragraph indent, rail spacing, underline spacing, and visual layout must never insert spaces, newlines, placeholders, widget spans, or hidden markers into the text.
- Rail remains keyboard-anchored and uses the table/list rail visual contract.
- Tag coloring uses normal text span styling only.
- Secondary underlines reserve line spacing for affected ranges without participating in hit testing.
- Single enter stays inside a paragraph; double enter starts a new paragraph.
- Step in/out changes paragraph metadata and must not change text length.
- Whole text chunk selection must remain possible through one native editable surface.
- If native-safe visible per-paragraph indent cannot be proven, mark visual indent BLOCKED rather than faking it.

---

## File Structure

Delete and replace:

- `lib/src/notes/ui/text_chunk/text_chunk_editor.dart`
- `lib/src/notes/ui/text_chunk/text_chunk_controller.dart`
- `lib/src/notes/ui/text_chunk/text_chunk_underlines.dart`
- `lib/src/notes/ui/text_chunk/text_chunk_ranges.dart`
- `lib/src/notes/ui/text_chunk/text_chunk_rail_state.dart`

Create:

- `lib/src/notes/ui/text_chunk/native_text_chunk_editor.dart`
  Owns the minimal `EditableText` widget. No outer gesture wrapper, no editor-owned scroll wrapper, no hit-test overlay.

- `lib/src/notes/ui/text_chunk/text_chunk_span_controller.dart`
  A `TextEditingController` that builds real `TextSpan`s for tag background and secondary underline line-height.

- `lib/src/notes/ui/text_chunk/text_chunk_text_edits.dart`
  Diff/edit helpers shared by range tag and paragraph style remapping.

- `lib/src/notes/ui/text_chunk/text_chunk_paragraphs.dart`
  Paragraph boundary detection, paragraph style remapping, and step in/out metadata transforms.

- `lib/src/notes/ui/text_chunk/text_chunk_rail.dart`
  Converts current text selection and range tags into `NativeSelectionRailState`.

Modify:

- `lib/src/notes/models/note_document.dart`
  Add `NoteTextParagraphStyle` and `NoteBlock.paragraphStyles` serialization.

- `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
  Replace editor runtime with the new minimal editor and metadata-based paragraph actions.

- `lib/src/notes/ui/native_selection_rail_bridge.dart`
  Keep transport; adjust action payloads only if the new rail state needs smaller surface.

- `android/app/src/main/kotlin/com/elizerpist/djinn/rail/NativeSelectionRailBridge.kt`
  Keep visual design; change only if payload contract changes.

Test:

- `test/note_document_test.dart`
- Replace `test/text_chunk_layout_model_test.dart` with `test/text_chunk_paragraphs_test.dart`
- Rewrite `test/note_text_chunk_editor_screen_test.dart`
- Keep/adjust `test/native_selection_rail_bridge_test.dart`
- Update `test/note_editor_route_test.dart` if finder keys change.

---

### Task 1: Paragraph Metadata Model

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Test: `test/note_document_test.dart`

**Interfaces:**
- Produces:
  - `class NoteTextParagraphStyle`
  - `NoteBlock.paragraphStyles`
  - `NoteTextParagraphStyle.fromJson(Object? value)`
  - `NoteTextParagraphStyle.toJson()`
  - `NoteTextParagraphStyle.copyWith(...)`

- [ ] **Step 1: Write failing serialization tests**

Add tests to `test/note_document_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_document_test.dart'
```

Expected: FAIL because `paragraphStyles` and `NoteTextParagraphStyle` do not exist.

- [ ] **Step 3: Implement the model**

In `lib/src/notes/models/note_document.dart`, add:

```dart
class NoteTextParagraphStyle {
  const NoteTextParagraphStyle({
    required this.id,
    required this.start,
    required this.end,
    this.level = 0,
  });

  final String id;
  final int start;
  final int end;
  final int level;

  bool get isValid => id.trim().isNotEmpty && start >= 0 && end > start;

  factory NoteTextParagraphStyle.fromJson(Object? value) {
    if (value is! Map) {
      return const NoteTextParagraphStyle(id: '', start: 0, end: 0);
    }
    return NoteTextParagraphStyle(
      id: value['id']?.toString() ?? '',
      start: value['start'] is int ? value['start'] as int : 0,
      end: value['end'] is int ? value['end'] as int : 0,
      level: (value['level'] is int ? value['level'] as int : 0)
          .clamp(0, 8)
          .toInt(),
    );
  }

  NoteTextParagraphStyle clampToTextLength(int length) {
    final normalizedLength = length < 0 ? 0 : length;
    final clampedStart = start.clamp(0, normalizedLength).toInt();
    final clampedEnd = end.clamp(clampedStart, normalizedLength).toInt();
    return copyWith(start: clampedStart, end: clampedEnd);
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'start': start,
      'end': end,
      if (level != 0) 'level': level.clamp(0, 8).toInt(),
    };
  }

  NoteTextParagraphStyle copyWith({
    String? id,
    int? start,
    int? end,
    int? level,
  }) {
    return NoteTextParagraphStyle(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      level: (level ?? this.level).clamp(0, 8).toInt(),
    );
  }
}
```

Add helper:

```dart
List<NoteTextParagraphStyle> _paragraphStylesFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map(NoteTextParagraphStyle.fromJson)
      .where((style) => style.isValid)
      .toList(growable: false);
}
```

Add `this.paragraphStyles = const []` to `NoteBlock`, a `final List<NoteTextParagraphStyle> paragraphStyles;`, parse it from `json['paragraphStyles']`, write it to JSON when non-empty, and add it to `copyWith`.

- [ ] **Step 4: Run tests**

Run the same `flutter test test/note_document_test.dart`.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/notes/models/note_document.dart test/note_document_test.dart
git commit -m "feat: add text paragraph metadata"
```

---

### Task 2: Text Edit, Range Tag, and Paragraph Helpers

**Files:**
- Delete: `lib/src/notes/ui/text_chunk/text_chunk_ranges.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_text_edits.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_paragraphs.dart`
- Test: `test/text_chunk_paragraphs_test.dart`

**Interfaces:**
- Consumes: `NoteTextRangeTag`, `NoteTextParagraphStyle`
- Produces:
  - `TextChunkTextEdit`
  - `TextChunkEditResult`
  - `textChunkEditFromTextChange(String oldText, String newText)`
  - `adjustTextChunkRangeTagsForEdit(...)`
  - `textChunkParagraphRanges(String text)`
  - `textChunkParagraphRangeForOffset(String text, int offset)`
  - `adjustTextChunkParagraphStylesForEdit(...)`
  - `applyTextChunkParagraphLevelStep(...)`
  - `textChunkTargetRangeForSelection(...)`
  - `textChunkTagsForRange(...)`

- [ ] **Step 1: Replace old tests with failing paragraph tests**

Delete `test/text_chunk_layout_model_test.dart`. Create `test/text_chunk_paragraphs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_paragraphs.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_text_edits.dart';

void main() {
  test('single enter stays in paragraph and double enter starts a new one', () {
    expect(textChunkParagraphRanges('Alpha\nBeta\n\nGamma'), [
      const TextRange(start: 0, end: 10),
      const TextRange(start: 12, end: 17),
    ]);
  });

  test('paragraph level step changes metadata without changing text', () {
    const text = 'Alpha\nBeta\n\nGamma';
    final result = applyTextChunkParagraphLevelStep(
      text: text,
      paragraphStyles: const [],
      selection: const TextSelection(baseOffset: 1, extentOffset: 14),
      delta: 1,
    );

    expect(result.text, text);
    expect(result.selection, const TextSelection(baseOffset: 1, extentOffset: 14));
    expect(result.paragraphStyles, hasLength(2));
    expect(result.paragraphStyles.map((style) => style.level), [1, 1]);
  });

  test('text edits remap paragraph styles and range tags', () {
    const text = 'Alpha\nBeta\n\nGamma';
    const style = NoteTextParagraphStyle(id: 'p-2', start: 12, end: 17, level: 2);
    const rangeTag = NoteTextRangeTag(
      id: 'r-1',
      start: 12,
      end: 17,
      tag: NoteKnowledgeTag(type: NoteKnowledgeTagTypes.topic, label: 'Topic'),
    );

    final edit = textChunkEditFromTextChange(text, 'Intro\nAlpha\nBeta\n\nGamma');
    final styles = adjustTextChunkParagraphStylesForEdit(
      oldTextLength: text.length,
      paragraphStyles: const [style],
      edit: edit,
    );
    final tags = adjustTextChunkRangeTagsForEdit(
      oldTextLength: text.length,
      rangeTags: const [rangeTag],
      edit: edit,
    );

    expect(styles.single.start, 18);
    expect(styles.single.end, 23);
    expect(tags.single.start, 18);
    expect(tags.single.end, 23);
  });
}
```

- [ ] **Step 2: Run the failing tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/text_chunk_paragraphs_test.dart'
```

Expected: FAIL because the new helper files do not exist.

- [ ] **Step 3: Implement text edit helpers**

Create `lib/src/notes/ui/text_chunk/text_chunk_text_edits.dart` with `TextChunkTextEdit`, `textChunkEditFromTextChange`, `adjustTextChunkRangeTagsForEdit`, and `TextChunkEditResult`. Move the existing range-tag remapping logic here, but do not include paragraph indent text mutation.

- [ ] **Step 4: Implement paragraph helpers**

Create `lib/src/notes/ui/text_chunk/text_chunk_paragraphs.dart` with paragraph range detection, paragraph style remapping, and metadata-only level step.

The level step must return:

```dart
class TextChunkParagraphLevelResult {
  const TextChunkParagraphLevelResult({
    required this.text,
    required this.paragraphStyles,
    required this.selection,
  });

  final String text;
  final List<NoteTextParagraphStyle> paragraphStyles;
  final TextSelection selection;
}
```

- [ ] **Step 5: Run paragraph tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/text_chunk_paragraphs_test.dart'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/ui/text_chunk/text_chunk_text_edits.dart lib/src/notes/ui/text_chunk/text_chunk_paragraphs.dart test/text_chunk_paragraphs_test.dart test/text_chunk_layout_model_test.dart
git commit -m "feat: add text chunk paragraph helpers"
```

---

### Task 3: Native Text Span Controller With Tag Highlight and Underline Spacing

**Files:**
- Delete: `lib/src/notes/ui/text_chunk/text_chunk_controller.dart`
- Delete: `lib/src/notes/ui/text_chunk/text_chunk_underlines.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_span_controller.dart`
- Test: `test/text_chunk_span_controller_test.dart`

**Interfaces:**
- Consumes: `NoteTextRangeTag`
- Produces:
  - `class TextChunkSpanController extends TextEditingController`
  - `configureTextChunkSpans({required List<NoteTextRangeTag> rangeTags})`
  - constants `textChunkUnderlineLaneHeight`, `textChunkUnderlineTopGap`

- [ ] **Step 1: Write failing span tests**

Create `test/text_chunk_span_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_span_controller.dart';

void main() {
  testWidgets('controller builds spans without changing text', (tester) async {
    final controller = TextChunkSpanController(text: 'Alpha Beta Gamma')
      ..configureTextChunkSpans(
        rangeTags: const [
          NoteTextRangeTag(
            id: 'r-1',
            start: 6,
            end: 10,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Topic',
              colorValue: 0xFF2563EB,
            ),
          ),
        ],
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 16),
              withComposing: false,
            );
            return Text.rich(span);
          },
        ),
      ),
    );

    expect(controller.text, 'Alpha Beta Gamma');
    expect(find.textContaining('Alpha Beta Gamma'), findsOneWidget);
  });

  testWidgets('secondary tag lanes increase only tagged span height', (tester) async {
    final controller = TextChunkSpanController(text: 'Alpha\nBeta\nGamma')
      ..configureTextChunkSpans(
        rangeTags: const [
          NoteTextRangeTag(
            id: 'r-1',
            start: 6,
            end: 10,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Topic',
              colorValue: 0xFF2563EB,
            ),
            tags: [
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.topic,
                label: 'Topic',
                colorValue: 0xFF2563EB,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.state,
                label: 'State',
                colorValue: 0xFFDC2626,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.custom,
                label: 'Custom',
                colorValue: 0xFF059669,
              ),
            ],
          ),
        ],
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            final span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 16),
              withComposing: false,
            );
            return Text.rich(span);
          },
        ),
      ),
    );

    final root = tester.widget<Text>(find.byType(Text));
    final spans = (root.textSpan! as TextSpan).children!.whereType<TextSpan>();
    final betaSpan = spans.firstWhere((span) => span.text == 'Beta');
    expect(betaSpan.style?.height, greaterThan(1));
    expect(controller.text, 'Alpha\nBeta\nGamma');
  });
}
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/text_chunk_span_controller_test.dart'
```

Expected: FAIL because `TextChunkSpanController` does not exist.

- [ ] **Step 3: Implement span controller**

Create `lib/src/notes/ui/text_chunk/text_chunk_span_controller.dart`. It must:

- build spans from real text substrings;
- apply primary background color;
- apply increased `TextStyle.height` only to substrings covered by range tags with secondary lanes;
- preserve composing behavior by passing `withComposing` through standard text handling where possible;
- not create `WidgetSpan`.

- [ ] **Step 4: Run span tests**

Run the same `flutter test test/text_chunk_span_controller_test.dart`.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/notes/ui/text_chunk/text_chunk_span_controller.dart test/text_chunk_span_controller_test.dart lib/src/notes/ui/text_chunk/text_chunk_controller.dart lib/src/notes/ui/text_chunk/text_chunk_underlines.dart
git commit -m "feat: add native text chunk span controller"
```

---

### Task 4: Minimal Native Editor Runtime

**Files:**
- Delete: `lib/src/notes/ui/text_chunk/text_chunk_editor.dart`
- Create: `lib/src/notes/ui/text_chunk/native_text_chunk_editor.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes:
  - `TextChunkSpanController`
  - `textChunkEditFromTextChange`
  - `adjustTextChunkRangeTagsForEdit`
  - paragraph helpers
- Produces:
  - `NativeTextChunkEditor`
  - key `ValueKey('note-text-native-editor')` on the editable surface

- [ ] **Step 1: Rewrite widget tests for runtime constraints**

Update `test/note_text_chunk_editor_screen_test.dart` so it asserts:

```dart
expect(find.byKey(const ValueKey('note-text-native-editor')), findsOneWidget);
expect(find.byKey(const ValueKey('note-text-chunk-field')), findsNothing);
expect(find.byKey(const ValueKey('note-text-scroll')), findsNothing);
expect(find.byKey(const ValueKey('note-text-secondary-underline-overlay')), findsNothing);
expect(find.byKey(const ValueKey('note-text-inline-selection-spacer')), findsNothing);
```

Keep tests for:

- text equality;
- rail hidden while untagged typing;
- rail visible for non-collapsed selection;
- rail visible for collapsed cursor inside tag.

- [ ] **Step 2: Run failing screen tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_text_chunk_editor_screen_test.dart'
```

Expected: FAIL because old wrapper keys still exist.

- [ ] **Step 3: Implement minimal editor widget**

Create `native_text_chunk_editor.dart` with one `EditableText`:

- key: `ValueKey('note-text-native-editor')`
- controller: `TextChunkSpanController`
- no surrounding `GestureDetector`
- no surrounding `SingleChildScrollView`
- no `Stack`
- no underline `CustomPaint`
- `selectionControls: materialTextSelectionHandleControls`
- native context menu builder
- `maxLines: null`
- selection callback passed through.

- [ ] **Step 4: Update screen integration**

Modify `note_text_chunk_editor_screen.dart`:

- replace `TextChunkEditingController` with `TextChunkSpanController`;
- remove imports for deleted runtime files;
- update text edit handling to use `textChunkEditFromTextChange`;
- update paragraph step to use `applyTextChunkParagraphLevelStep`;
- update `_block.copyWith(paragraphStyles: result.paragraphStyles)`;
- log `[TextChunkParagraph]` with `oldLen` and `newLen`, both equal.

- [ ] **Step 5: Run screen tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_text_chunk_editor_screen_test.dart'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/ui/note_text_chunk_editor_screen.dart lib/src/notes/ui/text_chunk/native_text_chunk_editor.dart lib/src/notes/ui/text_chunk/text_chunk_editor.dart test/note_text_chunk_editor_screen_test.dart
git commit -m "feat: rebuild text chunk native editor"
```

---

### Task 5: Rail State and Actions

**Files:**
- Delete: `lib/src/notes/ui/text_chunk/text_chunk_rail_state.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_rail.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Test: `test/native_selection_rail_bridge_test.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes:
  - `NativeSelectionRailState`
  - `TextSelection`
  - `NoteTextRangeTag`
- Produces:
  - `textChunkTargetRangeForSelection(...)`
  - `textChunkNativeRailState(...)`
  - `textChunkTagsForRange(...)`

- [ ] **Step 1: Write/adjust rail tests**

Ensure tests cover:

- selected text sends `visible: true`;
- collapsed cursor inside tagged range sends `visible: true`;
- untagged typing never sends `visible: true`;
- actions include `outdent`, `indent`, `tagSelection`, style toggles, tag row toggle;
- rail payload has no text layout fields.

- [ ] **Step 2: Run rail tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/native_selection_rail_bridge_test.dart test/note_text_chunk_editor_screen_test.dart'
```

Expected: FAIL until imports and state helper are replaced.

- [ ] **Step 3: Implement rail helper**

Move selection/range/tag rail helper logic into `text_chunk_rail.dart`. It must not reference layout placeholders, line metrics, or editor render boxes.

- [ ] **Step 4: Run rail tests**

Run the same rail test command.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/notes/ui/text_chunk/text_chunk_rail.dart lib/src/notes/ui/text_chunk/text_chunk_rail_state.dart lib/src/notes/ui/note_text_chunk_editor_screen.dart test/native_selection_rail_bridge_test.dart test/note_text_chunk_editor_screen_test.dart
git commit -m "feat: keep text chunk rail outside editor"
```

---

### Task 6: Remove Old Text Chunk Runtime and Update Route Tests

**Files:**
- Delete old files under `lib/src/notes/ui/text_chunk/` not recreated in this plan
- Modify: `test/note_editor_route_test.dart`
- Modify: imports in affected tests

**Interfaces:**
- Consumes: new editor keys and helper names.
- Produces: no references to deleted runtime symbols.

- [ ] **Step 1: Search for old symbols**

Run:

```bash
rg -n "TextChunkEditingController|NativeTextChunkEditor|TextChunkSecondaryUnderlineOverlay|text_chunk_controller|text_chunk_underlines|text_chunk_ranges|text_chunk_rail_state|applyTextChunkParagraphMarginStep|TextChunkMargin|note-text-chunk-field|note-text-scroll|rail-line-" lib test
```

Expected before cleanup: old references exist.

- [ ] **Step 2: Remove old references**

Update tests and imports to use:

- `TextChunkSpanController`
- `native_text_chunk_editor.dart`
- `text_chunk_text_edits.dart`
- `text_chunk_paragraphs.dart`
- `text_chunk_rail.dart`

Preserve negative test checks for `rail-line-` only where asserting logs do not contain it.

- [ ] **Step 3: Run route and text chunk tests**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_editor_route_test.dart test/note_text_chunk_editor_screen_test.dart test/text_chunk_paragraphs_test.dart test/text_chunk_span_controller_test.dart'
```

Expected: PASS.

- [ ] **Step 4: Re-run old-symbol search**

Run the same `rg` command.

Expected: no production old-symbol hits; only allowed negative assertions for `rail-line-`.

- [ ] **Step 5: Commit**

```bash
git add lib/src/notes/ui/text_chunk test/note_editor_route_test.dart test/note_text_chunk_editor_screen_test.dart test/text_chunk_paragraphs_test.dart test/text_chunk_span_controller_test.dart
git commit -m "chore: remove old text chunk runtime"
```

---

### Task 7: Verification, Manual Checklist, and Branch Push

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-22-textchunk-native-editor-paragraphs.md`
- Optional modify: `docs/superpowers/plans/2026-06-22-textchunk-native-editor-paragraphs.md` status checkboxes during execution

**Interfaces:**
- Consumes all previous tasks.
- Produces verified branch and updated checklist statuses.

- [ ] **Step 1: Run targeted tests**

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_document_test.dart test/text_chunk_paragraphs_test.dart test/text_chunk_span_controller_test.dart test/note_text_chunk_editor_screen_test.dart test/native_selection_rail_bridge_test.dart test/note_editor_route_test.dart'
```

Expected: all pass.

- [ ] **Step 2: Run analyze**

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter analyze'
```

Expected: `No issues found!`

- [ ] **Step 3: Run full tests**

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test'
```

Expected: all tests pass, with existing ObjectBox host skips only.

- [ ] **Step 4: Update checklist**

Mark each `TNEP-*` item as `DONE`, `PARTIAL`, or `BLOCKED` based on evidence. If native-safe visible per-paragraph indent is not possible, mark the visual-indent portion in `TNEP-05` as `BLOCKED` and do not claim it is complete.

- [ ] **Step 5: Commit verification docs**

```bash
git add docs/superpowers/checklists/2026-06-22-textchunk-native-editor-paragraphs.md docs/superpowers/plans/2026-06-22-textchunk-native-editor-paragraphs.md
git commit -m "docs: verify native text chunk rewrite"
```

- [ ] **Step 6: Push branch**

```bash
git push origin fix/textchunk-rail-dynamic-spacing
```

- [ ] **Step 7: Run GitHub Android build**

```bash
gh workflow run android-native-build.yml --repo elizerpist/djinn --ref fix/textchunk-rail-dynamic-spacing
gh run list --repo elizerpist/djinn --workflow android-native-build.yml --branch fix/textchunk-rail-dynamic-spacing --limit 1
```

Watch the returned run:

```bash
gh run watch <run-id> --repo elizerpist/djinn --exit-status
```

Expected: success and latest debug APK published.

- [ ] **Step 8: Manual Android verification**

Install the debug APK and verify on device:

- type a multiline text chunk;
- long-press text and expand both selection handles smoothly;
- select across newline and across double-newline paragraph boundary;
- confirm native copy/cut toolbar appears;
- confirm rail appears above keyboard for selected text;
- confirm untagged typing hides rail;
- tag a selection and confirm primary background appears;
- add multiple tags and confirm underline lanes reserve vertical room on affected lines;
- step in/out and confirm text length does not change.

Record manual result in the checklist before claiming completion.

