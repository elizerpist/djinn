# Notes Chunk Workspace Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the temporary mixed-note creation flow with a full-screen note workspace where each typed chunk card is user-authored content, can be reordered, edited in a type-specific full-screen editor, autosaves immediately, and exposes fresh/stale indexing state.

**Architecture:** Keep `NoteItem` as the persisted top-level note, but make `NoteDocument` blocks carry per-block status and revision metadata. Split the current monolithic `NoteDocumentEditorScreen` into a route-level editor shell, reusable chunk cards, and focused full-screen editors for text, list, table, and flowchart blocks. Notes list navigation should open the editor directly instead of a bottom sheet.

**Tech Stack:** Flutter Material widgets, existing notes repository JSON persistence, existing `NoteDocument`/`NoteBlock` model, existing flowchart model adapters, `flutter_test` widget/model tests. Local Flutter execution on Termux is expected to fail; GitHub Actions is the authoritative verification path.

---

## File Structure

- Modify: `lib/src/notes/models/note_document.dart`
  - Add note block indexing metadata, stable content hash helpers, list item payload support, flowchart node coordinates and ports.
- Modify: `lib/src/notes/models/note_item.dart`
  - Preserve `NoteItem` compatibility while exposing document-level helpers for index freshness.
- Modify: `lib/src/notes/data/note_repository.dart`
  - Add autosave-oriented note creation/update APIs and block update helpers.
- Modify: `lib/src/notes/data/note_chunk_builder.dart`
  - Enforce one visible block -> one chunk, with kind and index status.
- Create: `lib/src/notes/ui/note_editor_route.dart`
  - Full-screen note workspace route, title field, editor menu, autosave coordinator.
- Create: `lib/src/notes/ui/note_chunk_card.dart`
  - Read-only collapsible typed chunk card with status chips and drag handle.
- Create: `lib/src/notes/ui/note_chunk_fab.dart`
  - Icon-only main FAB and expanding icon-only sub-FABs.
- Create: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
  - Full-screen text/paragraph editor with indent/outdent and enter semantics.
- Create: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`
  - Google Keep-style list editor with draggable rows and add-row control.
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
  - Remove save button and make it autosave through a callback API.
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
  - Replace dialog-driven save flow with canvas-first autosave editor.
- Create: `lib/src/notes/ui/note_flowchart_canvas.dart`
  - Pinch/pan canvas with draggable palette, node ports, and edge creation.
- Modify: `lib/src/notes/ui/notes_screen.dart`
  - Remove `NoteCreationSheet` flow; open editor route from FAB/tap; add selected-note menus.
- Delete: `lib/src/notes/ui/note_creation_sheet.dart`
  - Remove the obsolete preview/create sheet from production code and tests.
- Create: `lib/src/notes/data/note_share_service.dart`
  - Export one or more notes to `.djinn-note.json` and invoke native Android share via `share_plus`.
- Tests:
  - `test/note_document_test.dart`
  - `test/note_chunk_builder_test.dart`
  - `test/note_repository_test.dart`
  - `test/notes_screen_test.dart`
  - `test/note_editor_route_test.dart`
  - `test/note_chunk_card_test.dart`
  - `test/note_text_chunk_editor_screen_test.dart`
  - `test/note_list_chunk_editor_screen_test.dart`
  - `test/note_table_editor_screen_test.dart`
  - `test/note_flowchart_editor_screen_test.dart`

---

### Task 1: Note Block Metadata and One-Block-One-Chunk Semantics

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Modify: `lib/src/notes/data/note_chunk_builder.dart`
- Test: `test/note_document_test.dart`
- Test: `test/note_chunk_builder_test.dart`

- [ ] **Step 1: Write failing model tests for block status metadata**

Add tests proving blocks serialize `indexedContentHash`, `indexedAt`, and list children while preserving legacy payloads:

```dart
test('note block serializes indexing metadata and content hash', () {
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
});

test('list block preserves ordered list items and hierarchy', () {
  final block = NoteBlock(
    id: 'list-1',
    type: NoteBlockType.listItem,
    listItems: const [
      NoteListItem(id: 'i1', text: 'Elso', level: 0, checked: false),
      NoteListItem(id: 'i2', text: 'Alpont', level: 1, checked: true),
    ],
  );

  final parsed = NoteBlock.fromJson(block.toJson());

  expect(parsed.listItems.map((item) => item.text), ['Elso', 'Alpont']);
  expect(parsed.listItems[1].level, 1);
  expect(parsed.listItems[1].checked, isTrue);
});
```

- [ ] **Step 2: Run focused tests and verify they fail**

Run locally if possible:

```bash
flutter test test/note_document_test.dart test/note_chunk_builder_test.dart
```

Expected locally on Termux: Flutter may fail with ARM64 TLS alignment. If it runs, expect compile failures for missing fields/classes.

- [ ] **Step 3: Implement metadata and list item model**

In `note_document.dart`, add:

```dart
class NoteListItem {
  const NoteListItem({
    required this.id,
    required this.text,
    this.level = 0,
    this.checked = false,
  });

  final String id;
  final String text;
  final int level;
  final bool checked;

  factory NoteListItem.fromJson(Map<String, Object?> json) => NoteListItem(
        id: json['id']?.toString() ?? 'item-1',
        text: json['text']?.toString() ?? '',
        level: json['level'] is int ? json['level'] as int : 0,
        checked: json['checked'] == true,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'text': text,
        if (level != 0) 'level': level,
        if (checked) 'checked': true,
      };

  NoteListItem copyWith({String? id, String? text, int? level, bool? checked}) =>
      NoteListItem(
        id: id ?? this.id,
        text: text ?? this.text,
        level: level ?? this.level,
        checked: checked ?? this.checked,
      );
}
```

Extend `NoteBlock` constructor and JSON parsing with:

```dart
this.listItems = const [],
this.indexedContentHash,
this.indexedAt,
```

Add helpers:

```dart
String get contentHash => stableNoteContentHash(plainTextForIndexing);

bool get hasContent => plainText.trim().isNotEmpty;

bool get isIndexFresh =>
    indexedContentHash != null && indexedContentHash == contentHash;

bool get needsReindex => hasContent && indexedContentHash != null && !isIndexFresh;

String get plainTextForIndexing => switch (type) {
      NoteBlockType.listItem => listItems.isEmpty
          ? text.trim()
          : listItems.map((item) => '  ' * item.level + item.text.trim()).join('
').trim(),
      _ => plainText,
    };
```

Implement `stableNoteContentHash` as a stable FNV-1a helper. Do not use Dart `hashCode`, because it is not a persisted content identity:

```dart
String stableNoteContentHash(String value) {
  const offset = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  var hash = offset;
  for (final byte in utf8.encode(value.trim())) {
    hash ^= byte;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
```

- [ ] **Step 4: Update chunk builder to produce one chunk per non-empty block**

Replace pending text grouping in `NoteChunkBuilder.build` with direct block iteration:

```dart
for (final block in document.blocks) {
  final text = block.plainTextForIndexing.trim();
  if (text.isEmpty) {
    continue;
  }
  chunks.add(
    NoteChunkViewModel(
      id: '$noteId:${block.id}',
      noteId: noteId,
      noteTitle: noteTitle,
      blockId: block.id,
      kind: _kindFor(block.type),
      text: text,
      groupId: noteId,
      isIndexFresh: block.isIndexFresh,
      needsReindex: block.needsReindex,
    ),
  );
}
```

Add fields to `NoteChunkViewModel`:

```dart
final bool isIndexFresh;
final bool needsReindex;
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
flutter test test/note_document_test.dart test/note_chunk_builder_test.dart
```

Expected: PASS on CI. If local Termux fails with TLS alignment, record that and rely on GitHub Actions after push.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/models/note_document.dart lib/src/notes/data/note_chunk_builder.dart test/note_document_test.dart test/note_chunk_builder_test.dart
git commit -m "feat: add note chunk metadata"
```

---

### Task 2: Autosave Repository API for Notes and Blocks

**Files:**
- Modify: `lib/src/notes/data/note_repository.dart`
- Modify: `lib/src/notes/models/note_item.dart`
- Test: `test/note_repository_test.dart`

- [ ] **Step 1: Write failing repository tests for direct editor autosave**

Add tests:

```dart
test('updateNoteDocument allows empty draft note content', () async {
  final repo = MemoryNoteRepository();
  final note = await repo.createDocumentNote(
    title: 'Draft',
    document: const NoteDocument(blocks: [
      NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'initial'),
    ]),
  );

  final updated = await repo.updateNoteDocument(
    note.id,
    title: 'Draft renamed',
    document: const NoteDocument(blocks: [
      NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: ''),
    ]),
  );

  expect(updated.title, 'Draft renamed');
  expect(updated.document.blocks.single.text, '');
});

test('markNoteBlocksIndexed updates matching block hashes', () async {
  final repo = MemoryNoteRepository();
  final note = await repo.createDocumentNote(
    title: 'Index note',
    document: const NoteDocument(blocks: [
      NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'abc'),
    ]),
  );

  final updated = await repo.markNoteBlocksIndexed(note.id, ['block-1']);

  expect(updated.document.blocks.single.isIndexFresh, isTrue);
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/note_repository_test.dart
```

Expected: compile failure for missing `markNoteBlocksIndexed`, and possibly empty draft validation failure.

- [ ] **Step 3: Add repository API**

In abstract `NoteRepository`, add:

```dart
Future<NoteItem> markNoteBlocksIndexed(String noteId, List<String> blockIds);
Future<NoteItem> moveNoteToFolder(String noteId, String? folderId);
```

Update `createDocumentNote` to allow empty draft documents created by editor. Require non-empty title only; `plainText` may be empty.

Implement `markNoteBlocksIndexed` in memory repo:

```dart
final now = _clock();
final blockIdSet = blockIds.toSet();
final document = existing.document.copyWith(
  blocks: [
    for (final block in existing.document.blocks)
      if (blockIdSet.contains(block.id))
        block.copyWith(
          indexedContentHash: block.contentHash,
          indexedAt: now,
        )
      else
        block,
  ],
);
return updateNoteDocument(noteId, title: existing.title, document: document);
```

Implement `moveNoteToFolder` using `copyWith(folderId: folderId, clearFolderId: folderId == null, updatedAt: _clock())`.

Override both in `FileNoteRepository` and call `_persist()`.

- [ ] **Step 4: Run repository tests**

```bash
flutter test test/note_repository_test.dart
```

Expected: PASS on CI.

- [ ] **Step 5: Commit**

```bash
git add lib/src/notes/data/note_repository.dart lib/src/notes/models/note_item.dart test/note_repository_test.dart
git commit -m "feat: autosave note documents"
```

---

### Task 3: Replace Notes Creation Sheet With Full-Screen Editor Route

**Files:**
- Create: `lib/src/notes/ui/note_editor_route.dart`
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Modify/Delete: `lib/src/notes/ui/note_creation_sheet.dart`
- Test: `test/notes_screen_test.dart`
- Test: `test/note_editor_route_test.dart`

- [ ] **Step 1: Write failing widget tests for route navigation**

Add/adjust tests:

```dart
testWidgets('notes FAB opens full screen note editor route', (tester) async {
  final repo = MemoryNoteRepository();
  await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repo)));

  await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
  expect(find.byType(NoteCreationSheet), findsNothing);
});

testWidgets('tapping note opens full screen note editor route', (tester) async {
  final repo = MemoryNoteRepository();
  await repo.createDocumentNote(
    title: 'Existing',
    document: const NoteDocument(blocks: [
      NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'abc'),
    ]),
  );
  await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repo)));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('note-box-existing')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
});
```

Use actual note id key if the current note box uses `ValueKey('note-box-${note.id}')`; capture created note id in the test.

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/notes_screen_test.dart test/note_editor_route_test.dart
```

Expected: failure because FAB still opens `NoteCreationSheet`.

- [ ] **Step 3: Create route shell with immediate title autosave**

Create `NoteEditorRoute`:

```dart
class NoteEditorRoute extends StatefulWidget {
  const NoteEditorRoute({
    super.key,
    required this.repository,
    required this.initialNote,
  });

  final NoteRepository repository;
  final NoteItem initialNote;

  @override
  State<NoteEditorRoute> createState() => _NoteEditorRouteState();
}
```

State keeps `_note`, `_titleController`, `_document`. Implement `_persist()`:

```dart
Future<void> _persist() async {
  final updated = await widget.repository.updateNoteDocument(
    _note.id,
    title: _titleController.text.trim().isEmpty ? 'Nevtelen jegyzet' : _titleController.text,
    document: _document,
  );
  if (mounted) setState(() => _note = updated);
}
```

Build keys:

```dart
Scaffold(
  key: const ValueKey('note-editor-route'),
  appBar: AppBar(...),
  body: Column(children: [
    TextField(key: const ValueKey('note-editor-title-field'), ...),
    Expanded(child: ...),
  ]),
)
```

- [ ] **Step 4: Update NotesScreen navigation**

Replace `_openCreateSheet` with `_openEditor({NoteItem? note})`:

```dart
Future<void> _openEditor({NoteItem? note}) async {
  final target = note ?? await widget.repository.createDocumentNote(
    title: 'Nevtelen jegyzet',
    document: NoteDocument.empty(),
    folderId: _activeFolderId,
  );
  await Navigator.of(context).push<void>(
    PageRouteBuilder(
      pageBuilder: (_, animation, __) => NoteEditorRoute(
        repository: widget.repository,
        initialNote: target,
      ),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
        child: child,
      ),
    ),
  );
  await _load();
}
```

- [ ] **Step 5: Remove old live flow**

Remove `NoteCreationSheet` import and usage from `notes_screen.dart`. Delete `note_creation_sheet.dart` in Task 10 after all tests are migrated away from it.

- [ ] **Step 7: Run tests**

```bash
flutter test test/notes_screen_test.dart test/note_editor_route_test.dart
```

Expected: PASS on CI.

- [ ] **Step 8: Commit**

```bash
git add lib/src/notes/ui/note_editor_route.dart lib/src/notes/ui/notes_screen.dart test/notes_screen_test.dart test/note_editor_route_test.dart
git commit -m "feat: open notes in full screen editor"
```

---

### Task 4: Chunk Card Rendering, Expand/Collapse, Delete Undo, and Live Reorder

**Files:**
- Create: `lib/src/notes/ui/note_chunk_card.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Test: `test/note_chunk_card_test.dart`
- Test: `test/note_editor_route_test.dart`

- [ ] **Step 1: Write failing chunk card rendering tests**

```dart
testWidgets('expanded chunk card renders list and status chips read only', (tester) async {
  final block = NoteBlock(
    id: 'list-1',
    type: NoteBlockType.listItem,
    listItems: const [
      NoteListItem(id: 'i1', text: 'Elso pont'),
      NoteListItem(id: 'i2', text: 'Masodik pont', level: 1),
    ],
  );

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: NoteChunkCard(
        block: block,
        expanded: true,
        onToggleExpanded: () {},
        onOpenEditor: () {},
        onDelete: () {},
        dragHandle: const Icon(Icons.drag_indicator),
      ),
    ),
  ));

  expect(find.text('Kinyerve'), findsOneWidget);
  expect(find.text('Elso pont'), findsOneWidget);
  expect(find.text('Masodik pont'), findsOneWidget);
  expect(find.byType(TextField), findsNothing);
});
```

- [ ] **Step 2: Write failing route tests for reorder and undo**

```dart
testWidgets('delete chunk shows undo and restores original position', (tester) async {
  final repo = MemoryNoteRepository();
  final note = await repo.createDocumentNote(
    title: 'N',
    document: const NoteDocument(blocks: [
      NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'A'),
      NoteBlock(id: 'b', type: NoteBlockType.paragraph, text: 'B'),
    ]),
  );
  await tester.pumpWidget(MaterialApp(home: NoteEditorRoute(repository: repo, initialNote: note)));

  await tester.tap(find.byKey(const ValueKey('note-chunk-delete-a')));
  await tester.pump();
  expect(find.text('A'), findsNothing);

  await tester.tap(find.text('Visszavonás'));
  await tester.pumpAndSettle();
  expect(find.text('A'), findsOneWidget);
});
```

- [ ] **Step 3: Implement `NoteChunkCard`**

Expose:

```dart
class NoteChunkCard extends StatelessWidget {
  const NoteChunkCard({
    super.key,
    required this.block,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onOpenEditor,
    required this.onDelete,
    required this.dragHandle,
  });
}
```

Header contains icon, type label, chips, expand button, delete button. Body uses renderer helpers:

```dart
Widget _expandedBody(BuildContext context) => switch (block.type) {
  NoteBlockType.table => _TablePreview(rows: block.rows),
  NoteBlockType.flowchart => _FlowchartPreview(block: block),
  NoteBlockType.listItem => _ListPreview(items: block.listItems, fallbackText: block.text),
  _ => _ParagraphPreview(text: block.text),
};
```

- [ ] **Step 4: Implement reorder in editor route**

Use `ReorderableListView.builder` or a focused reorder widget. The plan requires live reorder; Flutter `ReorderableListView` visually reorders during drag and is acceptable if the proxy decorator preserves card size.

```dart
ReorderableListView.builder(
  buildDefaultDragHandles: false,
  proxyDecorator: (child, index, animation) => Material(
    color: Colors.transparent,
    child: child,
  ),
  onReorder: _reorderBlocks,
  itemBuilder: (context, index) {
    final block = _document.blocks[index];
    return NoteChunkCard(
      key: ValueKey('note-chunk-card-${block.id}'),
      dragHandle: ReorderableDragStartListener(
        key: ValueKey('note-chunk-drag-${block.id}'),
        index: index,
        child: const Icon(Icons.drag_indicator),
      ),
      ...
    );
  },
)
```

- [ ] **Step 5: Implement delete undo**

```dart
void _deleteBlock(NoteBlock block) {
  final index = _document.blocks.indexWhere((item) => item.id == block.id);
  final next = [..._document.blocks]..removeAt(index);
  _setDocument(_document.copyWith(blocks: next));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Chunk torolve'),
      action: SnackBarAction(
        label: 'Visszavonás',
        onPressed: () {
          final restored = [..._document.blocks]..insert(index, block);
          _setDocument(_document.copyWith(blocks: restored));
        },
      ),
    ),
  );
}
```

- [ ] **Step 7: Run tests**

```bash
flutter test test/note_chunk_card_test.dart test/note_editor_route_test.dart
```

Expected: PASS on CI.

- [ ] **Step 8: Commit**

```bash
git add lib/src/notes/ui/note_chunk_card.dart lib/src/notes/ui/note_editor_route.dart test/note_chunk_card_test.dart test/note_editor_route_test.dart
git commit -m "feat: render reorderable note chunks"
```

---

### Task 5: Icon-Only Add Chunk FAB

**Files:**
- Create: `lib/src/notes/ui/note_chunk_fab.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Test: `test/note_editor_route_test.dart`

- [ ] **Step 1: Write failing FAB tests**

```dart
testWidgets('editor FAB expands icon only chunk actions', (tester) async {
  final repo = MemoryNoteRepository();
  final note = await repo.createDocumentNote(title: 'N', document: NoteDocument.empty());
  await tester.pumpWidget(MaterialApp(home: NoteEditorRoute(repository: repo, initialNote: note)));

  await tester.tap(find.byKey(const ValueKey('note-editor-add-fab')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('note-editor-add-text')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-editor-add-list')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-editor-add-table')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-editor-add-flowchart')), findsOneWidget);
  expect(find.text('Szöveg'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/note_editor_route_test.dart
```

Expected: missing FAB keys.

- [ ] **Step 3: Implement `NoteChunkFab`**

Expose callbacks:

```dart
class NoteChunkFab extends StatefulWidget {
  const NoteChunkFab({
    super.key,
    required this.onAddText,
    required this.onAddList,
    required this.onAddTable,
    required this.onAddFlowchart,
  });
}
```

Use one main FAB with key `note-editor-add-fab` and four `FloatingActionButton.small` widgets with only icons and tooltips.

- [ ] **Step 4: Wire chunk creation**

In route:

```dart
void _addBlock(NoteBlockType type) {
  final block = _emptyBlockFor(type);
  _setDocument(_document.copyWith(blocks: [..._document.blocks, block]));
}
```

`_emptyBlockFor` creates non-colliding ids and basic empty payload.

- [ ] **Step 5: Run tests**

```bash
flutter test test/note_editor_route_test.dart
```

Expected: PASS on CI.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/ui/note_chunk_fab.dart lib/src/notes/ui/note_editor_route.dart test/note_editor_route_test.dart
git commit -m "feat: add note chunk fab"
```

---

### Task 6: Full-Screen Text Chunk Editor

**Files:**
- Create: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`
- Test: `test/note_editor_route_test.dart`

- [ ] **Step 1: Write failing text editor tests**

```dart
testWidgets('text editor autosaves changed block without save button', (tester) async {
  NoteBlock? latest;
  await tester.pumpWidget(MaterialApp(
    home: NoteTextChunkEditorScreen(
      block: const NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'old'),
      onChanged: (block) => latest = block,
    ),
  ));

  expect(find.text('Mentés'), findsNothing);
  await tester.enterText(find.byKey(const ValueKey('note-text-editor-field')), 'first
second');
  await tester.pump();

  expect(latest?.text, 'first
second');
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/note_text_chunk_editor_screen_test.dart
```

Expected: missing class.

- [ ] **Step 3: Implement text editor**

Create screen with `TextEditingController`, appbar indent/outdent icon buttons, no save action:

```dart
TextField(
  key: const ValueKey('note-text-editor-field'),
  controller: _controller,
  keyboardType: TextInputType.multiline,
  maxLines: null,
  onChanged: (_) => widget.onChanged(_block.copyWith(text: _controller.text)),
)
```

Indent/outdent should update only the paragraph containing current selection:

```dart
String _indentCurrentParagraph(String text, TextSelection selection, int delta) {
  final start = text.lastIndexOf('
', selection.baseOffset - 1) + 1;
  final end = text.indexOf('
', selection.baseOffset);
  final paragraphEnd = end == -1 ? text.length : end;
  final paragraph = text.substring(start, paragraphEnd);
  final updated = delta > 0
      ? '  $paragraph'
      : paragraph.startsWith('  ') ? paragraph.substring(2) : paragraph;
  return text.replaceRange(start, paragraphEnd, updated);
}
```

- [ ] **Step 4: Wire chunk body tap to text editor**

In `NoteEditorRoute`, route paragraph/heading blocks to `NoteTextChunkEditorScreen(block: block, onChanged: _replaceBlockAndPersist)`.

- [ ] **Step 5: Run tests**

```bash
flutter test test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart
```

Expected: PASS on CI.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/ui/note_text_chunk_editor_screen.dart lib/src/notes/ui/note_editor_route.dart test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart
git commit -m "feat: add text chunk editor"
```

---

### Task 7: Google Keep-Style List Chunk Editor

**Files:**
- Create: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Test: `test/note_list_chunk_editor_screen_test.dart`

- [ ] **Step 1: Write failing list editor tests**

```dart
testWidgets('list editor adds deletes and reorders rows with autosave', (tester) async {
  NoteBlock? latest;
  final block = NoteBlock(
    id: 'list-1',
    type: NoteBlockType.listItem,
    listItems: const [
      NoteListItem(id: 'a', text: 'A'),
      NoteListItem(id: 'b', text: 'B'),
    ],
  );

  await tester.pumpWidget(MaterialApp(
    home: NoteListChunkEditorScreen(block: block, onChanged: (value) => latest = value),
  ));

  await tester.tap(find.byKey(const ValueKey('note-list-add-item')));
  await tester.pump();
  expect(latest?.listItems.length, 3);

  await tester.tap(find.byKey(const ValueKey('note-list-delete-a')));
  await tester.pump();
  expect(latest?.listItems.map((item) => item.id), isNot(contains('a')));
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/note_list_chunk_editor_screen_test.dart
```

Expected: missing class.

- [ ] **Step 3: Implement list editor**

Use `ReorderableListView.builder`, left drag handle, checkbox, text field, active-row delete icon, add row below list. Keys:

- `note-list-row-$id`
- `note-list-drag-$id`
- `note-list-field-$id`
- `note-list-delete-$id`
- `note-list-add-item`

Each change calls:

```dart
widget.onChanged(widget.block.copyWith(listItems: List.unmodifiable(_items)));
```

- [ ] **Step 4: Wire chunk body tap to list editor**

In route, `NoteBlockType.listItem` opens `NoteListChunkEditorScreen`.

- [ ] **Step 5: Run tests**

```bash
flutter test test/note_list_chunk_editor_screen_test.dart test/note_editor_route_test.dart
```

Expected: PASS on CI.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/ui/note_list_chunk_editor_screen.dart lib/src/notes/ui/note_editor_route.dart test/note_list_chunk_editor_screen_test.dart test/note_editor_route_test.dart
git commit -m "feat: add list chunk editor"
```

---

### Task 8: Autosave Table Editor and Table Card Preview

**Files:**
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_chunk_card.dart`
- Test: `test/note_table_editor_screen_test.dart`
- Test: `test/note_chunk_card_test.dart`

- [ ] **Step 1: Write failing autosave table test**

```dart
testWidgets('table editor autosaves cell changes without save button', (tester) async {
  NoteBlock? latest;
  final block = NoteBlock(id: 'table-1', type: NoteBlockType.table, rows: const [['A', 'B']]);

  await tester.pumpWidget(MaterialApp(
    home: NoteTableEditorScreen(block: block, onChanged: (value) => latest = value),
  ));

  expect(find.text('Mentés'), findsNothing);
  await tester.enterText(find.byKey(const ValueKey('note-table-cell-0-0')), 'COPD');
  await tester.pump();

  expect(latest?.rows.first.first, 'COPD');
});
```

- [ ] **Step 2: Run test to verify failure**

```bash
flutter test test/note_table_editor_screen_test.dart
```

Expected: constructor mismatch and save button still present.

- [ ] **Step 3: Change table editor API**

Update constructor:

```dart
const NoteTableEditorScreen({super.key, required this.block, required this.onChanged});
final ValueChanged<NoteBlock> onChanged;
```

Remove appbar save action. After `_updateCell`, `_addRow`, `_addColumn`, `_deleteRow`, `_deleteColumn`, call `_emit()`:

```dart
void _emit() {
  widget.onChanged(widget.block.copyWith(rows: [
    for (final row in _rows) row.map((cell) => cell.trim()).toList(growable: false),
  ]));
}
```

- [ ] **Step 4: Ensure chunk card renders table widget**

`NoteChunkCard` table body should use a compact `Table` widget with borders, not flattened text.

- [ ] **Step 5: Run tests**

```bash
flutter test test/note_table_editor_screen_test.dart test/note_chunk_card_test.dart
```

Expected: PASS on CI.

- [ ] **Step 6: Commit**

```bash
git add lib/src/notes/ui/note_table_editor_screen.dart lib/src/notes/ui/note_chunk_card.dart test/note_table_editor_screen_test.dart test/note_chunk_card_test.dart
git commit -m "feat: autosave note tables"
```

---

### Task 9: Canvas-Based Flowchart Chunk Editor

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Create: `lib/src/notes/ui/note_flowchart_canvas.dart`
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_chunk_card.dart`
- Test: `test/note_flowchart_editor_screen_test.dart`
- Test: `test/note_chunk_card_test.dart`

- [ ] **Step 1: Write failing flowchart model/editor tests**

```dart
test('flowchart node stores canvas position and port metadata survives json', () {
  final node = NoteFlowchartNode(
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

testWidgets('flowchart editor has icon palette and no save button', (tester) async {
  NoteBlock? latest;
  await tester.pumpWidget(MaterialApp(
    home: NoteFlowchartEditorScreen(
      block: const NoteBlock(id: 'flow-1', type: NoteBlockType.flowchart),
      onChanged: (value) => latest = value,
    ),
  ));

  expect(find.text('Mentés'), findsNothing);
  expect(find.byKey(const ValueKey('note-flow-palette-start')), findsOneWidget);
  expect(find.byKey(const ValueKey('note-flow-canvas')), findsOneWidget);
});
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/note_flowchart_editor_screen_test.dart test/note_chunk_card_test.dart
```

Expected: constructor mismatch/missing canvas.

- [ ] **Step 3: Extend flowchart node model**

Add to `NoteFlowchartNode`:

```dart
this.x = 0,
this.y = 0,
```

Add JSON keys only when non-zero:

```dart
if (x != 0) 'x': x,
if (y != 0) 'y': y,
```

Use `num` parsing for compatibility.

- [ ] **Step 4: Implement `NoteFlowchartCanvas`**

Build with `InteractiveViewer`:

```dart
InteractiveViewer(
  key: const ValueKey('note-flow-canvas'),
  minScale: 0.35,
  maxScale: 3.0,
  boundaryMargin: const EdgeInsets.all(2000),
  constrained: false,
  child: SizedBox(width: 2400, height: 1800, child: Stack(children: ...)),
)
```

Render nodes positioned at `node.x/node.y`; draw edges using `CustomPaint`. Provide node port hit targets with keys:

- `note-flow-port-${node.id}-in`
- `note-flow-port-${node.id}-out`
- `note-flow-port-${node.id}-yes`
- `note-flow-port-${node.id}-no`

- [ ] **Step 5: Implement icon-only palette**

Right vertical palette keys:

- `note-flow-palette-start`
- `note-flow-palette-process`
- `note-flow-palette-decision`
- `note-flow-palette-end`

Use `LongPressDraggable<AiFlowchartNodeShape>` and `DragTarget` on canvas. Dropping creates a node with shape-specific label and x/y from local drop offset.

- [ ] **Step 6: Implement node connection mode**

Maintain selected source port. Tapping a compatible target port creates `NoteFlowchartEdge` with `fromNodeId`, `toNodeId`, and `label` set to `Igen` or `Nem` for decision output ports.

Allow multiple edges to the same input node; reject self-connections.

- [ ] **Step 7: Update editor screen API**

Constructor:

```dart
const NoteFlowchartEditorScreen({super.key, required this.block, required this.onChanged});
final ValueChanged<NoteBlock> onChanged;
```

Remove save action and call `onChanged` on every node/edge mutation.

- [ ] **Step 8: Ensure chunk card renders visual flowchart**

Use `NoteFlowchartCanvas.preview(block: block)` or a separate compact preview widget. It must display nodes/edges, not `block.plainText`.

- [ ] **Step 9: Run tests**

```bash
flutter test test/note_flowchart_editor_screen_test.dart test/note_chunk_card_test.dart
```

Expected: PASS on CI.

- [ ] **Step 10: Commit**

```bash
git add lib/src/notes/models/note_document.dart lib/src/notes/ui/note_flowchart_canvas.dart lib/src/notes/ui/note_flowchart_editor_screen.dart lib/src/notes/ui/note_chunk_card.dart test/note_flowchart_editor_screen_test.dart test/note_chunk_card_test.dart
git commit -m "feat: add note flowchart canvas"
```

---

### Task 10: Menus, Index Actions, and Placeholder Cleanup

**Files:**
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Delete or archive: `lib/src/notes/ui/note_creation_sheet.dart`
- Test: `test/notes_screen_test.dart`
- Test: `test/note_editor_route_test.dart`

- [ ] **Step 1: Write failing menu tests**

```dart
testWidgets('editor menu has working note actions without rename', (tester) async {
  final repo = MemoryNoteRepository();
  final note = await repo.createDocumentNote(title: 'N', document: NoteDocument.empty());
  await tester.pumpWidget(MaterialApp(home: NoteEditorRoute(repository: repo, initialNote: note)));

  await tester.tap(find.byKey(const ValueKey('note-editor-menu')));
  await tester.pumpAndSettle();

  expect(find.text('Indexelés / újraindexelés'), findsOneWidget);
  expect(find.text('Chunkok megtekintése'), findsOneWidget);
  expect(find.text('Átnevezés'), findsNothing);
});
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/notes_screen_test.dart test/note_editor_route_test.dart
```

Expected: menu keys/actions missing.

- [ ] **Step 3: Create note export/share service**

Create `lib/src/notes/data/note_share_service.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/note_item.dart';

class NoteSharedFile {
  const NoteSharedFile({required this.path, required this.filename});

  final String path;
  final String filename;
}

typedef NoteShareAdapter = Future<void> Function(NoteSharedFile file);

class NoteShareService {
  const NoteShareService({this.shareAdapter});

  final NoteShareAdapter? shareAdapter;

  Future<File> exportNotes(List<NoteItem> notes, {required File target}) async {
    final payload = jsonEncode({
      'schemaVersion': 1,
      'type': 'djinn_notes',
      'notes': notes.map((note) => note.toJson()).toList(),
    });
    await target.writeAsString(payload);
    return target;
  }

  Future<NoteSharedFile> shareNotes(
    List<NoteItem> notes, {
    String filename = 'djinn-notes.djinn-note.json',
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$filename');
    await exportNotes(notes, target: file);
    final shared = NoteSharedFile(path: file.path, filename: filename);
    await (shareAdapter ?? _shareWithPlatform)(shared);
    return shared;
  }

  static Future<void> _shareWithPlatform(NoteSharedFile file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, name: file.filename)]),
    );
  }
}
```

- [ ] **Step 4: Implement editor menu actions**

Use `PopupMenuButton<String>(key: ValueKey('note-editor-menu'))` with values:

- `index`
- `chunks`
- `audit`
- `move-folder`
- `export`
- `share`
- `delete`

For this implementation pass, visible menu items must perform a concrete action:

- `index`: call `markNoteBlocksIndexed` for all non-empty blocks.
- `chunks`: show a modal/list of chunks from `NoteChunkBuilder`.
- `audit`: open the existing `ChunkValidationCard` for the note plain text and persist the returned validation through `updateNoteValidation`.
- `move-folder`: show a folder picker dialog backed by `listFolders`; update repository with `moveNoteToFolder`.
- `export`: call `NoteShareService.exportNotes` and save `.djinn-note.json` with `FilePicker.saveFile`.
- `share`: call `NoteShareService.shareNotes` and invoke the native Android share sheet through `share_plus`.
- `delete`: call `deleteNotes([note.id])` and pop the editor route.

Do not leave disabled non-working menu items.

- [ ] **Step 5: Implement selected-note list header menu**

Implement long-press selection in `NotesScreen`:

- selected ids set;
- appbar title shows selected count;
- top menu actions: index/re-index, move folder, export, share, delete;
- export and share use `NoteShareService` over the selected notes;
- tapping an unselected note opens the editor, while tapping during selection toggles selection.

- [ ] **Step 6: Remove `NoteCreationSheet` from production flow**

Delete `note_creation_sheet.dart` and update tests so no production or test code imports it.

- [ ] **Step 7: Run tests**

```bash
flutter test test/notes_screen_test.dart test/note_editor_route_test.dart
```

Expected: PASS on CI.

- [ ] **Step 8: Commit**

```bash
git add lib/src/notes/ui/notes_screen.dart lib/src/notes/ui/note_editor_route.dart lib/src/notes/data/note_share_service.dart test/notes_screen_test.dart test/note_editor_route_test.dart
git rm lib/src/notes/ui/note_creation_sheet.dart
git commit -m "feat: add note workspace menus"
```

---

### Task 11: Full Verification and GitHub Build

**Files:**
- Verify all files changed by Tasks 1-10.
- Modify only the specific test or source file named by analyzer/test failures.

- [ ] **Step 1: Static diff checks**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 2: Local focused tests if Flutter executable works**

Run:

```bash
flutter test test/note_document_test.dart test/note_chunk_builder_test.dart test/note_repository_test.dart test/notes_screen_test.dart test/note_editor_route_test.dart test/note_chunk_card_test.dart test/note_text_chunk_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart test/note_table_editor_screen_test.dart test/note_flowchart_editor_screen_test.dart
```

Expected on Termux: may fail with Dart ARM64 TLS alignment. If so, note this exact environment limitation and continue to GitHub Actions verification.

- [ ] **Step 3: Push branch**

```bash
git push origin feature/knowledge-ocr-inspector
```

Expected: push succeeds.

- [ ] **Step 4: Verify GitHub Actions**

Use `gh run list` and `gh run watch`:

```bash
gh run list --branch feature/knowledge-ocr-inspector --limit 3
gh run watch <run-id> --exit-status
```

Expected: Android native build workflow completes successfully, including analyze, Flutter tests, debug APK build, and release publication.

- [ ] **Step 5: Final status**

Report:

- latest commit hash;
- GitHub Actions run URL;
- whether local tests were blocked by Termux Dart TLS;
- any user-visible menu item removed because no working handler exists for it.
