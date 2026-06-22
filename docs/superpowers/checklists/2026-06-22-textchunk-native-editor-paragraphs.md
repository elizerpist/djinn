# Text Chunk Native Editor Rewrite Checklist

Scope: rebuild the text chunk runtime so native selection works while retaining keyboard rail, tag coloring, secondary underline spacing, and paragraph handling.

| ID | Source instruction | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TNEP-01 | User: "ok, de rail legyen" | Text chunk screen, native rail bridge, rail state | Keyboard-anchored rail remains available for selected text and collapsed cursor inside tagged text. | Widget/native channel tests plus Android manual check. | PARTIAL |
| TNEP-02 | User: "taggelési színezés" | Text controller/span builder | Range tag primary color is rendered through real `TextSpan` styling without placeholders or offset remapping. | Unit/widget tests inspect text equality and span behavior. | DONE |
| TNEP-03 | User: "underline befolyásolja az adott sor sorközét, ha egynél több van" | Text chunk span/underline layout | Only visual lines with secondary tag lanes reserve extra vertical space; unaffected lines stay normal height. | Widget test with mixed tagged/untagged lines and height/line metric assertion. | DONE |
| TNEP-04 | User: "legyen bekezdés kezelés is" | Note document model, text chunk paragraph helpers | Single newline stays in paragraph; double newline starts a new paragraph; paragraph metadata exists separately from text. | Model/unit tests for boundaries, serialization, and edit remapping. | DONE |
| TNEP-05 | User: prior "step in step out" and current paragraph handling | Paragraph metadata and rail/header actions | Step in/out changes paragraph level metadata for touched paragraphs without changing text length; visible per-paragraph indent is enabled only if a native-safe layout mechanism is proven. | Unit/widget tests assert text unchanged and metadata changed; implementation notes mark visual indent DONE or BLOCKED explicitly. | PARTIAL |
| TNEP-06 | User: "Google Keep szerű élmény", repeated selection failure | Text editor runtime | Editable surface has no outer gesture wrapper, no hidden text, no inline rail, no placeholder, no text-mutating indent. | Code inspection, negative `rg`, widget tests, Android manual long-press/handle-drag check. | PARTIAL |
| TNEP-07 | User: "kijelölés az egész textchunkot érintheti" | Text editor runtime | One native editable surface can select across the whole text chunk. | Widget test and Android manual selection check. | PARTIAL |
| TNEP-08 | User: table rail reference | Rail renderer/state | Rail visual behavior matches table/list rail: icon actions, two scroll rows, closable tag row, tag pills, style toggles. | Source comparison and rail payload tests. | DONE |
| TNEP-09 | Prior failure analysis | Tests | Tests no longer rely only on programmatic `controller.selection`; manual/integration selection checks are documented. | Test review and manual checklist entry. | PARTIAL |
| TNEP-10 | Global AGENTS.md | Verification | No completion claim until checklist statuses are DONE or explicitly deferred. | Re-read checklist before final/build/push. | DONE |

## Verification Notes

- `flutter test test/note_document_test.dart test/text_chunk_paragraphs_test.dart test/text_chunk_span_controller_test.dart test/note_text_chunk_editor_screen_test.dart test/native_selection_rail_bridge_test.dart test/note_editor_route_test.dart`: 39/39 passed.
- `flutter analyze`: No issues found.
- `flutter test`: 395 passed, 8 environment skips for missing host ObjectBox library.
- Production old-symbol search has no hits for `TextChunkEditingController`, `TextChunkSecondaryUnderlineOverlay`, `text_chunk_ranges`, `text_chunk_underlines`, `text_chunk_rail_state`, `applyTextChunkParagraphMarginStep`, or `[TextChunkMargin]`.
- Manual Android long-press/handle-drag verification has not been run in this session, so rail/selection rows that require device confirmation remain `PARTIAL`.
- Step in/out now stores paragraph level metadata without changing text length. Native-safe visible per-paragraph left margin is not implemented because stock single-surface `EditableText` has no proven per-paragraph margin API; this part remains explicitly blocked inside `TNEP-05`.
