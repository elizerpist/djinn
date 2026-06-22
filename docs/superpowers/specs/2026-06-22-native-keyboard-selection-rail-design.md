# Native Keyboard Selection Rail Design

Date: 2026-06-22

## Context

The text chunk editor must keep Flutter's native `EditableText` as the visible text editor. The previous in-text rail approach inserted hidden spacer placeholders into the native text layout, which caused selection handle drag ticks, layout jumps, and accidental rail action hits while dragging. The new direction rejects in-text rail placement.

## Approved Behavior

The selection rail is a native Android view attached to the keyboard top. It is not a Flutter widget chasing keyboard events, and it is not inserted into the `EditableText` layout. The rail must move in the same native frame pipeline as the keyboard animation.

The rail is visible when the editor has an active rail range:

- the user selects a non-collapsed text range;
- the user taps into an already tagged text range, even if the native cursor is collapsed;
- a rail action focuses an existing tagged range.

The rail is hidden when no active range exists, such as ordinary typing in untagged text. It must not appear simply because the editor has focus or because the keyboard is open.

Existing underline/tag decoration may still expand the line it belongs to. Only rail-driven native placeholders/spacers are forbidden.

## Architecture

Dart owns text editing state and note-domain actions. Android owns rail rendering and keyboard-synchronized movement.

Dart sends a serializable `NativeSelectionRailState` over a method channel whenever the active range, tags, action enabled state, or visual style flags change. Android renders a `NativeSelectionRailView` in the Activity window. Android uses `WindowInsetsAnimation.Callback` to position that native view against the IME top during keyboard animation. Android sends rail action IDs back to Dart over the same method channel; Dart executes the existing note actions.

The Flutter text editor receives no `selectionRail`. `TextChunkCanvasEditor` must stop creating rail-line placeholders and inline rail spacer widgets. Underline placeholder logic remains in place.

## iOS Path

The Dart model and rail action contract must stay platform-neutral. Later iOS support should implement the same contract with a native Swift keyboard accessory host, preferably `inputAccessoryView`. If the iOS implementation cannot rely on the system accessory pipeline for a specific screen, it may use keyboard frame notifications plus `CADisplayLink`, but the Flutter editor and Dart state model must not change.

## Acceptance Checklist

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| NKR-001 | User: "a natívot fogod fejleszteni" | `TextChunkCanvasEditor` | Visible text editing stays native `EditableText`; the custom-rendered text editor path is not restored. | Code inspection and widget tests. | DONE |
| NKR-002 | User: "alaphelyzetben nem látható" | `NoteTextChunkEditorScreen`, Dart rail bridge | Native rail hidden when there is no active selection/tag range. | Widget/unit test captures native method call `visible=false`. | DONE |
| NKR-003 | User: "ha user kijelöl egy szöveget" | selection state bridge | Non-collapsed native selection sends `visible=true` native rail state. | Widget/unit test captures native method call with selected range. | DONE |
| NKR-004 | User correction: tagged word tap should show rail | `_selectionTargetRange`, rail bridge | Collapsed cursor inside an existing tagged range still sends `visible=true`. | Widget/unit test with tagged range and collapsed selection. | DONE |
| NKR-005 | User: "ha a user gépel, akkor ne" | selection/text change state | Ordinary typing in untagged text sends or keeps `visible=false`. | Widget/unit test after text input. | DONE |
| NKR-006 | User: "keyboard tetején... slide közben" and "egy frame késést sem akarok" | Android native rail host | Android rail is a native view positioned from `WindowInsetsAnimation.Callback`, not a Flutter `viewInsets` follower. | Kotlin code inspection and Android CI build. | DONE |
| NKR-007 | User: rail must not expand text; underline may expand line | `TextChunkCanvasEditor` | No rail placeholders, no inline rail spacer, no `rail-line-*`; underline spacer behavior remains. | Widget tests and debug log assertions. | DONE |
| NKR-008 | Existing rail actions | Dart native rail action handler | Native actions invoke existing Dart actions: indent, outdent, tag, clear tags, prev/next tag, row/style toggles, and individual tag delete. | Unit/widget tests with mocked MethodChannel native action callbacks. | DONE |
| NKR-009 | Project Flutter build constraint | GitHub Actions | Android debug APK builds online; no local Termux APK build. | GitHub Actions URL after push. | DONE |
