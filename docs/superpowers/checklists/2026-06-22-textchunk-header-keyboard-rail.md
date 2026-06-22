Scope: rebuild the text chunk header and keyboard-top rail on top of the plain native TextField baseline.

| ID | Source | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TCHR-01 | User: "visszaepited a headert" | `lib/src/notes/ui/note_text_chunk_editor_screen.dart` | Text chunks use `NoteChunkEditorHeader` with editable title, global tag action, selected-range tag action, selected-tag delete action, chunk delete action, and step out/in header buttons. | DONE: `test/note_text_chunk_editor_screen_test.dart` asserts header keys, title autosave, global tag save, and rail range tag save. | DONE |
| TCHR-02 | User: "topkeyboard railt" and prior keyboard-top requirement | `note_text_chunk_editor_screen.dart` | A `NoteSelectionActionRail` appears above the keyboard area only when there is selected text or a collapsed cursor inside an existing tagged range; typing untagged text keeps it hidden. | DONE: widget tests set selection and `viewInsets.bottom`, then assert rail presence/absence and bottom padding. | DONE |
| TCHR-03 | User: "ugyanaz ... mint a tablazatokban" | `note_tag_pills.dart` reuse from text screen | Text rail reuses `NoteSelectionActionRail`, including two scroll rows, closable tag row, table/list colors, border/rounded/grey style toggles, and tag pills. | DONE: widget tests assert shared rail keys, two rows, tag pill prefix, and rounded/grey/borderless toggles. | DONE |
| TCHR-04 | User: step in/out should do what header buttons do | Text paragraph metadata helpers in `note_text_chunk_editor_screen.dart` | Step out/in update `paragraphStyles` metadata for all paragraphs intersecting the current selection/cursor without mutating `block.text`. | DONE: widget test asserts text unchanged, paragraph range metadata added on indent, and removed on outdent. | DONE |
| TCHR-05 | User: rail must not break native selection | Text editor surface | The editor remains one stock `TextField`; there is no custom `EditableText`, no text placeholder, no rail inserted into text, no hidden spacer, and no gesture wrapper over the field. | DONE: editor body has one keyed `TextField`; controller text remains plain text after rail actions; old-symbol scan returned no hits. | DONE |

## Verification Notes

- RED: `flutter test test/note_text_chunk_editor_screen_test.dart` failed on the blank reset because `note-chunk-title-field`, `note-text-keyboard-rail`, and `note-text-rail-indent` were missing.
- GREEN targeted: `flutter test test/note_text_chunk_editor_screen_test.dart`: 7/7 passed.
- GREEN regressions: `flutter test test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart test/note_document_test.dart test/note_selection_action_rail_test.dart`: 30/30 passed.
- Static: `flutter analyze`: No issues found.
- Full suite: `flutter test`: 385 passed, 8 ObjectBox host-library environment skips.
- Old-symbol scan: no hits for deleted native/textchunk rail artifacts or placeholder markers in `lib`, `android`, or `test`.
