# Text Chunk Native Editor, Rail, Tags, Underlines, and Paragraphs

Date: 2026-06-22

## Context

The current text chunk editor was rewritten once, but it still does not deliver a Google Keep-like native text selection experience. The remaining problem is architectural: native selection is mixed with custom wrapper gestures, custom scroll/layout layers, and paragraph indentation that mutates the text string.

The next implementation must restart the text chunk runtime again, but preserve the useful parts:

- native text selection;
- keyboard-anchored rail;
- table/list rail visual language;
- range tag coloring;
- secondary underline lanes;
- paragraph handling.

## Non-Negotiable Requirements

1. Native text selection must remain the primary interaction model.
   The editor must not wrap the editable surface in custom gesture layers that compete with long press, selection handle drag, or native toolbar behavior.

2. The editable text string must stay semantically clean.
   Paragraph indent, rail spacing, underline spacing, or visual layout must never insert spaces, newlines, placeholders, widget spans, or hidden markers into the text.

3. The rail must remain.
   It must use the table/list rail visual contract: icon actions, two horizontally scrollable rows, closable tag row, white/grey modes, border/rounded controls, and tag pills.

4. Tag coloring must remain.
   The primary tag should be shown through normal text span styling only.

5. Secondary underlines must affect line spacing.
   If a visual line contains text with more than one tag lane, only that line reserves enough vertical room for the underline lanes. Lines without secondary underlines remain normal height.

6. Paragraph handling must exist without mutating text.
   Single enter remains inside the same paragraph. Double enter starts a new paragraph. Step in/out changes paragraph metadata, not the text contents.

7. Selection can span the whole text chunk.
   Paragraph handling must not split the editor into multiple independent text fields if that would break whole-chunk native selection.

## Design

### Editor Surface

Replace the current text chunk runtime with one minimal native editing surface:

- one controller;
- one focus node;
- one editable text surface;
- no outer `GestureDetector` around the editable surface;
- no editor-owned `SingleChildScrollView` around the editable surface unless Flutter's own editable scroll behavior is insufficient;
- no stack overlay that participates in hit testing;
- no hidden placeholder text.

Use `EditableText` directly, because the screen needs explicit selection callbacks and a controller that builds tagged spans. Keep it minimal and let Flutter's native editable machinery own selection, handles, composing, toolbar, and scrolling behavior.

### Range Tags and Primary Highlight

Range tags remain stored in `NoteBlock.rangeTags`.

The text controller builds styled `TextSpan`s from real text offsets:

- no `WidgetSpan`;
- no replacement characters;
- no offset remapping;
- no synthetic text.

Primary tag color is applied as a background color with the same visual semantics used by table/list tag styling.

### Secondary Underline Line Height

Secondary tag lanes are visual only, but they must reserve vertical space.

The line-height calculation must be based on affected text ranges, not global editor state:

- a line with zero or one tag lane uses normal text height;
- a line with two tags reserves one underline lane;
- a line with three tags reserves two underline lanes;
- and so on.

Because Flutter text layout computes line metrics from spans, the controller should apply adjusted span height only to ranges that carry secondary lanes. An `IgnorePointer` painter may draw the underline lanes, but it must not be responsible for hit testing or text offset mapping.

If exact per-visual-line height cannot be achieved with plain spans, the implementation must stop and report the limitation before introducing custom text layout.

### Paragraph Model

Add paragraph metadata instead of encoding indentation in text.

Proposed model:

```dart
class NoteTextParagraphStyle {
  const NoteTextParagraphStyle({
    required this.id,
    required this.start,
    required this.end,
    this.level = 0,
  });
}
```

This can live as `NoteBlock.paragraphStyles` or equivalent focused metadata. It is only relevant for heading/paragraph text chunks.

Paragraph boundaries are derived from text:

- a single newline is a line break inside the same paragraph;
- two or more consecutive newlines split paragraphs;
- empty paragraph separators are not assigned editable synthetic content.

When text changes, paragraph styles are remapped by text edits similarly to range tags. Styles with invalid or empty ranges are dropped or normalized.

### Step In / Step Out

Step in/out changes the paragraph style level for the paragraph containing the current selection start or collapsed cursor.

Rules:

- selection inside one paragraph changes that paragraph;
- selection spanning multiple paragraphs changes all touched paragraphs;
- level clamps to a small range, initially `0..8`;
- text length must not change;
- selection offsets must remain valid.

The visual indent must be applied outside the text string. If stock Flutter editable text does not expose a native-safe per-paragraph left-margin mechanism, the implementation must keep paragraph metadata and mark visual per-paragraph indent as blocked instead of faking it with spaces, widget spans, or a custom canvas editor.

## Known Constraint

Flutter's stock single `EditableText` supports styled spans and line height, but it does not obviously expose per-paragraph left margins in the public text-span API. This is the main risk for paragraph step in/out.

The implementation sequence must therefore prove the native-safe paragraph layout mechanism before enabling visible per-paragraph step in/out. If no such mechanism exists, paragraph handling still includes boundary detection, metadata, serialization, and edit remapping, but step in/out must not mutate text and must not be presented as complete.

### Rail Behavior

The rail stays keyboard-anchored and uses the table/list visual behavior.

Visible when:

- a non-collapsed native text selection exists;
- or the collapsed cursor is inside an existing tagged range.

Hidden when:

- the user is typing in untagged text;
- selection is invalid;
- the editor loses focus and there is no actionable selected/tagged range.

Rail actions:

- tag selection;
- clear selected tags;
- previous/next tagged range;
- step out / step in;
- rounded/grey/border style toggles;
- tag row collapse/expand;
- delete individual tag from the tag row.

The rail must not be inserted into the text layout. It is outside the editable surface.

## Files To Delete Or Replace

Delete or replace:

- `lib/src/notes/ui/text_chunk/`
- text editing/runtime sections of `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- paragraph step text mutation logic
- current text chunk tests that only set `controller.selection` programmatically

Keep and reuse:

- `NoteTextRangeTag`;
- `NoteSelectionActionRail` visual contract;
- tag manager sheet;
- native rail bridge transport if it remains the cleanest keyboard anchor;
- table/list rail design behavior.

## Testing Strategy

Tests must cover behavior that previously slipped through:

- text remains unchanged after step in/out except paragraph metadata;
- paragraph metadata serializes and deserializes;
- single newline stays in the same paragraph;
- double newline creates separate paragraphs;
- whole text chunk selection is possible in the widget tree;
- range tag highlight uses text spans without placeholders;
- secondary underline lanes increase affected text height;
- untagged typing does not show the rail;
- selected text and collapsed cursor inside tagged text show the rail;
- no `rail-line-*`, hidden spacer, placeholder, or text length delta appears.

Widget tests are not enough for manual gesture fidelity, because previous tests only set `controller.selection` directly. Add at least one integration-style or manual-verification checklist item for long press and selection handle drag on Android.

## Out Of Scope

- Custom canvas text editor.
- Splitting one text chunk into one field per paragraph if that breaks whole-chunk selection.
- Reintroducing text-based indentation with spaces.
- Reintroducing inline rail insertion.
- Rebuilding table/list rail.
