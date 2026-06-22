# Text Chunk Native Editor Rewrite Checklist

Scope: rebuild the text chunk runtime so native selection works while retaining keyboard rail, tag coloring, secondary underline spacing, and paragraph handling.

| ID | Source instruction | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TNEP-01 | User: "ok, de rail legyen" | Text chunk screen, native rail bridge, rail state | Keyboard-anchored rail remains available for selected text and collapsed cursor inside tagged text. | Widget/native channel tests plus Android manual check. | NOT DONE |
| TNEP-02 | User: "taggelési színezés" | Text controller/span builder | Range tag primary color is rendered through real `TextSpan` styling without placeholders or offset remapping. | Unit/widget tests inspect text equality and span behavior. | NOT DONE |
| TNEP-03 | User: "underline befolyásolja az adott sor sorközét, ha egynél több van" | Text chunk span/underline layout | Only visual lines with secondary tag lanes reserve extra vertical space; unaffected lines stay normal height. | Widget test with mixed tagged/untagged lines and height/line metric assertion. | NOT DONE |
| TNEP-04 | User: "legyen bekezdés kezelés is" | Note document model, text chunk paragraph helpers | Single newline stays in paragraph; double newline starts a new paragraph; paragraph metadata exists separately from text. | Model/unit tests for boundaries, serialization, and edit remapping. | NOT DONE |
| TNEP-05 | User: prior "step in step out" and current paragraph handling | Paragraph metadata and rail/header actions | Step in/out changes paragraph level metadata for touched paragraphs without changing text length; visible per-paragraph indent is enabled only if a native-safe layout mechanism is proven. | Unit/widget tests assert text unchanged and metadata changed; implementation notes mark visual indent DONE or BLOCKED explicitly. | NOT DONE |
| TNEP-06 | User: "Google Keep szerű élmény", repeated selection failure | Text editor runtime | Editable surface has no outer gesture wrapper, no hidden text, no inline rail, no placeholder, no text-mutating indent. | Code inspection, negative `rg`, widget tests, Android manual long-press/handle-drag check. | NOT DONE |
| TNEP-07 | User: "kijelölés az egész textchunkot érintheti" | Text editor runtime | One native editable surface can select across the whole text chunk. | Widget test and Android manual selection check. | NOT DONE |
| TNEP-08 | User: table rail reference | Rail renderer/state | Rail visual behavior matches table/list rail: icon actions, two scroll rows, closable tag row, tag pills, style toggles. | Source comparison and rail payload tests. | NOT DONE |
| TNEP-09 | Prior failure analysis | Tests | Tests no longer rely only on programmatic `controller.selection`; manual/integration selection checks are documented. | Test review and manual checklist entry. | NOT DONE |
| TNEP-10 | Global AGENTS.md | Verification | No completion claim until checklist statuses are DONE or explicitly deferred. | Re-read checklist before final/build/push. | NOT DONE |
