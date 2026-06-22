Scope: make text chunk tag-count corner markers temporarily user-selectable for testing.

| ID | Source | Intended code area | Acceptance condition | Verification method | Status |
| --- | --- | --- | --- | --- | --- |
| TCCO-01 | User: "mindkettőt belerakod" referring to visual options 28 and 30 | `lib/src/notes/ui/note_text_chunk_editor_screen.dart`, `tagged_text_visual.dart` | Both right-corner count overlay modes exist: fixed PDF-like corner badge and adaptive/clamped badge. | DONE: `NoteTaggedTextCountMarkerMode.fixedCorner` and `.adaptiveClamp`; CI run `27970182493` passed. | DONE |
| TCCO-02 | User: "átmenetileg user selectable lesz" | Text chunk editor state | The selected marker mode can be switched at runtime for the current text chunk editor session. | DONE: local editor state and widget test; CI run `27970182493` passed. | DONE |
| TCCO-03 | User: "a textchunk dropdown menujében lehet kiválasztani melyik" | `NoteChunkEditorHeader.extraMenuItems` integration | The text chunk overflow/dropdown menu contains both count marker mode choices. | DONE: menu item keys `note-text-menu-count-marker-fixed` and `note-text-menu-count-marker-adaptive`; CI run `27970182493` passed. | DONE |
| TCCO-04 | Prior repeated native-selection constraint | Native text editor surface | Count badges are paint/overlay only; the editor remains a single native `TextField`, controller text is unchanged, and no `WidgetSpan`/placeholder/inserted marker is used. | DONE: `git diff --check` passed; bad-symbol scan found no `WidgetSpan`, `PlaceholderSpan`, placeholder, or `rail-line` additions; CI run `27970182493` passed. | DONE |
| TCCO-05 | User wants to compare 28 vs 30 separately | Visual marker semantics | Mode 28 renders a full fixed `N+` badge. Mode 30 renders adaptive/clamped marker content (`N+`, `+`, or dot based on range width). | DONE: unit test covers label rules; CI run `27970182493` passed. | DONE |

## Verification Notes

- RED/GREEN local Flutter execution is blocked in Termux: both local SDKs abort before compiling tests with Dart ARM64 Bionic TLS alignment error.
- Static local checks completed: `git diff --check` passed; bad-symbol scan found no `WidgetSpan`, `PlaceholderSpan`, placeholder, or `rail-line` additions in the touched textchunk files.
- GitHub Actions Android native build run `27970182493` passed: backend tests, `flutter analyze`, Flutter tests, debug APK build, and latest debug APK publish.
