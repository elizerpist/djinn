# Djinn Backend Connected Retrieval MVP Design

Date: 2026-06-03

## Goal

Build the next Djinn milestone as one coherent but staged RAG foundation:
connect Flutter chat to the FastAPI backend, replace dry ingest with basic PDF
text extraction and chunk storage, then add a retrieval contract that can later
move to Qdrant and PostgreSQL without changing the mobile chat surface.

This milestone still does not make clinical claims. Answers must stay bounded
by app documents. If retrieval cannot produce enough source evidence, the
backend returns a refusal instead of guessing.

## Selected Approach

Use backend-first incremental RAG:

- Flutter chat sends messages to the backend `/chat` endpoint and renders the
  backend response contract.
- Backend ingest extracts text from uploaded PDFs, creates source-aware chunks,
  and marks a document `processed` only when chunks exist.
- Retrieval starts with a deterministic local chunk search service so behavior
  is testable before vector infrastructure is introduced.
- Qdrant and PostgreSQL are added behind repository interfaces after the local
  retrieval contract is working.

This keeps every stage runnable. The app moves from local stub chat to
backend-grounded refusal, then to cited retrieval, then to indexed retrieval.

## Scope

Included:

- Flutter backend chat client and chat service.
- Conversation send flow that stores user and assistant messages from backend
  responses.
- Backend PDF extraction using a small adapter boundary, initially PyMuPDF if
  available.
- Chunk model with document id, page number, text, and source metadata.
- In-memory or file-backed chunk registry for development and tests.
- Retrieval service that returns ranked chunks and citations.
- Safety behavior that only returns `grounded` when source chunks are present.
- Qdrant upsert/search adapter and PostgreSQL metadata adapter wired through
  feature-safe settings, with local fallback preserved for tests and offline
  development.

Excluded:

- Production clinical validation.
- Flowchart graph extraction as a trusted clinical source.
- LLM provider integration.
- Internet search.
- On-device backend execution.

## Flutter Design

The current `LocalChatRepository` keeps conversation state and deterministic
refusal messages. This milestone introduces a backend boundary without removing
local persistence:

- `BackendChatClient` calls `POST /chat` with message text and optional backend
  conversation id.
- `ChatService` coordinates local conversation state, backend calls, error
  handling, and message persistence.
- `ChatScreen` uses `ChatService` instead of directly calling
  `LocalChatRepository.sendMessage()`.
- Backend response fields map into assistant bubble metadata:
  `status`, `citations`, and `refusalReason`.

On backend failure, the user message remains visible and the assistant response
uses a clear backend-unavailable status. The typed draft is not lost before a
send attempt. The existing knowledge readiness banner remains independent and
continues to refresh before sending.

## Backend Chat Design

The backend `/chat` endpoint becomes the single source for assistant responses.
It keeps the current response shape:

- `conversation_id`
- `answer`
- `status`
- `citations`
- `refusal_reason`

The backend stores chat messages through `ConversationStore` and delegates answer
generation to a retrieval-aware service:

1. Validate message and conversation id.
2. Append the user message.
3. Check knowledge-base status.
4. If no processed chunks exist, return the existing refusal states.
5. Run retrieval over processed chunks.
6. If retrieval has enough evidence, return a grounded answer with citations.
7. If retrieval is weak or empty, return `insufficient_evidence`.
8. Append the assistant message with status.

For this milestone, the grounded answer may be a deterministic extractive answer
assembled from the top retrieved chunk. It must not invent clinical instructions
not present in the chunk text.

## PDF Extraction And Chunking

Backend ingest changes from a dry status transition to a small pipeline:

1. Load the uploaded PDF path from `DocumentRegistry`.
2. Extract text by page through `PdfTextExtractor`.
3. Normalize whitespace and ignore empty pages.
4. Split text into chunks with stable ids.
5. Store chunks through `ChunkRepository`.
6. Mark the document `processed` only when at least one chunk was stored.
7. Mark the document `failed` with an error message when extraction fails.

The first extractor should use PyMuPDF when available because it is lightweight
and fits the current backend shape. The extractor boundary must allow later
MinerU, OCR, and flowchart adapters without changing document status endpoints.

Chunk metadata must preserve:

- backend document id;
- filename;
- page number when known;
- chunk index;
- source path;
- extraction method.

## Retrieval Design

Retrieval starts as a deterministic local service:

- tokenize the user query and chunks;
- score chunks by simple lexical overlap;
- return the top matching chunks above a minimum score;
- convert chunks to citations.

This is deliberately modest. It proves the end-to-end data flow, citation
contract, and refusal behavior before embedding infrastructure is added.

The next infrastructure layer in this same milestone introduces:

- `VectorIndex` interface for upsert/search;
- Qdrant-backed implementation for vector search;
- `MetadataStore` interface for document/chunk audit metadata;
- PostgreSQL-backed implementation for durable metadata;
- settings that allow local deterministic retrieval to remain available for
  tests and offline development.

The local chunk repository remains a development fallback and test double, not
the only production-facing retrieval path for the milestone.

## Safety Rules

The answer service must obey these rules:

- No processed chunks: refuse with `retrieval_not_available` or current
  readiness-specific refusal.
- Retrieval below threshold: refuse with `insufficient_evidence`.
- Retrieval above threshold: answer only from cited chunk text.
- Citations must include document id, title, page where available, and excerpt.
- Flowchart-derived chunks are not trusted until manually validated; this
  milestone only handles text chunks as retrievable evidence.

No path may call the internet or answer from model prior knowledge.

## Error Handling

Flutter:

- backend timeout or network error creates a visible failed assistant message;
- local chat history is preserved;
- retry can resend the same text later;
- readiness refresh failure is shown separately from chat response failure.

Backend:

- extraction failure marks the document `failed`;
- missing stored PDF marks the document `failed`;
- unsupported PDF parsing returns a structured error message;
- retrieval errors return `insufficient_evidence` rather than a fabricated
  answer;
- Qdrant/PostgreSQL unavailability falls back to local retrieval only when local
  chunks are explicitly available.

## Testing Plan

Flutter tests:

- chat client serializes `/chat` requests and parses grounded/refusal responses;
- chat service persists user and backend assistant messages;
- chat service records backend-unavailable failures without deleting the local
  conversation;
- chat screen sends through the service and renders backend response text.

Backend tests:

- ingest extracts text from a small PDF fixture and stores chunks;
- ingest fails cleanly when the stored file is missing or unreadable;
- retrieval returns citations for matching chunks;
- `/chat` returns grounded extractive answers when retrieval finds evidence;
- `/chat` refuses when retrieval has no sufficient evidence;
- existing no-corpus and pending-ingest refusals remain stable.

CI:

- backend pytest stays green;
- `flutter analyze` stays clean;
- `flutter test` stays green;
- GitHub Android native build continues to produce the APK artifact.

## Implementation Sequence

1. Add Flutter backend chat client and service while preserving local storage.
2. Route `ChatScreen` sends through the new service.
3. Add backend chunk schema, chunk repository, and retrieval service contract.
4. Replace dry ingest with PDF text extraction and chunk storage.
5. Use retrieval in `/chat` to produce cited extractive answers or refusals.
6. Add Qdrant/PostgreSQL interfaces, adapters, and development wiring behind
   feature-safe fallbacks.
7. Verify locally and through GitHub Actions after each committed slice.

## Non-Goals

- No clinical deployment readiness.
- No autonomous flowchart interpretation for medical decisions.
- No LLM-generated treatment recommendations.
- No external web search.
- No broad UI redesign.
- No replacement of the current PDF import/sync UX.
