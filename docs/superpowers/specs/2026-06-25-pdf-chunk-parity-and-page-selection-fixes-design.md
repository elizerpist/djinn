# PDF Chunk Parity And Page Selection Fixes Design

## Goal

Make PDF chunk lists and note chunk lists use the same central UI and UX contract, and make manual PDF selections behave as real PDF page regions instead of viewport overlays.

## Approved Scope

The user approved the central fix approach on 2026-06-25 with "ok" after reviewing the proposed design. This is a correction spec for regressions found after `2026-06-25-manual-pdf-chunk-flow-design.md`.

## Evidence

- Reference screenshot: `/storage/emulated/0/Pictures/Screenshots/Screenshot_20260625-111722.png`.
- The screenshot shows saved green source boxes extending beyond the PDF page into the gray viewer background. This proves the boxes are anchored to the viewport rather than the PDF page.
- Runtime logs show small selected rectangles still prefill with the full page text: `pdf text loaded page=1 chars=2423` followed by `prefill using pdf_text chars=2423`.
- `ExtractedKnowledgeScreen` uses `SharedChunkCard`, but passes PDF-specific behavior: `onLongPress: onValidate`, no drag handle, and a validation icon.
- Note chunk lists use `ReorderableListView.builder` with `ReorderableDragStartListener` and `Icons.drag_indicator`.
- Manual PDF chunks store `viewport_rect` in `sourceRectJson`; `SourceChunkBoxOverlay` reads that field and paints in full-viewer coordinates.
- `PdfViewerParams` supports `pageOverlaysBuilder`, which places widgets inside each rendered PDF page.
- `pdfrx` exposes `loadStructuredText()` with fragment and character rectangles in PDF page coordinates.

## Requirements Checklist

| ID | Source Instruction | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| PAR-01 | User: "a pdf chunklista nem úgy működik a jegyzet chunk lista, longtap nem dragot triggerel, hanem egy validáló menu jön fel" | `lib/src/knowledge/ui/extracted_knowledge_screen.dart`, shared chunk list/card code | Long-press/drag in the PDF chunk list reorders chunks like the note chunk list; it does not open validation. | Widget test long-presses a PDF chunk and verifies no `chunk-validation-card`; reorder changes displayed order. | DONE |
| PAR-02 | User: "ikonok sem ugyanazok ... centrális design ui és ux téren" | `lib/src/shared/chunks/`, `lib/src/notes/ui/note_chunk_card.dart`, `lib/src/knowledge/ui/extracted_knowledge_screen.dart` | Note and PDF chunk rows share the same card/list contract: drag handle position, icon set, tag action, expand icon, card tap to fullscreen editor, and preview layout. | Shared `SharedChunkCard` and `SharedChunkDragHandle`; extracted/note widget tests. | DONE |
| PAR-03 | User: "ha azt kérem hogy módosítsd a textchunk editor headerjét, akkor mindenhol módosulni fog" | `lib/src/notes/ui/note_chunk_editor_header.dart`, PDF editor route | PDF chunk editors continue to route into the existing note chunk editor screens and shared header. | Existing fullscreen PDF editor tests and source inspection of `PdfChunkEditorRoute`. | DONE |
| PAR-04 | User: "ne legyen kód duplikáció" | shared chunk list/card adapter files | Duplicated PDF-only chunk card layout and action wiring is removed or reduced to source-specific adapters. | PDF and note rows share `SharedChunkCard`; drag affordance shares `SharedChunkDragHandle`; PDF-specific validation action removed. | DONE |
| BOX-01 | User: "a boxok nem rögzülnek a pdf adott területére ... képernyőre rögzülnek" | `manual_chunk_editor_screen.dart`, `source_chunk_box_overlay.dart`, `pdf_viewer_screen.dart` | Manual and viewer source boxes are stored as normalized PDF page rects and painted inside `pageOverlaysBuilder`; boxes move with the PDF page and never extend into viewer background unless the source rect itself exceeds the page. | `source_chunk_rect_test.dart`, `pdf_viewer_source_box_overlay_test.dart`, manual save widget test, source inspection. | DONE |
| BOX-02 | User: "a pdf draggolható, nem csak scrollozható, mintha egy nagy canvas lenne" | manual PDF viewer params | Manual PDF viewer restricts interaction to vertical document scrolling and does not allow free canvas-like horizontal panning. | Source inspection: manual `PdfViewerParams` uses `panAxis: PanAxis.vertical` and `scaleEnabled: false`; analyzer passes. | DONE |
| OCR-01 | User: "az ocr nem a kért területet scrapeli. több szöveget rak bele" | manual PDF text extraction and OCR fallback | Prefill only includes text/OCR from the selected PDF page rect; full-page text is never used for a valid region selection. | `manual_pdf_region_text_test.dart`; source inspection of structured text filtering and crop OCR render path. | DONE |
| PERF-01 | Logs show repeated `viewer build pdf path=...` during drag | manual selection overlay | Dragging a selection updates only the page overlay selection state and does not rebuild the whole `PdfViewer.file` on every pointer move. | Source inspection: `_PageSelectionLayer` owns drag state locally; parent state updates only on selection completion. | DONE |
| COMPAT-01 | Existing chunks already contain `viewport_rect` | source rect parser | Legacy `viewport_rect` chunks remain readable as a fallback until migrated by edit/save. | `source_chunk_rect_test.dart` parses legacy and normalized rect JSON. | DONE |

## Architecture

### Shared Chunk List Contract

Introduce a shared list-level contract for chunk rows. `SharedChunkCard` remains the row surface, but list behavior must also be centralized. Notes and PDF chunks should both provide a shared row model that includes id, kind, title, status chips, preview body, expanded state, editor open action, tag action, and optional delete/source actions.

The shared list provides:

- `ReorderableListView.builder`;
- a left `ReorderableDragStartListener` with `Icons.drag_indicator`;
- the shared `SharedChunkCard`;
- identical expand/open action placement;
- source-specific trailing actions only when they do not change the common gesture contract.

PDF validation is not a long-press action in this list. If validation is still needed later, it must live outside the shared reorder gesture, for example in a detail/editor route or overflow menu.

### Persistent PDF Chunk Order

PDF chunks currently sort by page, source type, and id. That cannot support true note-like reorder. Add a focused repository reorder API for extracted chunk items:

```dart
Future<void> reorderExtractedKnowledgeItems(
  String documentPublicId,
  List<String> orderedItemIds,
);
```

ObjectBox storage should persist the order on `DocumentChunkEntity`. The in-memory repository should keep a matching order for tests. Existing data can default to the current page/type/id order until the user reorders it.

### Page-Anchored Source Rects

Replace new writes of `viewport_rect` with normalized top-left PDF page coordinates:

```json
{
  "source": "pdf_text",
  "created_by": "manual_chunk_editor",
  "page": 1,
  "page_rect_normalized": {
    "left": 0.10,
    "top": 0.20,
    "right": 0.70,
    "bottom": 0.32
  }
}
```

This coordinate space is independent of zoom, device size, and page scale. It converts to Flutter page overlay pixels for drawing, and to PDF point coordinates for structured text filtering and OCR crop rendering.

### Manual Selection Flow

Selection gestures should be handled by a per-page overlay returned from `pageOverlaysBuilder`, not by a full-screen overlay above the viewer. During selection, only the active PDF page accepts the drag. The overlay keeps drag state locally so pointer updates do not rebuild `ManualChunkEditorScreen` and `PdfViewer.file`.

PNG selection may keep the existing image-local path, but its stored rect should follow the same normalized-source-rect parser shape where practical.

### Region Text And OCR

For PDF text:

- call `page.loadStructuredText()`;
- convert the normalized source rect into PDF page coordinates;
- include fragments whose bounds overlap the selected rect;
- preserve document reading order by using the fragment order from `PdfPageText.fragments`;
- if the selected structured text is empty, fall back to OCR crop.

For OCR:

- render only the selected PDF sub-area using `PdfPage.render(x, y, width, height, fullWidth, fullHeight)`;
- run ML Kit OCR on the cropped temporary image;
- do not OCR the full page for a valid region selection.

### Viewer Interaction

Manual PDF chunking should not feel like a free canvas. Use `PdfViewerParams` to constrain panning to the vertical axis and disable scale gestures in the manual selection screen unless a later design explicitly reintroduces zoom controls.

## Testing Strategy

- Unit-test source rect serialization/parsing and legacy fallback.
- Unit-test normalized rect to PDF rect conversion and text fragment filtering.
- Widget-test PDF chunk list reorder behavior and absence of validation on long press.
- Widget-test shared note/PDF chunk list visuals through key/icon/action contracts.
- Widget-test manual save JSON contains `page_rect_normalized`, not only `viewport_rect`.
- Keep existing manual flow tests passing: sheet dismissal, save stays in viewer, source box visible after save.
- Run targeted Flutter tests and `flutter analyze` inside Ubuntu proot.

## Non-Goals

- Do not migrate notes and PDF chunks into one physical database table.
- Do not redesign all note editors.
- Do not remove existing validation infrastructure globally; only remove it from PDF chunk list long-press behavior.
- Do not run local Android APK builds in Termux.

## Verification Notes

- PASS: `flutter test test/source_chunk_rect_test.dart test/manual_pdf_region_text_test.dart test/pdf_viewer_source_box_overlay_test.dart test/extracted_knowledge_screen_test.dart test/knowledge_base_screen_test.dart test/knowledge_document_repository_test.dart test/note_chunk_card_test.dart` inside Ubuntu proot, 78 tests.
- PASS: targeted PDF reorder test verifies long press does not open validation and drag reorder persists through the repository.
- PASS: manual save widget test verifies saved metadata contains `page_rect_normalized` and not `viewport_rect`.
- PASS: `flutter analyze` inside Ubuntu proot, no issues.
- Local APK build was not run because Flutter APK builds must run through GitHub Actions in this Termux/Android environment.
