Scope: fix the text chunk range tag visual regression shown in
`/storage/emulated/0/Pictures/Screenshots/Screenshot_20260622-140602.png`.

| ID | Source instruction / reference | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TCVD-01 | User: "nem jó a tag színezés" and screenshot `Screenshot_20260622-140602.png` | `lib/src/notes/ui/tagged_text_visual.dart` | The first resolved range tag colors only the text background through the native text span and does not change the controller plain text. | DONE: CI widget/unit tests inspect `TextSpan.toPlainText`, background color, and controller text. | DONE |
| TCVD-02 | User: "el van az underline tolva" and screenshot `Screenshot_20260622-140602.png` | `tagged_text_visual.dart`, `note_text_chunk_editor_screen.dart` | Secondary underlines use the active native `RenderEditable` selection boxes, not a second independent `TextPainter` layout. | DONE: CI widget test inspects the underline painter receives a non-null `RenderEditable`; code inspection verifies `getBoxesForSelection` path. | DONE |
| TCVD-03 | User: "az underline nem expandálja a sorközt" | Tagged text span height and underline painter | Multiple secondary underlines reserve enough line height inside the actual native text span so the following content is pushed down. | PARTIAL: CI unit test asserts multi-underline span height is substantially above normal line height; Android screenshot confirmation is still needed. | PARTIAL |
| TCVD-04 | User: "a bekezdéskezelés sem működik" and earlier paragraph rules | `note_text_chunk_editor_screen.dart` paragraph helpers/render path | Double newline separates paragraphs; step in/out affects all touched paragraph metadata without mutating text. Visible per-paragraph left margin is only DONE if a native-safe render path exists. | Widget tests for paragraph ranges, metadata, unchanged text, plus debug log. Visual margin remains BLOCKED with a single stock `TextField` unless architecture changes. | PARTIAL |
| TCVD-05 | User: "nincsneek debug logok, hogy segítsek" | `note_text_chunk_editor_screen.dart` | Text changes, tag visual geometry, and paragraph step operations emit actionable `DebugConsole` logs. | DONE: CI widget tests inspect `[TextChunkNative]`, `[TextChunkVisual]`, and `[TextChunkParagraph]` logs. | DONE |
| TCVD-06 | User log 14:55:04 shows `runs=[112-118/u2]` but "underline nem húzza szét a sorközt" | `tagged_text_visual.dart`, `note_text_chunk_editor_screen.dart` | Secondary underline count drives a native-safe `TextField.strutStyle` minimum line height; controller plain text is unchanged and no placeholders are inserted. | PARTIAL: widget test now asserts dynamic strut height; CI still needs to execute because local Flutter aborts before compiling on Termux. | PARTIAL |
| TCVD-07 | User log 14:54:48 shows `[TextChunkParagraph] ... styles=[0-168/l1] textUnchanged=true` but "bekezdés step left right sem működik" | `note_text_chunk_editor_screen.dart` | Paragraph step state is consumed by the editor layout as a visible left inset while keeping the right edge fixed and leaving `block.text` unchanged. | PARTIAL: widget test now asserts TextField x-position changes after indent and returns after outdent; CI still needs to execute. | PARTIAL |

Root cause notes:

- The screenshot shows the first tag background coming from the native text span, while the secondary underlines are painted by a separate overlay using a separate `TextPainter`. That can drift from the real `EditableText` layout and cannot be trusted for handle/scroll/line-height geometry.
- `paragraphStyles` currently persists metadata but a single stock Flutter `TextField` has no per-paragraph left-margin API. Visual paragraph indentation needs a separate render strategy or explicit text mutation; text mutation was rejected because it harms native selection and plain text.
- The 14:54-14:55 Android log narrows the remaining issue: range-tag runs and paragraph metadata both exist, but the native edit surface does not consume them as layout-affecting inputs.

Verification notes:

- Local RED/GREEN Flutter execution is blocked in Termux: `/data/data/com.termux/files/home/flutter/bin/flutter test ...` aborts before compiling with Dart ARM64 Bionic TLS alignment error.
- Local static checks run: `git diff --check` passed; old hidden placeholder/rail symbol scan returned no hits.
- GitHub Actions `27952545764` passed: backend tests, `flutter analyze`, full `flutter test`, debug APK build, and `debug-latest` release publication.
- The first CI attempt `27952248849` failed only because the new debug log test expected `ranges=0`; the fixture intentionally retained one valid range tag after text edit, so the test was corrected to `ranges=1`.
