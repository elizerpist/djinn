# Djinn System Design

Date: 2026-06-03

## Goal

Djinn is a local-first Flutter application for AI-assisted decision support over
OMSZ procedure documents. The first implementation creates the full project
shape, not a clinically deployable system: a usable text-only chat frontend, a
local backend API, a document ingestion/RAG pipeline skeleton, guardrail
contracts, and local infrastructure definitions.

The system must be designed so that production answers can later be grounded
only in the app's approved document corpus. When the corpus does not support an
answer, the assistant must say that the answer is not available in the knowledge
base instead of guessing.

## Initial Scope

- Create `/data/data/com.termux/files/home/ubuntu/flutteruser/flutterapps/djinn`.
- Use the existing local Flutter test app as a practical starting point, but
  replace the counter behavior with the Djinn chat experience.
- Use `flutter_messenger_clean_architecture` only as design inspiration for a
  clean messenger-style UI and feature boundaries.
- Keep the Flutter app text-only: no video, voice, stickers, emoji panel, file
  sending, or reactions.
- Add a local FastAPI backend skeleton.
- Add a document processing pipeline skeleton for PDFs, OCR, flowcharts,
  chunking, embeddings, Qdrant indexing, and manual validation checkpoints.
- Add Docker Compose definitions for Qdrant and PostgreSQL.
- Initialize git locally and push to a new GitHub repository when credentials
  and network access allow it.

## Frontend Design

The Flutter app has two primary screens.

The main screen shows existing conversations and a floating action button. The
FAB starts a new chat and navigates into the chat screen. The user can return
from a chat to the main screen and reopen another conversation.

The chat screen uses messenger-style bubbles:

- user messages aligned to the trailing side;
- assistant messages aligned to the leading side;
- compact timestamp/status metadata;
- text input fixed to the bottom;
- send button disabled for empty input;
- simple loading state while the backend responds.

The frontend stores conversation state locally for the first version. The API
client boundary is still explicit so the app can switch from a mock/local
backend to a real RAG backend without rewriting UI code.

## Backend Design

The local backend is a FastAPI service under `backend/`. It exposes:

- `GET /health` for readiness checks;
- `GET /conversations` for conversation summaries;
- `POST /conversations` to create a conversation;
- `GET /conversations/{id}/messages` to list messages;
- `POST /chat` to append a user message and return an assistant response.

The first backend response can be deterministic or rule-based, but it must use
the same response shape expected from the future RAG system:

- answer text;
- citations list;
- confidence/grounding status;
- refusal reason when the knowledge base does not contain the answer.

## RAG And Document Pipeline

The ingestion pipeline is a separate backend process, not something that runs
during chat. Its planned stages are:

1. Load OMSZ PDFs from a local corpus directory.
2. Extract text with PyMuPDF/pdfplumber/Unstructured-style adapters.
3. Run OCR when pages or extracted regions require it.
4. Identify pages, sections, headings, figures, and flowchart regions.
5. Extract flowchart images from PDF pages.
6. OCR flowchart nodes and detect arrows/decision edges where possible.
7. Require manual validation for clinical flowchart structure.
8. Chunk text and validated flowchart nodes with source metadata.
9. Create embeddings.
10. Store vectors in Qdrant and metadata in PostgreSQL.

For the first implementation, these stages are represented as runnable modules
or placeholders with explicit interfaces, not as a complete clinical extraction
engine.

## Retrieval And Safety

The future retrieval service should combine:

- vector retrieval for semantically related chunks;
- metadata filtering by source, procedure, page, and section;
- graph traversal for algorithmic flowchart steps;
- reranking before answer generation;
- strict answer synthesis that cites the retrieved source passages.

The safety layer must reject unsupported answers. It should return one of these
states:

- `grounded`: answer is supported by cited corpus evidence;
- `insufficient_evidence`: corpus search did not retrieve enough support;
- `out_of_scope`: user asks outside the OMSZ document scope;
- `unsafe_request`: the request cannot be answered safely by the system.

The first implementation includes these states and refusal behavior as API
contracts and backend stubs.

## Technology Direction

Frontend:

- Flutter;
- Material UI with a restrained messenger-style layout;
- local state classes/repositories before introducing heavier state management.

Backend:

- Python;
- FastAPI;
- Pydantic models;
- pytest-ready service boundaries.

RAG infrastructure:

- Qdrant for vector search;
- PostgreSQL for source metadata and audit records;
- optional LangGraph/LlamaIndex service boundaries later;
- MinerU/PyMuPDF/pdfplumber/OCR adapters as pipeline candidates;
- GraphRAG/LightRAG/Neo4j-style graph ideas as future research, not first-pass
  dependencies.

## Error Handling

Frontend:

- show backend unavailable state without losing the drafted message;
- keep chat history visible when a send fails;
- allow retrying failed sends.

Backend:

- return structured errors;
- distinguish unavailable backend, empty corpus, insufficient evidence, and
  unsafe/out-of-scope responses;
- log pipeline validation failures separately from chat errors.

Pipeline:

- never silently accept uncertain flowchart extraction;
- mark unvalidated flowcharts as unusable for clinical answers;
- preserve source page and region metadata for every extracted item.

## Testing Plan

Frontend tests:

- app starts and renders main screen;
- FAB creates/navigates to a new chat;
- sending text creates user and assistant bubbles;
- multiple conversations can be switched.

Backend tests:

- health endpoint works;
- chat endpoint returns the expected response shape;
- unsupported questions return `insufficient_evidence`;
- pipeline stage interfaces produce source metadata.

Integration smoke test:

- Flutter API client can call the local backend health endpoint or mocked
  equivalent;
- backend can run without Qdrant/PostgreSQL for development-mode stub responses.

## Open Decisions For Later

- Whether the production RAG orchestrator should use LangGraph, LlamaIndex,
  Haystack, or a custom lightweight service.
- Whether graph storage should be PostgreSQL tables, Neo4j, or a lighter
  in-memory/exported graph representation.
- Which exact PDF/OCR stack performs best on OMSZ documents.
- Which model providers will be supported after the local backend skeleton is
  stable.

## Non-Goals For This First Implementation

- No clinical validation claim.
- No live OMSZ corpus ingestion unless source files are already available.
- No production-grade flowchart understanding.
- No real LLM provider integration yet.
- No internet search from the app.
- No media/chat extras such as video, voice, emoji panel, attachments, or
  reactions.
