# Mixed Text Chunks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new mixed text chunk that stores and edits paragraphs, lists, and tables inside one logical chunk, while keeping legacy text/list/table chunks compatible.

**Architecture:** Add an ordered mixed-section model to `NoteBlock`, persist optional structured content for PDF/manual chunks, and route new text chunks into a mixed editor. Fix PDF selected-region text joining before parsing into mixed sections. Keep legacy editors and storage paths intact.

**Tech Stack:** Flutter/Dart, pdfrx structured text, ObjectBox local storage, existing note/editor widgets, Ubuntu proot for Flutter test/analyze.

## Global Constraints

- Required references: `/storage/emulated/0/Pictures/Screenshots/Screenshot_20260625-124832.png` and `/storage/emulated/0/Pictures/Screenshots/Screenshot_20260625-124857.png`.
- Do not delete `NoteBlockType.listItem` or `NoteBlockType.table`.
- Do not force-migrate existing documents.
- Flowcharts remain separate from mixed chunks.
- New content should be mixed text by default.
- The mixed editor rail belongs above the keyboard, not inline in cards.
- Local Flutter test/analyze must run inside Ubuntu proot.
- Do not run local Android APK builds in Termux; APK builds run on GitHub Actions.

---

## File Structure

- Modify `lib/src/knowledge/ui/manual_pdf_region_text.dart`: layout-aware joining for selected PDF text fragments.
- Modify `test/manual_pdf_region_text_test.dart`: regression tests for word fragments, bullets, numbered lines, and paragraph gaps.
- Modify `lib/src/notes/models/note_document.dart`: `NoteBlockType.mixed`, `NoteMixedSectionType`, `NoteMixedSection`, JSON, plain text, indexing, known tags.
- Modify `test/note_document_test.dart`: mixed model round-trip, legacy compatibility, plain text/index metadata.
- Create `lib/src/notes/models/mixed_chunk_parser.dart`: conservative plain-text-to-mixed-section parser and legacy conversion helpers.
- Create `test/mixed_chunk_parser_test.dart`: parser tests for the first PDF section shape.
- Modify `lib/src/knowledge/models/local_extraction.dart`: add `structuredContentJson` to `LocalChunk`; add `LocalChunkKind.mixedText` if storage needs explicit structured text.
- Modify `lib/src/knowledge/models/extracted_knowledge_item.dart`: add `structuredContentJson`, copyWith support, mixed type labels.
- Modify `lib/src/local_store/entities.dart`, `lib/objectbox-model.json`, and `lib/objectbox.g.dart`: add ObjectBox persisted `structuredContentJson` property to `DocumentChunkEntity`.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`, `lib/src/knowledge/data/objectbox_knowledge_repository.dart`, and `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`: save/list/update structured content.
- Modify repository tests: `test/knowledge_document_repository_test.dart`, `test/objectbox_knowledge_repository_test.dart`, and related extracted chunk tests.
- Create `lib/src/notes/ui/note_mixed_text_chunk_editor_screen.dart`: mixed editor route/screen.
- Create `test/note_mixed_text_chunk_editor_screen_test.dart`: paragraph/list/table/rail widget tests.
- Modify `lib/src/notes/ui/note_editor_route.dart` and `lib/src/notes/ui/note_chunk_fab.dart`: new text creation defaults to mixed; legacy add options are not primary.
- Modify `lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart` and `lib/src/knowledge/ui/pdf_chunk_editor_route.dart`: load/save structured mixed chunks and convert legacy chunks safely.
- Modify `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`: manual PDF text chunks save mixed structure and readable flattened text.
- Modify `lib/src/shared/chunks/shared_chunk.dart`, `lib/src/shared/chunks/shared_chunk_card.dart`, `lib/src/notes/ui/note_shared_chunk_adapter.dart`, and `lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart`: display mixed as text.
- Modify `lib/src/notes/pdf/note_pdf_document_builder.dart`: export mixed sections in order.
- Modify retrieval/indexing tests if exhaustive switches require updates.

---

### Task 1: Layout-Aware PDF Region Text Joining

**Files:**
- Modify: `lib/src/knowledge/ui/manual_pdf_region_text.dart`
- Test: `test/manual_pdf_region_text_test.dart`

**Interfaces:**
- Consumes: `PdfTextRegionFragment(text, bounds)` and `PdfRect selectedRect`.
- Produces: `String textFromFragmentsInPdfRect({required List<PdfTextRegionFragment> fragments, required PdfRect selectedRect})` that returns readable selected text.

- [ ] **Step 1: Add failing word-fragment and bullet tests**

Append tests to `test/manual_pdf_region_text_test.dart`:

```dart
test('joins word fragments on the same visual line with spaces', () {
  final text = textFromFragmentsInPdfRect(
    fragments: const [
      PdfTextRegionFragment(text: 'Az', bounds: PdfRect(40, 700, 58, 684)),
      PdfTextRegionFragment(text: 'eljárásrend', bounds: PdfRect(62, 700, 145, 684)),
      PdfTextRegionFragment(text: 'célja:', bounds: PdfRect(150, 700, 194, 684)),
      PdfTextRegionFragment(text: '•', bounds: PdfRect(44, 672, 50, 656)),
      PdfTextRegionFragment(text: 'az', bounds: PdfRect(64, 672, 80, 656)),
      PdfTextRegionFragment(text: 'ellátás', bounds: PdfRect(84, 672, 135, 656)),
      PdfTextRegionFragment(text: 'során', bounds: PdfRect(139, 672, 178, 656)),
    ],
    selectedRect: const PdfRect(30, 720, 220, 640),
  );

  expect(text, 'Az eljárásrend célja:\n• az ellátás során');
});

test('adds a blank line for paragraph gaps and keeps numbered markers', () {
  final text = textFromFragmentsInPdfRect(
    fragments: const [
      PdfTextRegionFragment(text: 'I.', bounds: PdfRect(40, 700, 52, 684)),
      PdfTextRegionFragment(text: 'Célok:', bounds: PdfRect(80, 700, 128, 684)),
      PdfTextRegionFragment(text: 'Jelen', bounds: PdfRect(40, 650, 78, 634)),
      PdfTextRegionFragment(text: 'eljárásrend', bounds: PdfRect(82, 650, 165, 634)),
    ],
    selectedRect: const PdfRect(30, 720, 220, 620),
  );

  expect(text, 'I. Célok:\n\nJelen eljárásrend');
});
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/manual_pdf_region_text_test.dart'
```

Expected: FAIL because current implementation joins every fragment with `\n`.

- [ ] **Step 3: Implement line grouping**

In `manual_pdf_region_text.dart`, replace the simple map/join with:

```dart
String textFromFragmentsInPdfRect({
  required List<PdfTextRegionFragment> fragments,
  required PdfRect selectedRect,
}) {
  final selected = fragments
      .where((fragment) => fragment.bounds.overlaps(selectedRect))
      .where((fragment) => fragment.text.trim().isNotEmpty)
      .toList(growable: false);
  if (selected.isEmpty) {
    return '';
  }
  selected.sort(_comparePdfFragmentsReadingOrder);
  final lines = _groupFragmentsIntoLines(selected);
  final buffer = StringBuffer();
  double? previousCenterY;
  double? previousHeight;
  for (final line in lines) {
    if (buffer.isNotEmpty) {
      final gap = previousCenterY == null
          ? 0
          : (previousCenterY - line.centerY).abs();
      final threshold = (previousHeight ?? line.height) * 1.75;
      buffer.write(gap > threshold ? '\n\n' : '\n');
    }
    buffer.write(_joinLineFragments(line.fragments));
    previousCenterY = line.centerY;
    previousHeight = line.height;
  }
  return buffer.toString().trim();
}
```

Add private helpers in the same file:

```dart
int _comparePdfFragmentsReadingOrder(
  PdfTextRegionFragment a,
  PdfTextRegionFragment b,
) {
  final vertical = _centerY(b.bounds).compareTo(_centerY(a.bounds));
  if ((_centerY(a.bounds) - _centerY(b.bounds)).abs() > _lineTolerance(a, b)) {
    return vertical;
  }
  return a.bounds.left.compareTo(b.bounds.left);
}

List<_PdfTextLine> _groupFragmentsIntoLines(List<PdfTextRegionFragment> items) {
  final lines = <_PdfTextLine>[];
  for (final fragment in items) {
    final center = _centerY(fragment.bounds);
    final existingIndex = lines.indexWhere(
      (line) => (line.centerY - center).abs() <= line.height * 0.55,
    );
    if (existingIndex < 0) {
      lines.add(_PdfTextLine([fragment]));
    } else {
      lines[existingIndex] = lines[existingIndex].append(fragment);
    }
  }
  for (var i = 0; i < lines.length; i += 1) {
    lines[i] = lines[i].sorted();
  }
  return lines;
}

String _joinLineFragments(List<PdfTextRegionFragment> fragments) {
  final buffer = StringBuffer();
  for (final fragment in fragments) {
    final text = fragment.text.trim();
    if (text.isEmpty) {
      continue;
    }
    if (buffer.isEmpty || _noSpaceBefore(text)) {
      buffer.write(text);
    } else {
      buffer.write(' $text');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+([,.;:])'), r'$1');
}

bool _noSpaceBefore(String text) => RegExp(r'^[,.;:!?)]').hasMatch(text);
double _centerY(PdfRect rect) => (rect.top + rect.bottom) / 2;
double _height(PdfRect rect) => (rect.top - rect.bottom).abs();
double _lineTolerance(PdfTextRegionFragment a, PdfTextRegionFragment b) =>
    (_height(a.bounds) + _height(b.bounds)) * 0.35;

class _PdfTextLine {
  const _PdfTextLine(this.fragments);
  final List<PdfTextRegionFragment> fragments;
  double get centerY =>
      fragments.map((fragment) => _centerY(fragment.bounds)).reduce((a, b) => a + b) /
      fragments.length;
  double get height =>
      fragments.map((fragment) => _height(fragment.bounds)).reduce((a, b) => a + b) /
      fragments.length;
  _PdfTextLine append(PdfTextRegionFragment fragment) =>
      _PdfTextLine([...fragments, fragment]);
  _PdfTextLine sorted() {
    final next = [...fragments]..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    return _PdfTextLine(next);
  }
}
```

- [ ] **Step 4: Run Task 1 tests**

Run the same command from Step 2.

Expected: all `manual_pdf_region_text_test.dart` tests pass.

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/src/knowledge/ui/manual_pdf_region_text.dart test/manual_pdf_region_text_test.dart
git commit -m "fix: join pdf text fragments into readable lines"
```

---

### Task 2: Mixed Chunk Model And Parser

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Create: `lib/src/notes/models/mixed_chunk_parser.dart`
- Test: `test/note_document_test.dart`
- Test: `test/mixed_chunk_parser_test.dart`

**Interfaces:**
- Produces: `NoteBlockType.mixed`
- Produces: `NoteMixedSectionType`
- Produces: `NoteMixedSection`
- Produces: `NoteBlock mixedBlockFromPlainText({required String id, String? title, required String text, List<NoteKnowledgeTag> tags = const []})`
- Produces: `NoteBlock mixedBlockFromLegacy(NoteBlock block)`

- [ ] **Step 1: Write failing model tests**

Append to `test/note_document_test.dart`:

```dart
test('serializes mixed chunk sections and derives plain text in order', () {
  const block = NoteBlock(
    id: 'mixed-1',
    type: NoteBlockType.mixed,
    title: 'Célok',
    mixedSections: [
      NoteMixedSection(
        id: 'p1',
        type: NoteMixedSectionType.paragraph,
        text: 'Az eljárásrend célja:',
      ),
      NoteMixedSection(
        id: 'l1',
        type: NoteMixedSectionType.list,
        listItems: [
          NoteListItem(id: 'i1', text: 'az ellátás során'),
          NoteListItem(id: 'i2', text: 'a felszerelés meghatározása', level: 1),
        ],
        listLayoutMode: NoteListLayoutMode.hierarchy,
      ),
      NoteMixedSection(
        id: 't1',
        type: NoteMixedSectionType.table,
        rows: [
          ['Eszköz', 'Mennyiség'],
          ['AED', '1'],
        ],
      ),
    ],
  );

  final parsed = NoteBlock.fromJson(block.toJson());

  expect(parsed.type, NoteBlockType.mixed);
  expect(parsed.mixedSections, hasLength(3));
  expect(parsed.plainText, contains('Az eljárásrend célja:'));
  expect(parsed.plainText, contains('az ellátás során'));
  expect(parsed.plainText, contains('AED | 1'));
  expect(parsed.displayTextForIndexing, parsed.plainText);
});

test('legacy list and table blocks still parse after mixed type is added', () {
  final list = NoteBlock.fromJson({
    'id': 'l1',
    'type': 'list_item',
    'listItems': [
      {'id': 'i1', 'text': 'Régi lista'},
    ],
  });
  final table = NoteBlock.fromJson({
    'id': 't1',
    'type': 'table',
    'rows': [
      ['A', 'B'],
    ],
  });

  expect(list.type, NoteBlockType.listItem);
  expect(list.plainText, contains('Régi lista'));
  expect(table.type, NoteBlockType.table);
  expect(table.plainText, contains('A | B'));
});
```

- [ ] **Step 2: Write failing parser tests**

Create `test/mixed_chunk_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/mixed_chunk_parser.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('parses paragraph plus bullet list into mixed sections', () {
    final block = mixedBlockFromPlainText(
      id: 'manual-1',
      title: 'Célok',
      text: 'I. Célok:\nAz eljárásrend célja:\n• az ellátás során\n• a felszerelés meghatározása\n\nJelen eljárásrend a korábban kiadott...',
    );

    expect(block.type, NoteBlockType.mixed);
    expect(block.mixedSections.map((section) => section.type), [
      NoteMixedSectionType.paragraph,
      NoteMixedSectionType.list,
      NoteMixedSectionType.paragraph,
    ]);
    expect(block.mixedSections[1].listItems.map((item) => item.text), [
      'az ellátás során',
      'a felszerelés meghatározása',
    ]);
  });

  test('converts legacy table block to one mixed table section', () {
    const legacy = NoteBlock(
      id: 'table-1',
      type: NoteBlockType.table,
      title: 'Eszközök',
      rows: [
        ['Eszköz', 'Mennyiség'],
        ['AED', '1'],
      ],
    );

    final mixed = mixedBlockFromLegacy(legacy);

    expect(mixed.type, NoteBlockType.mixed);
    expect(mixed.mixedSections.single.type, NoteMixedSectionType.table);
    expect(mixed.mixedSections.single.rows.last, ['AED', '1']);
  });
}
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_document_test.dart test/mixed_chunk_parser_test.dart'
```

Expected: FAIL because mixed model/parser types do not exist.

- [ ] **Step 4: Implement mixed model**

In `note_document.dart`:

- Add `mixed('mixed')` to `NoteBlockType`.
- Add `NoteMixedSectionType` and `NoteMixedSection` near `NoteListItem`.
- Add `mixedSections = const []` to `NoteBlock`.
- Parse `mixedSections` in `fromJson`.
- Emit `mixedSections` in `toJson`.
- Include mixed sections in `plainText`, `displayTextForIndexing`, `knownTags`, `hasContent`, and `copyWith`.

Use these exact signatures:

```dart
enum NoteMixedSectionType {
  paragraph('paragraph'),
  list('list'),
  table('table');

  const NoteMixedSectionType(this.wireName);
  final String wireName;

  static NoteMixedSectionType fromWireName(String? value) {
    return switch (value) {
      'list' => NoteMixedSectionType.list,
      'table' => NoteMixedSectionType.table,
      _ => NoteMixedSectionType.paragraph,
    };
  }
}

class NoteMixedSection {
  const NoteMixedSection({
    required this.id,
    required this.type,
    this.title,
    this.text = '',
    this.rangeTags = const [],
    this.paragraphStyles = const [],
    this.listItems = const [],
    this.listLayoutMode = NoteListLayoutMode.checkbox,
    this.rows = const [],
    this.tableColumnWidths = const [],
    this.tableRowHeights = const [],
    this.scopedTags = const [],
  });
  // fields, fromJson, toJson, copyWith, plainText, knownTags.
}
```

- [ ] **Step 5: Implement parser**

Create `mixed_chunk_parser.dart` with:

```dart
import 'note_document.dart';

NoteBlock mixedBlockFromPlainText({
  required String id,
  String? title,
  required String text,
  List<NoteKnowledgeTag> tags = const [],
}) {
  final sections = parseMixedSectionsFromPlainText(text);
  return NoteBlock(
    id: id,
    type: NoteBlockType.mixed,
    title: title,
    tags: tags,
    mixedSections: sections.isEmpty
        ? [NoteMixedSection(id: '$id-p1', type: NoteMixedSectionType.paragraph, text: text.trim())]
        : sections,
  );
}

NoteBlock mixedBlockFromLegacy(NoteBlock block) {
  if (block.type == NoteBlockType.mixed) {
    return block;
  }
  final section = switch (block.type) {
    NoteBlockType.listItem => NoteMixedSection(
      id: '${block.id}-list',
      type: NoteMixedSectionType.list,
      title: block.title,
      listItems: block.listItems,
      listLayoutMode: block.listLayoutMode,
    ),
    NoteBlockType.table => NoteMixedSection(
      id: '${block.id}-table',
      type: NoteMixedSectionType.table,
      title: block.title,
      rows: block.rows,
      tableColumnWidths: block.tableColumnWidths,
      tableRowHeights: block.tableRowHeights,
      scopedTags: block.scopedTags,
    ),
    _ => NoteMixedSection(
      id: '${block.id}-p',
      type: NoteMixedSectionType.paragraph,
      title: block.title,
      text: block.text,
      rangeTags: block.rangeTags,
      paragraphStyles: block.paragraphStyles,
    ),
  };
  return block.copyWith(type: NoteBlockType.mixed, mixedSections: [section]);
}
```

Implement `parseMixedSectionsFromPlainText(String text)` conservatively: group bullet lines into list sections; group non-bullet paragraphs into paragraph sections; preserve all content.

- [ ] **Step 6: Update exhaustive switches**

Update every switch on `NoteBlockType` touched by analyzer for `mixed`. Map mixed to text display unless the switch needs to walk sections.

- [ ] **Step 7: Run Task 2 tests**

Run the Step 3 command.

Expected: PASS.

- [ ] **Step 8: Commit Task 2**

```bash
git add lib/src/notes/models/note_document.dart lib/src/notes/models/mixed_chunk_parser.dart test/note_document_test.dart test/mixed_chunk_parser_test.dart
git commit -m "feat: add mixed chunk model"
```

---

### Task 3: Persist Structured Mixed Content For PDF Chunks

**Files:**
- Modify: `lib/src/knowledge/models/local_extraction.dart`
- Modify: `lib/src/knowledge/models/extracted_knowledge_item.dart`
- Modify: `lib/src/local_store/entities.dart`
- Modify: `lib/objectbox-model.json`
- Modify: `lib/objectbox.g.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Test: `test/knowledge_document_repository_test.dart`
- Test: `test/objectbox_knowledge_repository_test.dart`

**Interfaces:**
- Produces: `LocalChunk.structuredContentJson`
- Produces: `ExtractedKnowledgeItem.structuredContentJson`
- Produces: `DocumentChunkEntity.structuredContentJson`
- Consumes: `NoteBlock.toJson()` for structured mixed chunk payloads.

- [ ] **Step 1: Write failing repository tests**

Add to in-memory repository tests:

```dart
test('manual local chunks preserve structured mixed content json', () async {
  final repository = KnowledgeDocumentRepository();
  final document = await repository.addDocument(
    filename: 'mixed.pdf',
    localPath: '/memory/mixed.pdf',
    sizeBytes: 1,
    importedAt: DateTime.utc(2026, 6, 25),
    sha256: 'mixed-hash',
  );

  await repository.saveLocalChunks(document.id, [
    const LocalChunk(
      id: 'mixed-1',
      documentId: 'ignored',
      text: 'Az eljárásrend célja:\naz ellátás során',
      pageNumber: 1,
      kind: LocalChunkKind.text,
      pipeline: LocalExtractionPipeline.manual,
      structuredContentJson: '{"type":"mixed","mixedSections":[]}',
    ),
  ], replaceExisting: false);

  final items = await repository.listExtractedKnowledgeItems(document.id);
  expect(items.single.structuredContentJson, contains('"type":"mixed"'));
});
```

Add matching ObjectBox test using `ObjectBoxKnowledgeRepository.saveLocalChunks` and `listExtractedKnowledgeItems`.

- [ ] **Step 2: Run repository tests and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/knowledge_document_repository_test.dart test/objectbox_knowledge_repository_test.dart'
```

Expected: FAIL because structured content fields do not exist.

- [ ] **Step 3: Add model fields**

Add optional `structuredContentJson` to `LocalChunk`, `ExtractedKnowledgeItem`, and `ExtractedKnowledgeItem.copyWith`.

- [ ] **Step 4: Add ObjectBox field**

Add `String? structuredContentJson;` to `DocumentChunkEntity`. Update generated ObjectBox files consistently with a new property id/UID. Preserve existing properties and do not reuse an existing UID.

- [ ] **Step 5: Wire repositories**

Update all chunk entity creation and mapping:

- `LocalChunk` -> `DocumentChunkEntity.structuredContentJson`
- `DocumentChunkEntity` -> `ExtractedKnowledgeItem.structuredContentJson`
- update item edits to preserve existing `structuredContentJson` unless a new value is passed.

If update methods need a parameter, use:

```dart
String? structuredContentJson,
bool clearStructuredContent = false,
```

- [ ] **Step 6: Run Task 3 tests**

Run Step 2 command.

Expected: PASS.

- [ ] **Step 7: Commit Task 3**

```bash
git add lib/src/knowledge/models/local_extraction.dart lib/src/knowledge/models/extracted_knowledge_item.dart lib/src/local_store/entities.dart lib/objectbox-model.json lib/objectbox.g.dart lib/src/knowledge/data/knowledge_document_repository.dart lib/src/knowledge/data/objectbox_knowledge_repository.dart test/knowledge_document_repository_test.dart test/objectbox_knowledge_repository_test.dart
git commit -m "feat: persist mixed chunk structure"
```

---

### Task 4: Mixed PDF/Note Adapters And New Creation Defaults

**Files:**
- Modify: `lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart`
- Modify: `lib/src/knowledge/ui/pdf_chunk_editor_route.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Modify: `lib/src/notes/ui/note_chunk_fab.dart`
- Modify: `lib/src/shared/chunks/shared_chunk.dart`
- Modify: `lib/src/notes/ui/note_shared_chunk_adapter.dart`
- Modify: `lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart`
- Test: `test/shared_chunk_adapter_test.dart`
- Test: `test/extracted_knowledge_screen_test.dart`
- Test: `test/note_document_editor_screen_test.dart`

**Interfaces:**
- Consumes: `mixedBlockFromPlainText` and `mixedBlockFromLegacy`.
- Produces: `noteBlockFromPdfChunk` that loads `structuredContentJson` when present.
- Produces: `pdfChunkTextFromNoteBlock` that flattens mixed sections.
- Produces: new text creation uses `NoteBlockType.mixed`.

- [ ] **Step 1: Write failing adapter tests**

Add tests asserting:

```dart
test('pdf chunk adapter loads structured mixed content when present', () {
  const item = ExtractedKnowledgeItem(
    id: 'mixed-1',
    documentId: 'doc-1',
    sourceType: EvidenceSourceType.textChunk,
    text: 'Fallback',
    structuredContentJson: '{"id":"mixed-1","type":"mixed","mixedSections":[{"id":"p1","type":"paragraph","text":"Structured"}]}',
  );

  final block = noteBlockFromPdfChunk(item);

  expect(block.type, NoteBlockType.mixed);
  expect(block.plainText, 'Structured');
});
```

Add widget tests that `note-editor-add-text` creates a mixed block and old list/table add buttons are not primary. The expected UI keys should remain stable:

```dart
expect(find.byKey(const ValueKey('note-editor-add-text')), findsOneWidget);
expect(find.byKey(const ValueKey('note-editor-add-list')), findsNothing);
expect(find.byKey(const ValueKey('note-editor-add-table')), findsNothing);
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/shared_chunk_adapter_test.dart test/extracted_knowledge_screen_test.dart test/note_document_editor_screen_test.dart'
```

Expected: FAIL because mixed adapters/default creation do not exist.

- [ ] **Step 3: Implement PDF adapter support**

In `pdf_chunk_note_block_adapter.dart`:

- if `item.structuredContentJson` parses as a mixed `NoteBlock`, return it;
- otherwise convert legacy item text/list/table into current legacy block;
- make `pdfChunkTextFromNoteBlock` return `block.plainText` for `NoteBlockType.mixed`;
- make `localChunkKindFromNoteBlock` return text/mixed storage kind for `NoteBlockType.mixed`.

- [ ] **Step 4: Route mixed editor placeholder**

Update `PdfChunkEditorRoute` switch to route `NoteBlockType.mixed` to the mixed editor once Task 5 creates it. Until Task 5 lands, keep this task compiling by adding an import and a temporary route only if Task 5 is implemented in the same branch before running analyzer.

- [ ] **Step 5: Update creation defaults**

In `note_editor_route.dart`, change `_addBlock(NoteBlockType.paragraph)` path for text FAB to create `NoteBlockType.mixed`. In `note_chunk_fab.dart`, remove primary list/table mini FABs from the expanded menu. Keep callbacks optional or leave legacy callbacks for tests/routes that still call them directly.

- [ ] **Step 6: Update shared display mapping**

Map `NoteBlockType.mixed` to text visual kind and title `Szöveg chunk`.

- [ ] **Step 7: Run Task 4 tests**

Run Step 2 command after Task 5 mixed editor scaffold exists.

Expected: PASS.

- [ ] **Step 8: Commit Task 4**

```bash
git add lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart lib/src/knowledge/ui/pdf_chunk_editor_route.dart lib/src/notes/ui/note_editor_route.dart lib/src/notes/ui/note_chunk_fab.dart lib/src/shared/chunks/shared_chunk.dart lib/src/notes/ui/note_shared_chunk_adapter.dart lib/src/knowledge/ui/pdf_shared_chunk_adapter.dart test/shared_chunk_adapter_test.dart test/extracted_knowledge_screen_test.dart test/note_document_editor_screen_test.dart
git commit -m "feat: route new text chunks to mixed editor"
```

---

### Task 5: Mixed Text Editor With Paragraph, List, Table Sections, And Keyboard Rail

**Files:**
- Create: `lib/src/notes/ui/note_mixed_text_chunk_editor_screen.dart`
- Modify: `lib/src/knowledge/ui/pdf_chunk_editor_route.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Test: `test/note_mixed_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: `NoteBlock(type: NoteBlockType.mixed, mixedSections: ...)`
- Produces: `NoteMixedTextChunkEditorScreen({required NoteBlock block, required ValueChanged<NoteBlock> onChanged, ...})`
- Produces keys: `note-mixed-text-editor`, `note-mixed-add-paragraph`, `note-mixed-add-list`, `note-mixed-add-table`, `note-mixed-keyboard-rail`, `note-mixed-list-item-<id>`, `note-mixed-table-cell-<sectionId>-<row>-<column>`.

- [ ] **Step 1: Write failing mixed editor tests**

Create `test/note_mixed_text_chunk_editor_screen_test.dart` with tests for:

```dart
testWidgets('mixed editor renders paragraph list and table sections in order', (tester) async { ... });
testWidgets('mixed list section reorders and indents items', (tester) async { ... });
testWidgets('mixed table section edits cells and adds rows and columns', (tester) async { ... });
testWidgets('mixed selection rail appears above keyboard for selected list item', (tester) async { ... });
```

The first test should pump a block with three sections and assert visible text order. The rail test should use `MediaQuery(data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 240)))`.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_mixed_text_chunk_editor_screen_test.dart'
```

Expected: FAIL because the screen does not exist.

- [ ] **Step 3: Implement editor scaffold**

Create a `StatefulWidget` with:

- `NoteChunkEditorHeader`;
- block-level tag row;
- `ReorderableListView.builder` for section order;
- add section actions in header menu or app bar actions;
- bottom keyboard rail positioned like `NoteTextChunkEditorScreen`.

- [ ] **Step 4: Implement paragraph section**

Use `TextField` with full-width padding. On text change, update the matching `NoteMixedSection.text` and emit `block.copyWith(mixedSections: next, clearIndex: true)`.

- [ ] **Step 5: Implement list section**

Use card rows matching `NoteListChunkEditorScreen` behavior:

- drag handle for item reorder;
- marker or checkbox;
- `TextFormField` per item;
- indent/outdent actions through keyboard rail;
- add/delete through keyboard rail.

Do not show inline `NoteSelectionActionRail`.

- [ ] **Step 6: Implement table section**

Implement an in-editor table grid that supports:

- text edit per cell;
- add row/column;
- delete selected row/column where possible;
- row/column/cell tag target selection;
- basic row/column reorder controls;
- no inline rail.

Reuse current table helper logic where practical, but keep the mixed screen as the owner of section state.

- [ ] **Step 7: Implement keyboard rail target switching**

Represent selection as:

```dart
sealed class _MixedSelectionTarget {
  const _MixedSelectionTarget();
}
```

Use simple subclasses or an enum-backed class for text/list/table targets. The rail actions must change based on target type.

- [ ] **Step 8: Run mixed editor tests**

Run Step 2 command.

Expected: PASS.

- [ ] **Step 9: Commit Task 5**

```bash
git add lib/src/notes/ui/note_mixed_text_chunk_editor_screen.dart lib/src/knowledge/ui/pdf_chunk_editor_route.dart lib/src/notes/ui/note_editor_route.dart test/note_mixed_text_chunk_editor_screen_test.dart
git commit -m "feat: add mixed text chunk editor"
```

---

### Task 6: Manual PDF Text Save As Mixed Chunk

**Files:**
- Modify: `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`
- Test: `test/knowledge_base_screen_test.dart`

**Interfaces:**
- Consumes: `mixedBlockFromPlainText`.
- Produces: manual text `LocalChunk` with `structuredContentJson` and readable `text`.

- [ ] **Step 1: Write failing manual save test**

Extend manual chunk save test to assert:

```dart
expect(manualItems.single.structuredContentJson, contains('"type":"mixed"'));
expect(manualItems.single.text, isNot(contains('Az\neljárásrend\ncélja')));
```

Use a test fixture that enters or preloads readable first-section text.

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/knowledge_base_screen_test.dart --name "manual chunk editor saves a selected PDF chunk"'
```

Expected: FAIL because manual chunk save has no structured JSON.

- [ ] **Step 3: Implement mixed save**

In `_save()` when `_kind == LocalChunkKind.text`:

- build `final mixedBlock = mixedBlockFromPlainText(id: chunkId, title: _emptyToNull(_titleController.text), text: content);`
- use `mixedBlock.plainText` for `LocalChunk.text`;
- set `structuredContentJson: jsonEncode(mixedBlock.toJson())`;
- keep `kind: LocalChunkKind.text` or `LocalChunkKind.mixedText` depending on Task 3 storage decision.

- [ ] **Step 4: Run Task 6 test**

Run Step 2 command.

Expected: PASS.

- [ ] **Step 5: Commit Task 6**

```bash
git add lib/src/knowledge/ui/manual_chunk_editor_screen.dart test/knowledge_base_screen_test.dart
git commit -m "feat: save manual text chunks as mixed"
```

---

### Task 7: Export, Search, And Regression Coverage

**Files:**
- Modify: `lib/src/notes/pdf/note_pdf_document_builder.dart`
- Modify: note retriever/indexer files as required by analyzer switches
- Test: `test/note_pdf_export_service_test.dart`
- Test: `test/note_aware_local_retriever_test.dart`
- Test: `test/note_aware_local_retriever_atom_search_test.dart`
- Test: `test/note_chunk_builder_test.dart`

**Interfaces:**
- Consumes: `NoteBlockType.mixed`, `NoteMixedSection`.
- Produces: export/index plain text behavior for mixed chunks.

- [ ] **Step 1: Write failing export/index tests**

Add PDF builder/export test that mixed paragraph/list/table content is exportable. Add retrieval test that mixed table/list text can be found.

- [ ] **Step 2: Run focused tests and verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_pdf_export_service_test.dart test/note_aware_local_retriever_test.dart test/note_chunk_builder_test.dart'
```

Expected: FAIL until export/switches handle mixed.

- [ ] **Step 3: Implement export**

Update `notePdfBlockHasExportableContent`, `_blockSection`, labels, and list/table helpers to handle `NoteBlockType.mixed` by iterating sections and delegating to existing paragraph/list/table PDF builders.

- [ ] **Step 4: Implement search/index switch updates**

Update exhaustive switches and helpers to use `block.plainText` for mixed blocks. Do not duplicate parser logic.

- [ ] **Step 5: Run Task 7 tests**

Run Step 2 command.

Expected: PASS.

- [ ] **Step 6: Commit Task 7**

```bash
git add lib/src/notes/pdf/note_pdf_document_builder.dart lib/src test
git commit -m "feat: export and index mixed chunks"
```

---

### Task 8: Full Verification, Checklist Update, Push, And CI

**Files:**
- Modify: `docs/superpowers/specs/2026-06-25-mixed-text-chunk-design.md`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: honest requirement statuses and a pushed branch.

- [ ] **Step 1: Run targeted suite**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/manual_pdf_region_text_test.dart test/mixed_chunk_parser_test.dart test/note_document_test.dart test/note_mixed_text_chunk_editor_screen_test.dart test/knowledge_document_repository_test.dart test/objectbox_knowledge_repository_test.dart test/extracted_knowledge_screen_test.dart test/knowledge_base_screen_test.dart test/note_pdf_export_service_test.dart test/note_aware_local_retriever_test.dart test/note_chunk_builder_test.dart'
```

Expected: all tests pass.

- [ ] **Step 2: Run analyzer**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter analyze'
```

Expected: `No issues found!`

- [ ] **Step 3: Run diff check**

Run:

```bash
git diff --check
```

Expected: no output and exit 0.

- [ ] **Step 4: Update spec checklist**

Mark requirements as `DONE`, `PARTIAL`, or `BLOCKED` based only on evidence from Steps 1-3 and direct code inspection. Do not mark an item `DONE` because unrelated tests pass.

- [ ] **Step 5: Commit verification doc update**

```bash
git add docs/superpowers/specs/2026-06-25-mixed-text-chunk-design.md
git commit -m "docs: update mixed chunk verification"
```

- [ ] **Step 6: Push branch**

```bash
git push origin feature/tag-sheet-registry-text-markers
```

- [ ] **Step 7: Watch GitHub Actions**

Run:

```bash
gh run list --repo elizerpist/djinn --branch feature/tag-sheet-registry-text-markers --limit 1
```

Then watch the latest run:

```bash
gh run watch <run-id> --repo elizerpist/djinn --interval 10 --exit-status
```

Expected: workflow completes successfully. If it fails, inspect with:

```bash
gh run view <run-id> --repo elizerpist/djinn --log-failed
```

---

## Self-Review

- Spec coverage: OCR-01/OCR-02 in Task 1; MIX-01/MIX-02/MIX-06 in Task 2; COMPAT-02 in Task 3; PDF-02/COMPAT-01 in Task 4; MIX-03/MIX-04/MIX-05/UX-01/UX-02 in Task 5; PDF-01 in Task 6; EXPORT-01/SEARCH-01 in Task 7; checklist verification in Task 8.
- Placeholder scan: no unfinished marker words or unspecified test-writing steps remain.
- Type consistency: mixed model names are `NoteBlockType.mixed`, `NoteMixedSectionType`, `NoteMixedSection`, `mixedSections`, and `structuredContentJson` throughout.
