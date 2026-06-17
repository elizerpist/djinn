# Chunk Tag Rail Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inconsistent local tag controls with one inline selected-scope rail pattern for text selections, list items, and table row/column/cell selections.

**Architecture:** Keep the existing `NoteBlock`, `NoteTextRangeTag`, `NoteListItem.tags`, and `NoteScopedTagAssignment` persistence model. Add a shared selected-scope rail widget, then adapt text/list/table editors to render content highlights while keeping tag pills and actions in the rail. Flowchart behavior is only guarded so canvas pills stay absent.

**Tech Stack:** Flutter/Dart, existing notes UI widgets, existing widget tests, GitHub Actions for test/build verification because local Dart/Flutter is not runnable on Termux ARM64.

## Global Constraints

- Do not attempt a local Flutter APK build on Termux/Android.
- Use TDD: write failing widget tests before production UI changes.
- Do not put tag pills inside table cells.
- Do not put tag pills on the flowchart canvas.
- Keep existing tag serialization backward compatible.
- Preserve scoped tag remapping for table row/column deletion and insertion.
- Use the existing tag manager sheet; do not introduce a second tag manager entry point.

---

## File Structure

- Modify `lib/src/notes/ui/note_tag_pills.dart`: add shared `NoteSelectionActionRail` and optional compact rail helpers.
- Modify `lib/src/notes/ui/note_text_chunk_editor_screen.dart`: show selected range rail and move local range pills out of the bottom section.
- Modify `lib/src/notes/ui/note_list_chunk_editor_screen.dart`: remove selector icon, select on row/text tap, show item rail, highlight tagged item text.
- Modify `lib/src/notes/ui/note_table_editor_screen.dart`: replace DataTable body with a compact Excel-like grid, row/column/cell heads, and inline expanding rail.
- Modify `test/note_text_chunk_editor_screen_test.dart`: add text selection rail expectations.
- Modify `test/note_list_chunk_editor_screen_test.dart`: add list rail/highlight/no-selector expectations.
- Modify `test/note_table_editor_screen_test.dart`: add Excel grid, expansion rail, no-selector/no-marker expectations.
- Keep `test/note_flowchart_editor_screen_test.dart`: existing tests already assert no canvas pills and external flowchart tag feedback.

## Task 1: Shared Selected-Scope Rail

**Files:**
- Modify: `lib/src/notes/ui/note_tag_pills.dart`
- Test indirectly through list/table/text widget tests.

**Interfaces:**
- Produces: `NoteSelectionActionRail`, a reusable widget with `tags`, `actions`, optional `label`, and stable key prefix.

- [ ] **Step 1: Write failing list/table tests that require a rail**

Add expectations in the editor tests for keys:

```dart
expect(find.byKey(const ValueKey('note-selection-action-rail')), findsOneWidget);
expect(find.byKey(const ValueKey('note-selection-action-tag')), findsOneWidget);
```

- [ ] **Step 2: Implement the shared rail**

Add this public widget to `note_tag_pills.dart`:

```dart
class NoteSelectionActionRail extends StatelessWidget {
  const NoteSelectionActionRail({
    super.key,
    required this.tags,
    required this.actions,
    this.label,
    this.pillPrefix = 'note-selection-rail-tag-pill',
  });

  final List<NoteKnowledgeTag> tags;
  final List<Widget> actions;
  final String? label;
  final String pillPrefix;
}
```

The rail uses a white surface, 999-radius colored pills, thin border, and compact icon actions.

- [ ] **Step 3: Keep `NoteSelectedTagTray` for flowchart compatibility**

Do not remove `NoteSelectedTagTray`; flowchart tests currently depend on it.

## Task 2: List Item Rail And Highlight

**Files:**
- Modify: `test/note_list_chunk_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`

**Interfaces:**
- Consumes: `NoteSelectionActionRail`.
- Produces: selected item expansion rail and tag-colored text background.

- [ ] **Step 1: Write failing tests**

Add one test that:

```dart
await tester.tap(find.byKey(const ValueKey('note-list-row-item-1')));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('note-list-item-select-item-1')), findsNothing);
expect(find.byKey(const ValueKey('note-selection-action-rail')), findsOneWidget);
expect(find.byKey(const ValueKey('note-list-rail-tag-item-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-list-rail-outdent-item-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-list-rail-indent-item-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-list-rail-delete-item-1')), findsOneWidget);
```

Add a second assertion in the existing tag test:

```dart
expect(find.byKey(const ValueKey('note-list-item-tag-highlight-item-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-list-item-tag-pill-item-1-súlyos')), findsNothing);
```

- [ ] **Step 2: Verify RED**

Run in CI because local Flutter is unavailable:

```bash
git add test/note_list_chunk_editor_screen_test.dart docs/superpowers
git commit -m "test: describe list item tag rail"
git push origin feature/knowledge-ocr-inspector
gh run watch --exit-status
```

Expected: GitHub Actions fails in `note_list_chunk_editor_screen_test.dart` because the selector icon and below-item local pills still exist.

- [ ] **Step 3: Implement minimal list changes**

Remove the item selector `IconButton`. Wrap the item row in a tappable container keyed `note-list-row-<id>`. Keep checkbox beside drag handle. Render a `NoteSelectionActionRail` only when the item is selected. Use `TextStyle(backgroundColor: tagColor.withValues(alpha: 0.22))` on the item text field when `item.tags.isNotEmpty`.

- [ ] **Step 4: Verify GREEN**

Run/push CI again and confirm the list tests pass.

## Task 3: Text Selection Rail

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`

**Interfaces:**
- Consumes: `NoteSelectionActionRail`.
- Produces: active selection rail and removes generic bottom local range pill row.

- [ ] **Step 1: Write failing tests**

Extend the existing selected text test:

```dart
field.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
await tester.pump();
expect(find.byKey(const ValueKey('note-text-selection-rail')), findsOneWidget);
expect(find.byKey(const ValueKey('note-text-selection-rail-tag')), findsOneWidget);
```

After saving a range tag:

```dart
expect(find.byKey(const ValueKey('note-local-tag-pill-súlyos')), findsNothing);
expect(find.byKey(const ValueKey('note-text-range-highlight-range-')), findsWidgets);
```

- [ ] **Step 2: Verify RED**

Run GitHub Actions after committing the test:

```bash
git add test/note_text_chunk_editor_screen_test.dart
git commit -m "test: describe text selection tag rail"
git push origin feature/knowledge-ocr-inspector
gh run watch --exit-status
```

Expected: CI fails because no selection rail exists and local range pills still render below the editor.

- [ ] **Step 3: Implement minimal text rail**

Track `_selectionStart`, `_selectionEnd`, and overlapping tags from the text controller listener. Render a compact rail above the tip bar when selection is non-collapsed. Reuse existing `_tagSelection` and `_deleteSelectedTag` callbacks. Remove the bottom generic local range `NoteTagPills`.

- [ ] **Step 4: Verify GREEN**

Push and watch CI until text tests pass.

## Task 4: Table Excel Grid And Expanding Rail

**Files:**
- Modify: `test/note_table_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`

**Interfaces:**
- Consumes: `NoteSelectionActionRail`.
- Produces: row/column/cell selection through real heads/cells and inline expansion rail.

- [ ] **Step 1: Write failing grid tests**

Replace marker/tray expectations with:

```dart
expect(find.byKey(const ValueKey('note-table-corner-head')), findsOneWidget);
expect(find.byKey(const ValueKey('note-table-column-head-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-table-row-head-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-table-select-cell-1-1')), findsNothing);
```

Tap a cell:

```dart
await tester.tap(find.byKey(const ValueKey('note-table-cell-1-1')));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('note-table-row-expansion-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-selection-action-rail')), findsOneWidget);
```

Tap a column head:

```dart
await tester.tap(find.byKey(const ValueKey('note-table-column-head-1')));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('note-table-column-expansion-1')), findsOneWidget);
```

- [ ] **Step 2: Write failing highlight tests**

Use preseeded scoped tags and assert affected cells render highlight keys:

```dart
expect(find.byKey(const ValueKey('note-table-cell-highlight-1-0')), findsOneWidget);
expect(find.byKey(const ValueKey('note-table-cell-highlight-1-1')), findsOneWidget);
expect(find.byKey(const ValueKey('note-table-cell-tag-marker-1-1')), findsNothing);
expect(find.byKey(const ValueKey('note-selected-tag-tray')), findsNothing);
```

- [ ] **Step 3: Verify RED**

Run CI after committing tests:

```bash
git add test/note_table_editor_screen_test.dart
git commit -m "test: describe table expanding tag rail"
git push origin feature/knowledge-ocr-inspector
gh run watch --exit-status
```

Expected: CI fails because the editor still uses `DataTable`, selector icons, marker dots, and an external tray.

- [ ] **Step 4: Implement the grid**

Replace `DataTable` with a `Column` containing a header row and body rows made of fixed-size `SizedBox` cells:

- corner head key: `note-table-corner-head`
- column head keys: `note-table-column-head-$column`
- row head keys: `note-table-row-head-$row`
- cell field keys remain `note-table-cell-$row-$column`

Use horizontal and vertical `SingleChildScrollView` like today. Selecting a column inserts `note-table-column-expansion-$column` under the header row. Selecting a row or cell inserts `note-table-row-expansion-$row` under that body row.

- [ ] **Step 5: Implement rail actions**

The table rail provides:

- tag selected scope;
- delete selected tag when tags exist;
- delete row for row/cell selection;
- delete column for column/cell selection;
- insert column right for column/cell selection.

Keep header add-row and add-column buttons.

- [ ] **Step 6: Implement highlight resolution**

For each cell, compute tags in this order:

```dart
final direct = _tagsForSelection(_TableSelection.cell(row, column));
final rowTags = _tagsForSelection(_TableSelection.row(row));
final columnTags = _tagsForSelection(_TableSelection.column(column));
final tags = direct.isNotEmpty ? direct : rowTags.isNotEmpty ? rowTags : columnTags;
```

If `tags.isNotEmpty`, wrap the cell field in a keyed highlight container and set text style background color to the first tag color.

- [ ] **Step 7: Verify GREEN**

Push and watch CI until table tests and existing remap/drop tests pass.

## Task 5: Documentation, Full CI, Commit Hygiene

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-18-chunk-tag-rail-redesign.md`

**Interfaces:**
- Produces: final pushed branch with CI evidence.

- [ ] **Step 1: Mark checklist items as complete**

Update completed checkboxes only after tests pass in CI.

- [ ] **Step 2: Try local command only to document Flutter limitation**

Run:

```bash
/data/data/com.termux/files/home/flutter/bin/dart --version
```

Expected: fails on Termux ARM64 with TLS underalignment. Do not run a local APK build.

- [ ] **Step 3: Push final implementation**

```bash
git status --short
git push origin feature/knowledge-ocr-inspector
gh run watch --exit-status
```

Expected: GitHub Actions succeeds and publishes the debug APK through the existing workflow.

- [ ] **Step 4: Final response**

Report the final commit SHA, branch, Actions URL, and APK URL if the workflow publishes one.
