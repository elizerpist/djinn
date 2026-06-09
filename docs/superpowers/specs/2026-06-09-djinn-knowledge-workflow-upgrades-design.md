# Djinn Knowledge Workflow Upgrades Design

## Goal

Build a cost-aware, provider-flexible knowledge workflow for Djinn where PDFs are imported first, processed only by user action, reusable as portable training packs, enriched with flowchart validation, and usable through voice input and Android text-to-speech.

## Scope

This design covers the first working version of these features:

- Manual multi-PDF import with per-document status badge and per-document sync/chunk action.
- PDF fingerprinting and duplicate prevention.
- Sequential train queue with retry and cancel-between-documents behavior.
- Training export/import as a versioned `.djinnpack` JSON package.
- Flowchart extraction into ObjectBox flowchart/node/edge records, surfaced in validation.
- Provider-independent AI layer with OpenAI and Google Gemini clients.
- Google API key save/test and model/provider settings.
- Document-level RAG enable/disable.
- Knowledge collections with document assignment and chat-time collection filter.
- Citation jump from chat citations to a source page screen.
- OCR/preprocessing status warning for scanned/image-heavy PDFs.
- Android native voice-to-text.
- Android native text-to-speech for assistant answers.
- Admin/maintenance screen.
- Cost-control settings and debug logging.

## Non-Goals For This Pass

- Full background Android service processing after app close.
- Perfect geometric OCR reconstruction of every flowchart arrow.
- Cloud synchronization between devices.
- Full PDF editing or annotation.
- Accurate monetary billing estimation by provider tariff; v1 shows conservative warnings and request counts.

## Architecture

The current app has OpenAI-specific interfaces and an ObjectBox local knowledge store. The upgrade introduces a provider-neutral AI boundary while keeping ObjectBox as the local source of truth. UI screens stay Flutter-native and retain the current simple Material style.

The core split is:

- `AiClient`: provider-neutral extraction, embedding, answer, groundedness, key testing.
- `AiProvider`: enum/string setting for OpenAI or Gemini.
- `KnowledgeRepository`: document metadata, chunks, embeddings, flowcharts, collections, pack import/export.
- `KnowledgeBaseScreen`: import-only first; processing is user-triggered.
- `VoiceInputService` and `TextToSpeechService`: native Android speech and TTS adapters with test fakes.

## Data Model

`KnowledgeDocumentEntity` gains:

- `contentHash`: SHA-256 of the imported PDF bytes.
- `ragEnabled`: whether this document participates in retrieval.
- `collectionName`: user-facing collection label, default `Alap`.
- `ocrStatus`: `unknown`, `text_available`, `image_heavy`, `needs_ocr`.
- `trainedAtMillis`: nullable timestamp for completed train.
- `packVersion`: nullable pack schema version for imported packs.

Existing `FlowchartEntity`, `FlowchartNodeEntity`, `FlowchartEdgeEntity`, and `ChunkEmbeddingEntity` are reused. Flowchart node and edge embeddings use existing `sourceType` values `flowchart_node` and `flowchart_edge`.

## AI Provider Design

Create `lib/src/ai/ai_client.dart` with provider-neutral models:

- `AiExtractionResult`
- `AiExtractedChunk`
- `AiExtractedFlowchart`
- `AiExtractedFlowchartNode`
- `AiExtractedFlowchartEdge`
- `AiAnswer`
- `AiEvidence`
- `AiException`

OpenAI and Gemini clients both implement `AiClient`.

OpenAI uses current `/v1/responses` and `/v1/embeddings`. Gemini v1 uses the official Gemini REST endpoints:

- `generateContent` for answer and extraction.
- `embedContent` with `gemini-embedding-001` and `outputDimensionality` set to `3072`, matching the current ObjectBox HNSW vector index.

Gemini model defaults:

- Answer: `gemini-2.5-flash`
- Extraction: `gemini-2.5-flash`
- Groundedness: `gemini-2.5-flash`
- Embedding: `gemini-embedding-001`

OpenAI defaults remain the existing settings unless changed.

## Flowchart Extraction

The extraction JSON schema expands from only `chunks` to:

- `chunks`
- `flowcharts`
  - `id`
  - `page_number`
  - `title`
  - `confidence`
  - `nodes`
  - `edges`

The prompt requires conservative extraction: create flowchart records only when boxes/arrows are visible or explicitly described. Every extracted flowchart is saved with `ValidationState.unreviewed`; document state becomes `needs_review` after text chunks and embeddings are saved.

Flowchart nodes and edges also get embeddings, so they can appear in RAG retrieval before validation with warning labels. Rejected nodes/edges remain excluded by the existing retriever logic.

## Knowledge Workflow

PDF import no longer starts AI processing automatically. Imported PDFs immediately appear in the list as local documents. Each row shows:

- filename
- size
- collection
- RAG enabled/off
- OCR/preprocessing badge
- processing status badge
- sync/chunk button
- retry on failed/blocked states
- export action when ready

The user decides which PDFs to chunk. A selected-documents action processes multiple documents sequentially. V1 cancel stops the queue after the current document finishes.

## Fingerprint And Duplicate Prevention

During import, Djinn computes a SHA-256 hash. If a document with the same hash already exists, the app does not create a duplicate. It logs `[Knowledge] duplicate skipped hash=... filename=...` and shows a short duplicate status message.

## Training Pack Export/Import

V1 `.djinnpack` is a UTF-8 JSON file with this shape:

```json
{
  "schema_version": 1,
  "app": "djinn",
  "exported_at": "2026-06-09T00:00:00.000Z",
  "documents": [
    {
      "filename": "stroke.pdf",
      "content_hash": "sha256...",
      "size_bytes": 123,
      "collection_name": "Stroke",
      "rag_enabled": true,
      "ocr_status": "text_available",
      "chunks": [],
      "embeddings": [],
      "flowcharts": []
    }
  ]
}
```

Import creates or updates documents by `content_hash`. It restores chunks, embeddings, flowcharts, validation states, collection and RAG flags without making AI calls.

## Chat And Retrieval

Retrieval excludes chunks from documents where `ragEnabled == false`. Chat screen gains a collection filter. `Minden gyűjtemény` searches all enabled documents; a named collection searches only that collection.

Citation chips open a source page screen. V1 shows filename, page number, source type, excerpt, and a button to open the PDF with the platform when available. If a PDF viewer package is added in implementation, the same screen hosts the viewer and jumps to the page.

## Voice Input

Use Android native speech recognition via the Flutter `speech_to_text` package. Required Android changes:

- `android.permission.RECORD_AUDIO`
- `android.permission.INTERNET`
- query for `android.speech.RecognitionService`

Chat composer gets a microphone icon. The service listens in `hu-HU`, writes partial/final transcript into the input, and logs start/stop/error events.

## Text-To-Speech

Use Android native TTS via `flutter_tts`. Assistant messages get play, pause and stop controls. Defaults:

- language `hu-HU`
- speech rate `0.5`
- pitch `1.0`

If Hungarian is unavailable, the UI shows an error and logs `[TTS] language unavailable hu-HU`.
The Android manifest also declares a `android.intent.action.TTS_SERVICE` query so package visibility does not block TTS discovery.

## Settings

Settings adds:

- AI provider: OpenAI or Gemini.
- OpenAI API key.
- Google API key.
- Provider key tests.
- Provider-specific model fields.
- Paid AI allowed switch.
- Confirmation before AI processing switch.
- Voice language.
- TTS language/rate/pitch.

Keys remain in `flutter_secure_storage`.

## Admin/Maintenance

Drawer adds `Admin`. V1 admin screen includes:

- training pack export/import entry points
- clear imported documents/chunks action with confirmation
- rebuild embeddings action for ready documents
- knowledge database summary
- debug log copy remains in the debug panel

## Debug Logging

Add logs for:

- import/fingerprint/duplicate
- queue start/stop/cancel
- provider selected
- Gemini key test and request errors
- flowchart extraction count
- pack export/import counts
- RAG skip because disabled document
- voice start/stop/transcript/error
- TTS start/pause/stop/error
- admin destructive operations

## Testing Strategy

Use TDD. Each feature slice starts with failing tests:

- repository import duplicate by hash
- import does not auto-process
- per-document sync triggers processing
- queue processes selected docs sequentially and cancel stops after current
- pack export/import restores chunks and embeddings without AI calls
- provider selection routes to OpenAI/Gemini clients
- Gemini HTTP client parses JSON answer/extraction/embedding
- flowchart extraction saves unreviewed flowchart records and marks document `needs_review`
- retriever skips RAG-disabled documents
- collection filter limits retrieval
- citation chip opens source page
- voice service writes transcript into composer
- TTS controls call service and log state
- admin clear action requires confirmation

## Release Flow

No local APK build on Termux. After tests pass locally:

1. Commit implementation.
2. Push `feature/knowledge-workflow-upgrades`.
3. Run one GitHub Actions Android debug build.
4. Verify `debug-latest` release asset.
5. Report the direct APK link.
