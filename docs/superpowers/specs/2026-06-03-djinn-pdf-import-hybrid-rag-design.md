# Djinn PDF Import And Hybrid RAG Design

Date: 2026-06-03

## Goal

Add the next Djinn milestone: persistent conversations, a knowledge-base import
entry point in the mobile app, local PDF registration, backend upload
preparation, and visible ingest status. This milestone must make the app useful
for loading OMSZ PDFs from a phone while staying honest about the RAG state.

The app must not claim that a PDF is usable for clinical answers until a backend
pipeline has accepted and processed it. If no processed knowledge base exists,
the assistant must say that the documents are imported but not yet validated for
RAG answers.

## Selected Approach

Use the hybrid approach:

- Flutter imports PDFs from the phone and stores document metadata locally.
- Flutter keeps chat history persistent across app restarts.
- Flutter can attempt backend upload when a backend base URL is configured.
- If the backend is unavailable, imported PDFs remain locally registered with
  `pending_ingest` status.
- The backend exposes document registry and upload contracts, and keeps the
  ingestion pipeline as a separate process boundary.

This avoids pretending that the Android APK itself can run the Python/FastAPI,
Qdrant, OCR, and graph pipeline. It also gives the app a real mobile workflow
immediately: choose PDFs, see them in the knowledge base, and understand whether
they are usable for answers.

## Mobile UI

The main screen gains a folder button in the app bar. The button opens a
knowledge-base screen.

The knowledge-base screen shows:

- an import button for selecting one or more PDF files from the phone;
- a document list with filename, size, imported time, and ingest status;
- a clear message when no documents are imported;
- a backend connection status line;
- an action to retry upload/ingest for pending documents.

The chat screen shows knowledge-base readiness above or near the composer:

- no documents: "No knowledge base loaded";
- imported but not processed: "Documents imported, ingest pending";
- processed: "Knowledge base ready";
- backend unavailable: "Backend unavailable, local documents preserved".

## Flutter Data Model

Add local models:

- `KnowledgeDocument`: id, filename, local path or uri, size, importedAt,
  status, backendDocumentId, errorMessage.
- `KnowledgeDocumentStatus`: imported, pendingIngest, uploading, processed,
  failed.
- `KnowledgeBaseState`: document list plus derived readiness.

Chat persistence should use a small local store abstraction. The first
implementation can use JSON files in app document storage rather than a database
if that keeps the code simpler and testable.

## Flutter Platform Dependencies

The Android app needs file picking and app document storage:

- `file_picker` for PDF selection;
- `path_provider` for app storage paths;
- `path` for safe filename/path handling.

The app should copy imported PDFs into app-owned storage where practical. If the
platform returns bytes instead of a stable path, the app writes those bytes to
the app document directory.

## Backend API Design

Add backend document endpoints:

- `GET /knowledge/documents` lists registered documents.
- `POST /knowledge/documents` accepts multipart PDF upload.
- `POST /knowledge/documents/{document_id}/ingest` starts or retries ingest.
- `GET /knowledge/status` returns aggregate readiness.

The first backend implementation may store files under `backend/corpus/omsz`
and metadata in an in-memory registry or JSON file. It must return clear
statuses and must not mark a document `processed` unless the dry ingest pipeline
or a real ingest stage explicitly says so.

## RAG Behavior

The chat answer contract remains strict:

- If no processed documents exist, return `insufficient_evidence`.
- If only imported/pending documents exist, include a refusal reason explaining
  that ingest is pending.
- No internet search is allowed.
- No answer should cite a document unless that document is processed.

For this milestone, "AI works with the PDFs" means the system can accept,
register, persist, and stage PDFs for backend processing. Full text extraction,
embedding, Qdrant retrieval, and flowchart understanding remain the following
milestone unless implemented behind the same contracts after this base is stable.

## Error Handling

Flutter:

- failed PDF copy keeps a visible error on the document row;
- backend upload failure changes status to `failed` or keeps `pendingIngest`
  with an error message;
- app restart preserves chat and document metadata;
- sending chat while backend is down shows a grounded refusal/error state.

Backend:

- reject non-PDF uploads;
- preserve original filenames safely;
- avoid overwriting files with the same name;
- expose ingest errors as structured status fields.

## Testing Plan

Flutter tests:

- persistent chat store can save and reload conversations;
- knowledge document store can add, list, update, and persist documents;
- knowledge-base screen shows empty state and imported document rows;
- main screen folder button opens the knowledge-base screen;
- chat screen displays pending-ingest readiness.

Backend tests:

- document upload rejects non-PDF files;
- PDF upload registers a document with `pending_ingest`;
- document list returns registered documents;
- knowledge status reports not ready until processed;
- chat response refuses when documents are pending but not processed.

CI:

- GitHub Actions continues to run Flutter analyze, Flutter tests, and native
  Android APK build on push.

## Non-Goals

- No production clinical validation.
- No automatic trust in flowchart extraction.
- No completed Qdrant retrieval loop in this milestone unless it fits without
  weakening the import/persistence foundation.
- No on-device Python backend.
- No internet search.
