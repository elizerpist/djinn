# Djinn Backend Sync And Ingest Status Design

Date: 2026-06-03

## Goal

Add the next Djinn milestone after local PDF import: connect imported mobile
PDFs to the local backend document API, keep document ingest status synchronized,
and make chat behavior depend on backend knowledge-base readiness.

This slice must create an end-to-end operational loop without pretending that
the RAG pipeline is clinically complete. A PDF can be uploaded, registered, and
advanced through status states, but clinical answers still require processed and
validated corpus content.

## Selected Approach

Use a small sync layer between Flutter and the FastAPI backend:

- Flutter keeps the local document registry as the source of mobile UI state.
- Flutter uploads pending local PDFs to `POST /knowledge/documents` when backend
  sync is requested or available.
- Flutter stores the backend document id after upload.
- Flutter can request ingest/retry via
  `POST /knowledge/documents/{document_id}/ingest`.
- Flutter polls or refreshes `GET /knowledge/status` and
  `GET /knowledge/documents` to reconcile local statuses.
- Backend keeps ingest as a separate state transition. The first implementation
  may use a dry ingest transition to `pending_ingest` or `processed` only when
  explicitly triggered by testable backend logic.

This keeps the mobile app usable while preserving the future boundary for
PyMuPDF, OCR, MinerU, Qdrant, and graph/flowchart extraction.

## Status Lifecycle

Flutter document statuses:

- `pendingIngest`: file exists locally but is not ready for answers.
- `uploading`: upload or retry is actively running.
- `processed`: backend reports usable processed content.
- `failed`: upload or ingest failed with a visible reason.

Backend serialized statuses:

- `pending_ingest`
- `processing`
- `processed`
- `failed`

Mapping rule: Flutter must never mark a document `processed` from local state
alone. Only backend document/status responses may create a local `processed`
status.

## Flutter UX

The knowledge-base screen adds document actions:

- pending local document without backend id: upload/sync action;
- uploaded pending document: retry/start ingest action;
- failed document: retry action;
- processed document: read-only processed badge.

The main screen or knowledge-base screen should show aggregate backend status:

- backend unavailable: local documents preserved, sync unavailable;
- empty corpus: no knowledge base loaded;
- pending documents: processing/import pending;
- processed documents: knowledge base ready.

The chat screen must refresh readiness before sending or opening a conversation
when possible. If the backend is unavailable or not ready, it should still
answer with the existing grounded refusal text rather than hallucinating.

## Flutter Data Flow

1. User imports one or more PDFs through the folder screen.
2. App copies files into app-owned storage and creates local document rows.
3. User taps sync/retry, or the screen attempts sync on refresh.
4. `KnowledgeSyncService` uploads documents that have no backend id.
5. Uploaded documents store `backendDocumentId` and backend status.
6. `KnowledgeSyncService` can trigger ingest/retry for backend documents.
7. The app refreshes backend document/status endpoints and updates local rows.
8. Chat readiness uses the reconciled state.

## Backend Behavior

The backend already has upload/list/status endpoints. This slice tightens the
contract:

- upload returns a stable document id and `pending_ingest`;
- ingest endpoint returns the updated document record;
- status endpoint returns aggregate counts and readiness;
- failed ingest includes a machine-readable reason and human-readable message;
- non-PDF uploads remain rejected;
- files are stored safely without overwriting existing imported files.

If real extraction is not implemented in this slice, a dry ingest endpoint may
mark documents as `processed` only in a clearly testable development path. The
chat answer still must not cite extracted content until a retrieval layer exists.

## Error Handling

Flutter:

- upload failure keeps the local file row and records the error;
- missing local file changes the row to `failed`;
- backend unavailable is displayed separately from document failure;
- retry clears the previous error only after a successful backend response.

Backend:

- malformed upload returns 400;
- unknown document id returns 404;
- ingest failure returns structured `failed` status;
- status responses must remain available even when no documents exist.

## Testing Plan

Flutter tests:

- sync service uploads a pending local PDF and stores backend id/status;
- sync service maps backend `processed` to local `processed`;
- sync service records upload failure without deleting local metadata;
- knowledge-base screen shows upload/retry actions by status;
- chat screen readiness changes when repository status changes.

Backend tests:

- ingest endpoint returns updated document status;
- status endpoint reports counts for pending, processed, and failed documents;
- chat refusal distinguishes no corpus from pending corpus;
- processed corpus readiness can be reported without enabling retrieval claims.

CI:

- keep `flutter analyze`, `flutter test`, backend pytest, and GitHub Android
  native build green after this slice.

## Non-Goals

- No final medical RAG answer generation.
- No automatic clinical validation of OMSZ PDFs.
- No Qdrant/MinerU/OCR implementation in this slice.
- No internet lookup.
- No on-device Python backend.
