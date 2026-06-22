Scope: fix the text chunk range tag visual regression shown in
`/storage/emulated/0/Pictures/Screenshots/Screenshot_20260622-140602.png`.

| ID | Source instruction / reference | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TCVD-01 | User: "nem jó a tag színezés" and screenshot `Screenshot_20260622-140602.png` | `lib/src/notes/ui/tagged_text_visual.dart` | The first resolved range tag colors only the text background through the native text span and does not change the controller plain text. | Widget/unit tests inspect `TextSpan.toPlainText`, background color, and controller text. | PARTIAL |
| TCVD-02 | User: "el van az underline tolva" and screenshot `Screenshot_20260622-140602.png` | `tagged_text_visual.dart`, `note_text_chunk_editor_screen.dart` | Secondary underlines use the active native `RenderEditable` selection boxes, not a second independent `TextPainter` layout. | Widget test inspects the underline painter receives a non-null `RenderEditable`; code inspection verifies `getBoxesForSelection` path. | PARTIAL |
| TCVD-03 | User: "az underline nem expandálja a sorközt" | Tagged text span height and underline painter | Multiple secondary underlines reserve enough line height inside the actual native text span so the following content is pushed down. | Unit test asserts multi-underline span height is substantially above normal line height; widget/screenshot evidence required before final DONE. | PARTIAL |
| TCVD-04 | User: "a bekezdéskezelés sem működik" and earlier paragraph rules | `note_text_chunk_editor_screen.dart` paragraph helpers/render path | Double newline separates paragraphs; step in/out affects all touched paragraph metadata without mutating text. Visible per-paragraph left margin is only DONE if a native-safe render path exists. | Widget tests for paragraph ranges, metadata, unchanged text, plus debug log. Visual margin remains BLOCKED with a single stock `TextField` unless architecture changes. | PARTIAL |
| TCVD-05 | User: "nincsneek debug logok, hogy segítsek" | `note_text_chunk_editor_screen.dart` | Text changes, tag visual geometry, and paragraph step operations emit actionable `DebugConsole` logs. | Widget tests inspect `[TextChunkNative]`, `[TextChunkVisual]`, and `[TextChunkParagraph]` logs. | PARTIAL |

Root cause notes:

- The screenshot shows the first tag background coming from the native text span, while the secondary underlines are painted by a separate overlay using a separate `TextPainter`. That can drift from the real `EditableText` layout and cannot be trusted for handle/scroll/line-height geometry.
- `paragraphStyles` currently persists metadata but a single stock Flutter `TextField` has no per-paragraph left-margin API. Visual paragraph indentation needs a separate render strategy or explicit text mutation; text mutation was rejected because it harms native selection and plain text.

Verification notes:

- Local RED/GREEN Flutter execution is blocked in Termux: `/data/data/com.termux/files/home/flutter/bin/flutter test ...` aborts before compiling with Dart ARM64 Bionic TLS alignment error.
- Local static checks run: `git diff --check` passed; old hidden placeholder/rail symbol scan returned no hits.
