# Textchunk Blank Reset Acceptance Checklist

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TCBR-01 | User: "0-ázd le, mindent azaz mindent" | `lib/src/notes/ui/text_chunk/`, `lib/src/notes/ui/native_selection_rail_bridge.dart`, Android rail package | All textchunk-specific runtime modules and native rail bridge files are physically deleted, not patched. | DONE: `find lib/src/notes/ui/text_chunk android/app/src/main/kotlin/com/elizerpist/djinn/rail` returns nothing; old-symbol `rg` returns no hits in `lib`, `android`, or `test`. | DONE |
| TCBR-02 | User: "blank google keepet akarok" | `lib/src/notes/ui/note_text_chunk_editor_screen.dart` | The textchunk editor uses a single Flutter `TextField` as the editing surface; no custom `EditableText`, custom text controller, rail, tag span, underline, or paragraph step logic is present. | DONE: `test/note_text_chunk_editor_screen_test.dart` asserts one `TextField` with key `note-text-plain-field`; old runtime files are deleted. | DONE |
| TCBR-03 | User: native selection must work before adding features back | `note_text_chunk_editor_screen.dart` | The editor does not intercept selection gestures with custom wrappers or overlay controls; native `TextField` owns keyboard, toolbar, selection handles, and scroll. | DONE: code inspection and `rg "GestureDetector|Listener|Stack|EditableText" lib/src/notes/ui/note_text_chunk_editor_screen.dart` show no custom gesture/overlay/editor surface. | DONE |
| TCBR-04 | Existing notes behavior | `note_text_chunk_editor_screen.dart`, `note_editor_route.dart` | Typing text updates `NoteBlock.text` and preserves unrelated block metadata without range-tag/paragraph remap logic. | DONE: widget and route tests enter text and assert block/repository text updated; text edits clear textchunk range/paragraph metadata. | DONE |
| TCBR-05 | Regression safety | Tests and static analysis | Deleted textchunk tests are removed or rewritten so no old feature expectation remains. Full relevant tests and analysis pass. | DONE: targeted tests `24/24 passed`; full `flutter test` `380 passed, 8 environment skips`; `flutter analyze` no issues; old-symbol `rg` clean. | DONE |

## Verification Notes

- RED verification: `flutter test test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart` failed because `note-text-plain-field` did not exist.
- GREEN targeted: `flutter test test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart test/note_document_test.dart`: `24/24 passed`.
- Full suite: `flutter test`: `380 passed`, `8` ObjectBox host-library environment skips.
- Static analysis: `flutter analyze`: no issues found.
- Old-symbol scan: `rg "NativeSelectionRail|TextChunkSpanController|TextChunkParagraph|textChunkNativeRailState|note-text-native-editor|note-text-indent|note-text-outdent|text_chunk/|native_selection_rail_bridge|TextChunkNative|TextChunkMargin|applyTextChunkParagraph|textChunkEditFromTextChange" lib android test` returned no hits.
