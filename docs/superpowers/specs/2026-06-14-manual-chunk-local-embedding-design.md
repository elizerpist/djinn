# Manual Chunk Editor, Grouped Extraction, and Local Embedding Design

## Goal

Djinn must let the user inspect and correct extracted knowledge without API cost: local chunking should produce useful clinical blocks, extracted content should be grouped by content type, manual chunking should happen directly from a full-screen PDF selection workflow, and offline indexing should be selectable from settings.

## Current Problems

- `Kinyert chunkok` uses the subheader/tab area for `AI / Lokalis / Manualis / Osszehasonlitas`, so the earlier type grouping (`szoveg`, `tablazat`, `flowchart`, etc.) disappeared.
- The local chunk builder emits one chunk per OCR line, so headings and isolated words become unusable chunks.
- Local OCR reads flowcharts as plain text instead of preserving them as flowchart candidates for audit.
- Manual chunking is a form-only screen, not a PDF selection workflow.
- Offline embedding/indexing choices are not surfaced in settings, and the current ObjectBox vector field is fixed at 3072 dimensions for AI embeddings.

## Decisions

### Extracted Knowledge Navigation

The header owns the pipeline mode. The app bar gets a three-dot menu with:

- `AI chunkok`
- `Lokalis chunkok`
- `Manualis chunkok`
- `Osszehasonlitas`

The subheader owns content type grouping inside the selected pipeline:

- `Osszes`
- `Szoveg`
- `Felsorolas`
- `Tablazat`
- `Score`
- `Flowchart`
- `Kep`
- `Vizualis teny`

Each pipeline mode has its own grouped view. Comparison remains its own mode and can show grouped summary rows later, but it does not replace type grouping in normal pipeline views.

### Local Chunk Builder

Local chunks are block-based, not line-based.

Rules:

- A heading is metadata, never a standalone chunk.
- Very short text lines are buffered into the following block.
- Paragraphs continue until a heading, table-like block, list block, or page boundary with no continuation cue.
- Lists stay together with their section title, including when they continue on the next page.
- Tables and score blocks stay as table/score chunks.
- A chunk below the minimum useful length is merged forward when possible.
- Every generated chunk gets a `groupId` concept encoded in source metadata first, so the UI and retrieval can later prioritize logically related chunks without immediately changing ObjectBox schema.

### Flowchart From Local OCR

Local OCR may produce text for a diagram, but that text should not be treated only as normal text. The local builder should detect flowchart-like OCR blocks using cues such as branch labels, arrows, repeated short box labels, and flowchart keywords. These blocks become `LocalChunkKind.flowchart` and keep page/source metadata. Full node/edge structure remains audit work; no fake arrows should be invented.

### Manual Chunk Editor

The manual editor opens as a full-screen PDF viewer.

Workflow:

1. User opens `Kezi chunkolas` for a PDF.
2. PDF is shown full screen.
3. A selection FAB starts region selection.
4. User draws a rectangle over text, table, score, flowchart, or image region.
5. A slide-in bottom card opens with:
   - selected page,
   - selected content type,
   - title/section field,
   - editable extracted text,
   - source mode,
   - save button.
6. Saving appends a `manual` pipeline chunk and returns the user to the PDF with the selection visible until dismissed.

The first implementation may use the page text/OCR already available for the page and persist the selected rectangle metadata. It must still be a real save flow, not a placeholder.

### Offline Embedding and Search Modes

Settings must expose selectable local/offline indexing options:

- `MediaPipe Text Embedder / LiteRT`
- `ONNX multilingual embedding`, recommended first real model family: multilingual E5
- `LiteRT + EmbeddingGemma`
- `Csak kulcsszo / BM25 / regex`

The current AI vector index remains 3072-dimensional. Local embedding choices must not be forced into that index. The first implementation must provide a working offline keyword/BM25-style index path and persist enough mode metadata for the embedding engines to be wired without UI redesign. If a heavy local model asset is not bundled yet, the app must say `Modell nincs telepitve` instead of pretending semantic local embedding exists.

Chunk states shown in the UI:

- `Kinyerve`: chunk exists, searchable by keyword/BM25/regex.
- `Indexelve`: chunk has an index for the selected indexing mode.
- `Auditalt + indexelt`: preferred retrieval source.

## Retrieval Rule

RAG should prefer `Auditalt + indexelt`, then `Indexelt`, then `Kinyerve` keyword matches. Local keyword/BM25 results can supplement vector retrieval but must remain source-bounded.

## Non-Goals For This Increment

- No fake semantic vectors.
- No full native ONNX/MediaPipe/EmbeddingGemma model bundle unless the required model asset is available in the repository.
- No destructive rewrite of the working AI chunking pipeline.
- No removal of the existing flowchart hierarchy views.
