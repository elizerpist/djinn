Scope: restore inline range tag visuals for the plain native text chunk editor.

| ID | Source | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TCTV-01 | User: "az első tag mindig a szöveg hátterét színezi" | `lib/src/notes/ui/tagged_text_visual.dart`, `note_text_chunk_editor_screen.dart` | For a tagged text range, the first resolved tag paints only the selected text range background with that tag color and does not mutate the controller text. | PARTIAL: tests added and code implemented; local Flutter runtime is blocked by ARM64 TLS alignment, CI verification pending. | PARTIAL |
| TCTV-02 | User: "minden további tag egy újabb underline, a tag színével" | `tagged_text_visual.dart`, text editor underline layer | Every secondary resolved tag contributes one separate underline color for the same text range. | PARTIAL: tests added and code implemented; local Flutter runtime is blocked by ARM64 TLS alignment, CI verification pending. | PARTIAL |
| TCTV-03 | User: prior requirement "ha sok aláhúzás van, az tolja lejjebb..." | Tagged text span style / underline layout | Tagged spans with secondary underlines reserve extra line height so underline stacks do not print over the next line. | PARTIAL: span height expands for secondary underline count; local Flutter runtime is blocked by ARM64 TLS alignment, CI verification pending. | PARTIAL |
| TCTV-04 | User: repeated native-selection constraint | Text editor surface | Inline visuals are paint/style only: no `WidgetSpan`, no placeholder text, no inserted hidden characters, and the editor remains one stock `TextField`. | PARTIAL: code inspection and old-symbol scan are clean; widget-test/CI verification pending. | PARTIAL |

## Verification Notes

- RED attempt: local `flutter test test/tagged_text_visual_test.dart test/note_text_chunk_editor_screen_test.dart` could not execute because both local Flutter SDKs fail before compiling tests with Dart ARM64 Bionic TLS alignment error.
- Static/code checks completed locally: `git diff --check` passed; old-symbol scan returned no hits for `WidgetSpan`, `rail-line-*`, `placeholderDelta`, deleted native rail bridge/runtime files, or old TextChunk controllers in `lib`, `android`, and `test`.
