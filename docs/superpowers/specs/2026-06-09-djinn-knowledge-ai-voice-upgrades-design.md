# Djinn Knowledge, AI Settings, And Voice Upgrades Design

Date: 2026-06-09

## Goal

Upgrade Djinn from the current working knowledge/RAG prototype into a more
durable daily-use Android app for document-heavy workflows. The app must let
the user import many PDFs without immediate AI cost, organize them into folders,
open them in-app, manually choose what gets chunked, reuse/export processed
knowledge, configure OpenAI or Gemini from structured settings, and use voice in
a conversational loop.

This design also fixes the observed runtime failures:

- OpenAI/Gemini key state can be saved but training still reports
  `missing_api_key`.
- Gemini Flash/Flash Lite can return malformed or invalid structured output.
- Gemini can fail with quota/prepay, high demand, connection abort, or schema
  validation errors.
- STT timeouts and empty interim results currently look like app failures.
- TTS can be started repeatedly instead of behaving like one controlled player.
- Flowcharts detected in PDFs do not reliably appear in the validation queue.

## User-Visible Success Criteria

1. Imported PDFs appear immediately in the knowledge base and do not auto-run
   paid AI processing.
2. Every PDF has compact status badges and can be opened with a single tap in an
   in-app PDF viewer.
3. Long tap enters Android-file-manager-style selection mode: all rows show
   checkboxes, the header changes, and selected PDFs define the batch.
4. The three-dot menus are overlays above the PDF list; they do not push the
   list down or leave blank space.
5. The user can create folders and move PDFs between folders.
6. AI settings are grouped into one AI block with OpenAI/Gemini pills, API key
   controls, and four provider-specific model dropdowns.
7. Settings auto-save. There is no manual save button and no duplicate
   "use Gemini" switch.
8. Gemini extraction uses structured output and invalid responses produce a
   retryable, understandable state instead of an unhandled `FormatException`.
9. Voice supports push-to-talk and conversational STT -> RAG/chat -> TTS loops.
10. Debug logs identify provider, model, document, attempt, and exact blocked or
    retryable reason without exposing API keys.

## Scope

In scope:

- Knowledge-base UI redesign and selection-mode behavior.
- In-app PDF viewer entry point from the knowledge list.
- Folder metadata and move operations for documents.
- Manual sync/chunk queue for one or more selected PDFs.
- Chunk export/import for avoiding repeated API cost.
- AI settings redesign for OpenAI and Gemini.
- Provider-aware key/model resolution and error classification.
- Gemini structured output parsing and validation hardening.
- STT/TTS conversational controls and debug logs.
- Flowchart validation queue reliability.
- Offline non-LLM fallback design hooks, with minimal implementation only if it
  does not destabilize the main work.

Out of scope for the first implementation plan:

- Full offline answer generation.
- Cloud account sync.
- OpenAI-hosted vector store migration.
- PDF annotation editing.
- Clinical validation.

## Knowledge UI Design

The knowledge screen follows the Android file manager interaction model.

### Normal Mode

- Header title: `Tudastar`.
- Header subtitle summarizes corpus state, for example:
  `24 PDF · 12 RAG-ban · 3 syncre var`.
- Header actions:
  - search;
  - sort/filter;
  - three-dot general menu.
- Folder chips appear under the header:
  - `Osszes`;
  - user folders such as `Eljarasrendek`, `Igazgatoi utasitasok`,
    `Kulso guidelineok`.
- PDF rows are compact:
  - filename clamped to one or two lines;
  - folder/page/OCR metadata;
  - status badges;
  - row three-dot menu.
- Single tap opens the PDF in an in-app viewer.
- Long tap enters selection mode.

The normal three-dot menu is a floating overlay. It contains general operations:

- select all;
- sort;
- create folder;
- chunk package import;
- knowledge export.

The menu must be rendered as an overlay above the list, not as a layout element.
Opening it must not move PDF rows or create blank space.

### Selection Mode

Long tap on a PDF enters selection mode:

- every row shows a checkbox;
- the long-tapped row is selected;
- the header changes to selection mode.

Selection header:

- left: `X` to exit selection mode;
- center: `N kijelolve` plus a compact summary, for example
  `86 oldal · 2 syncre var · 1 mar RAG-ban`;
- right:
  - send/sync selected;
  - delete selected;
  - three-dot selected-menu overlay.

The selected three-dot overlay contains document/knowledge operations:

- enable/disable RAG for selected;
- move to folder;
- export chunk package;
- refresh embeddings;
- send flowcharts to validation;
- update offline index.

The overlay follows the same rule as normal mode: it floats over the PDF rows
and closes on outside tap or Android back.

### In-App PDF Viewer

Single tap opens an in-app PDF viewer rather than an external file intent.

Minimum viewer behavior:

- back navigation returns to the knowledge list with scroll/selection state
  preserved when practical;
- page navigation and zoom are available through the selected PDF package;
- document title and current page are visible;
- the viewer is read-only in this iteration.

Later viewer extensions can include page-to-RAG actions and selected excerpt
actions, but those are not required in this first implementation.

## Knowledge Workflow

Importing PDFs creates local documents immediately:

1. User imports one or more PDFs.
2. The app copies them into app-private storage.
3. A document hash is computed.
4. The document appears in the knowledge list with initial status badges.
5. No AI processing starts unless the user explicitly sends/syncs a document.

Document statuses must be visible and machine-readable:

- imported;
- text available;
- OCR needed;
- not synced;
- queued;
- chunking;
- embedded;
- failed;
- disabled for RAG.

Manual sync sends selected documents into the processing queue. If paid AI is
disabled or the active provider lacks a key, the queue does not start and the
blocked reason is shown in the UI and debug log.

Processing must be idempotent by document hash and chunk package metadata so the
same PDF does not need to be re-chunked on every app version.

## Folder Model

Folders are metadata containers inside the knowledge base, not filesystem
directories exposed to the user.

Minimum operations:

- create folder;
- rename folder;
- delete folder without deleting documents;
- move selected documents to a folder;
- filter the knowledge list by folder.

The initial default folder can be `Osszes` plus no-folder/unfiled state. Example
user folders are:

- `Eljarasrendek`;
- `Igazgatoi utasitasok`;
- `Kulso guidelineok`;
- `Oktatasi anyagok`;
- `Sajat jegyzetek`.

Folder scope may later be used as a RAG filter.

## Chunk Export And Import

Chunk export/import reduces repeated API cost while testing many app builds.

An export package contains:

- package schema version;
- document hash;
- original filename and document metadata;
- provider and model metadata;
- embedding model and vector dimension;
- chunks;
- embeddings;
- flowchart extraction records when available;
- validation state when compatible.

Import rules:

- document hash must match if attaching to an existing PDF;
- vector dimension must match the active local vector index;
- embedding model mismatch must be surfaced before import;
- incompatible schema versions are rejected with a clear message;
- imported chunks become searchable without new API calls.

OpenAI or Gemini provider storage is not the primary persistence layer for this
feature. The app's local ObjectBox knowledge store remains the source of truth.

## AI Settings Design

Settings are reorganized into four blocks:

1. AI
2. Beszed
3. Mukodesi mod
4. Validalas

### AI Block

The AI block starts with an OpenAI/Gemini segmented pill selector.

When OpenAI is active:

- OpenAI API key input;
- OpenAI key test;
- answer model dropdown;
- PDF processing model dropdown;
- groundedness model dropdown;
- embedding model dropdown.

When Gemini is active:

- Google/Gemini API key input;
- Google/Gemini key test;
- answer model dropdown;
- PDF processing model dropdown;
- groundedness model dropdown;
- embedding model dropdown or a disabled row if the provider cannot supply the
  required embedding mode.

Model IDs are selected from dropdowns, not typed into free text fields. The
model option lists live in app constants and can be updated in later app
versions. A future dynamic model-list refresh can be added, but the first
implementation should avoid network-dependent settings rendering.

There is no separate "use Gemini" switch. The provider pill is the source of
truth.

Settings auto-save on edit. API key save, provider selection, and model
selection each emit debug logs. The UI must not report save failure if the key
was actually saved and the subsequent test succeeds.

Provider resolution rules:

- training, chat, groundedness, and embeddings use the active provider and the
  model configured for that capability;
- `missing_api_key` must include the provider name;
- Gemini-active training must not be blocked because OpenAI has no key;
- changing provider invalidates any stale in-memory provider client.

## Provider Error Handling

Provider errors are classified before they reach UI state.

Required classifications:

- missing API key;
- key test failed;
- quota/prepay/rate limit;
- temporary high demand;
- network abort/connection aborted;
- invalid structured response;
- JSON parse failure;
- schema validation failure;
- unsupported embedding configuration;
- unknown provider error.

Gemini document extraction must use structured output:

- response MIME type/application JSON mode where supported by the current client;
- schema for extraction result;
- schema validation before creating local chunks;
- one retry or repair path for invalid/malformed response;
- final retryable failure state if the response is still invalid.

The observed failures map as follows:

- `FormatException: Unexpected character` -> JSON parse failure, retry once,
  then invalid provider response.
- `invalid Gemini structured response` -> schema validation failure with field
  details in debug logs.
- `ClientException: Software caused connection abort` -> transient network
  failure, retryable/manual retry.
- Gemini 429 prepaid credits depleted -> quota/prepay failure.
- Gemini 503 high demand -> temporary high demand with backoff.

## Voice Design

Voice has two user-facing modes:

- push-to-talk;
- conversational mode.

Push-to-talk listens once and sends only a final, non-empty transcript.

Conversational mode runs:

1. listen;
2. final transcript;
3. Chat/RAG request;
4. TTS answer;
5. optionally listen again.

STT rules:

- `error_speech_timeout` is a no-speech state, not a fatal error;
- empty interim results do not send chat requests;
- only final transcript or explicit send triggers chat;
- permission, locale, status, partial result, final result, timeout, and stop are
  logged.

TTS rules:

- one active speech session at a time;
- repeated speak taps do not stack duplicate TTS sessions;
- pause/resume/stop are stateful;
- STT start or user interrupt can stop current TTS;
- Hungarian language availability is checked and logged.

If Chat/RAG refuses because of missing key or disabled paid AI, TTS can speak
the short refusal message once, but repeated automatic speaking is prevented.

## Flowchart Validation

Flowchart detection must produce a validation candidate when extraction finds a
flowchart-like structure.

The validation screen must explain zero-state causes:

- no processed documents;
- processed documents contain no detected flowcharts;
- flowcharts already validated;
- extraction failed;
- provider disabled or key missing.

Debug logs:

- extraction flowchart count;
- persisted flowchart count;
- validation query count;
- reason when the validation list is zero.

## Offline Non-LLM Fallback

Offline fallback is a separate mode, not pretending to be an AI answer.

The first design target:

- keyword search;
- exact phrase search;
- local chunk/folder filtering;
- source excerpt display;
- no generated answer.

BM25 or fuzzy search can be added if the existing local stack supports it with
low risk.

## Data Model Additions

Expected additions or extensions:

- `KnowledgeFolder`
  - id, name, createdAt, updatedAt, sort order.
- `KnowledgeDocument`
  - folder relation;
  - document hash;
  - import status;
  - sync status;
  - active provider/model metadata;
  - last processing error classification.
- `ProcessingJob`
  - provider;
  - model;
  - attempt;
  - retryable flag;
  - structured error code.
- `ChunkExportPackage`
  - schema version;
  - document hash;
  - embedding model/dimension;
  - provider metadata.
- `AppSettings`
  - active provider;
  - per-provider model selections;
  - voice mode settings.

The implementation should follow existing ObjectBox/entity patterns and avoid
large unrelated refactors.

## Debug Panel

The floating debug button remains visible across menus.

Debug categories:

- OpenAI;
- Google/Gemini;
- AI Training;
- VectorGraph;
- Chat/RAG;
- Flowchart;
- Knowledge;
- Voice/STT;
- Voice/TTS.

Secrets are never logged. API key logs may include provider and length only.

## Testing Strategy

Red/green tests should cover:

- API key save does not report failure after successful persistence;
- active provider controls which key is required;
- provider/model dropdown state persists automatically;
- Gemini malformed JSON maps to retryable parse failure;
- Gemini invalid structured response exposes validation details;
- Gemini connection abort maps to transient retryable failure;
- STT timeout produces no-speech state;
- empty interim STT results do not send chat;
- TTS repeated speak does not create duplicate sessions;
- PDF import creates visible documents without auto-sync;
- long tap enters selection mode and shows checkboxes on all rows;
- selection header batch actions use selected document IDs;
- normal and selection three-dot menus are overlays;
- folder create/rename/delete/move behavior;
- chunk export/import compatibility checks;
- flowchart extraction creates validation candidates.

Manual verification should include:

- import many PDFs;
- open a PDF in-app;
- long-tap selection and batch sync;
- switch OpenAI/Gemini providers;
- test missing-key, quota, high-demand, connection-abort, invalid-response
  states;
- run `flutter analyze` and `flutter test`.

APK builds must run through GitHub Actions, not local Termux APK builds.

## Implementation Notes

This is large enough to implement in staged ownership areas, but it can remain
one feature branch if tests are added as each subsystem is changed.

Recommended implementation sequence:

1. Provider/settings state and error classification.
2. Gemini structured output validation hardening.
3. Knowledge list selection-mode UI and in-app PDF viewer.
4. Folder metadata and move operations.
5. Manual sync queue and chunk export/import.
6. Voice STT/TTS state machine.
7. Flowchart validation queue diagnostics.
8. Offline fallback minimum search mode.

Subagents can be used for independent investigation or implementation streams
after a written implementation plan exists. Integration must be reviewed in the
main session before commit/push/build.

