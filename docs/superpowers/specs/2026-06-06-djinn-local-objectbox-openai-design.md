# Djinn Local ObjectBox OpenAI Design

Date: 2026-06-06

## Goal

Redesign Djinn from the current backend-driven prototype into a mobile-first
Flutter APK runtime where the user can configure an OpenAI API key in the app,
import OMSZ PDF documents from the phone, process them into a local ObjectBox
knowledge base, and chat against that local corpus with strict source-bounded
answers.

This design defines **B mode**. B mode is not a fallback. It is a user-selected
runtime mode whose storage, retrieval, validation state, chat history, and
knowledge-base state live inside the mobile app. If a future A mode backend is
selected and fails, the app must show an error instead of silently switching to
B mode.

## User-Visible Success Criteria

1. The app opens to a messenger-style chat experience with a clear empty state.
2. The user can create multiple chats with the FAB and switch between them.
3. The user can open the hamburger menu, enter an OpenAI API key, test it,
   change it, or delete it.
4. The user can open the knowledge-base screen, import PDFs from phone storage,
   and see processing status per document.
5. Imported PDFs are copied into app storage and processed automatically when an
   API key and network are available.
6. Processed text chunks, flowchart structures, embeddings, source metadata,
   and validation state are stored locally in ObjectBox.
7. Chat questions retrieve local ObjectBox evidence before OpenAI generation.
8. Answers contain citations. Unsupported questions return an insufficient
   evidence message instead of a guessed answer.
9. Non-validated flowchart evidence may be used, but the answer shows a warning
   and labels each affected citation.
10. Rejected flowcharts, nodes, and edges are never used as answer evidence.

## Runtime Scope

In scope for this redesign:

- Flutter mobile UI for chat, settings, knowledge base, and validation.
- ObjectBox local database and vector search as the primary retrieval store.
- OpenAI direct API access from the APK using the user's key.
- Secure API key storage through Android secure storage or Keystore-backed
  Flutter secure storage.
- PDF import from phone storage into app-private storage.
- OpenAI-assisted document and flowchart extraction.
- Local embeddings and vector search records in ObjectBox.
- Strict retrieval, citation verification, and optional groundedness checking.

Out of scope for this redesign:

- Running FastAPI, Qdrant, PostgreSQL, LangGraph, or NeMo Guardrails inside the
  APK.
- Termux as a required runtime for end users.
- Automatic fallback from backend mode to local mode.
- Multiple AI providers.
- Video, voice, emoji panel, stickers, reactions, or media chat features.
- Clinically validated deployment. This remains a prototype that must warn users
  that extracted clinical flowcharts require review.

## Selected Architecture

The selected architecture is B mode local-first with small future adapter
boundaries:

```text
Flutter UI
  -> application services
      -> chat orchestration
      -> document ingestion orchestration
      -> retrieval and citation verification
      -> flowchart validation workflows
      -> settings and mode selection
  -> data adapters
      -> ObjectBox local database
      -> app-private PDF file storage
      -> secure API key storage
  -> provider adapters
      -> OpenAI Responses/document processing
      -> OpenAI embeddings
```

The existing backend code can remain in the repository as a future A mode
reference, but B mode must not depend on it at runtime. The Flutter app should
use explicit service interfaces so a future backend adapter can be added later
without rewriting the chat UI.

## Modes

Version 1 ships with B mode as the default and only working runtime mode.

Settings may contain a mode section that explains:

- **B mode: Local ObjectBox** - active in this version.
- **A mode: Backend** - planned for later and disabled or marked unavailable.

When A mode is eventually implemented, it must be selected explicitly. A mode
errors must remain A mode errors and must not trigger automatic local fallback.

## UI Design

The main experience is a messenger-style chat app inspired by the linked
Flutter messenger clean architecture repository, but with only the required
features.

Primary UI areas:

- **Chat home:** empty state, active chat list, FAB for new chat.
- **Chat screen:** user and assistant bubbles, bottom composer, sending state,
  source/citation block, warning banner when required.
- **Hamburger menu:** conversations, knowledge base, flowchart validation,
  settings.
- **Knowledge base:** folder/import button, document list, processing status,
  retry, reprocess, delete.
- **Flowchart validation:** simple list mode and graphical editor mode.
- **Settings:** API key, model IDs, OpenAI file deletion behavior, groundedness
  check toggle, retrieval thresholds, mode information.

The empty state must never look like a broken blank screen. It should make the
next action obvious: create a chat or import documents.

## OpenAI Configuration

Version 1 supports OpenAI only.

The app stores the API key in secure storage, not in ObjectBox. ObjectBox stores
only non-secret state such as whether a key exists, the selected model IDs, and
last successful key-test metadata.

Default model behavior:

- Answer generation default: `gpt-5.5`.
- Document and flowchart extraction default: `gpt-5.5`.
- Optional groundedness check default: `gpt-5.5`.
- Embeddings default: `text-embedding-3-large`.

These IDs are editable in an advanced settings section. The app should avoid
using mutable aliases such as `chat-latest` as the default because clinical
auditability benefits from explicit model IDs. The settings screen may expose a
"restore recommended defaults" action.

OpenAI calls must not enable web search, hosted file search over unrelated
files, code execution, MCP tools, or other external tools for answer generation.
The model receives only the current document being processed or the local
retrieved evidence selected by the app.

Model source notes checked on 2026-06-06:

- OpenAI's model documentation recommends `gpt-5.5` when unsure for complex
  reasoning and professional work, and smaller variants for lower latency or
  cost.
- OpenAI's embeddings documentation lists `text-embedding-3-large` as the most
  capable third-generation embedding model and `text-embedding-3-small` as the
  lower-cost option.


## PDF Import And Processing

The knowledge-base screen provides a folder/import button. After the user
selects one or more PDFs:

1. The app copies each PDF into app-private storage.
2. The app creates a `KnowledgeDocument` and `ProcessingJob`.
3. If no API key is configured, the job stays blocked with a clear message.
4. If network is unavailable, the job stays retryable.
5. If prerequisites are present, processing starts automatically.

Processing flow:

1. Upload or pass the PDF to OpenAI through the supported official API path.
2. Request structured extraction of:
   - document title and sections;
   - page-aware text chunks;
   - clinical algorithm steps;
   - flowchart regions;
   - flowchart node text;
   - decision edges and labels;
   - source page and region metadata where available.
3. Store the structured extraction result locally.
4. Create embeddings for text chunks and flowchart retrieval units.
5. Store vectors, source metadata, and validation state in ObjectBox.
6. Mark the document `ready`, `needs_review`, or `failed`.
7. Delete the uploaded OpenAI file when the setting requires deletion.

OpenAI file deletion is configurable in Settings. The default is to delete
uploaded files after successful processing. If deletion fails, the app records a
warning in the processing job and exposes a retry/delete action where the API
allows it.

Original PDFs remain local until the user deletes them from the knowledge base.

## ObjectBox Data Model

The first implementation should model these entities:

- `ChatThread`
- `ChatMessage`
- `KnowledgeDocument`
- `DocumentChunk`
- `ChunkEmbedding`
- `Flowchart`
- `FlowchartNode`
- `FlowchartEdge`
- `Citation`
- `ProcessingJob`
- `AppSettings`

Key requirements:

- `KnowledgeDocument` stores local file path, original filename, import time,
  processing state, processing errors, and OpenAI remote-file metadata when
  applicable.
- `DocumentChunk` stores source text, page number, section title, source span or
  crop metadata when available, validation-independent source metadata, and a
  relation to the document.
- `ChunkEmbedding` stores ObjectBox vector data and points to either a text
  chunk or a flowchart retrieval unit.
- `Flowchart` stores document relation, page/crop metadata, validation status,
  extraction confidence, and review timestamps.
- `FlowchartNode` and `FlowchartEdge` store labels, graph topology, validation
  status, rejection reason, and editor layout positions.
- `Citation` stores the exact local source ID used in an answer and the source
  type label shown to the user.
- `ProcessingJob` stores state transitions and retryable errors for import,
  OpenAI processing, embedding, file deletion, and validation needs.
- `AppSettings` stores non-secret settings only.

Validation states:

- `unreviewed`
- `partially_validated`
- `validated`
- `rejected`

Processing states:

- `imported`
- `blocked_missing_api_key`
- `blocked_offline`
- `uploading`
- `processing`
- `embedded`
- `ready`
- `needs_review`
- `failed`

## Retrieval And Answer Flow

Chat does not send the user question directly to OpenAI as an unconstrained
prompt.

Runtime flow:

1. Validate API key presence.
2. Validate that at least one local document is processed and answerable.
3. Create an OpenAI embedding for the user question.
4. Query ObjectBox vector search across text chunks and flowchart retrieval
   units.
5. Exclude rejected flowcharts, rejected nodes, rejected edges, failed
   documents, and malformed source records.
6. Apply relevance thresholds and context-size limits.
7. If evidence is insufficient, return a local refusal without OpenAI answer
   generation.
8. Send only selected evidence to OpenAI for answer generation.
9. Require structured output containing answer text and cited source IDs.
10. Verify locally that every cited source ID exists in the retrieved evidence.
11. If enabled, run a second OpenAI groundedness check against the same evidence.
12. Persist the answer, citations, warning flags, and retrieval audit metadata.

Source labels shown in the answer:

- `Validated flowchart`
- `Partially validated flowchart`
- `Unvalidated flowchart`
- `Text PDF excerpt`

The Hungarian UI labels should be:

- `Validált flowchart`
- `Részben validált flowchart`
- `Nem validált flowchart`
- `Szöveges PDF-részlet`

The code may use ASCII enum values internally while the UI renders localized
Hungarian strings.

## Hallucination Protection

B mode uses deterministic app-side controls plus optional model-side checking:

1. The model has no web search and no direct database access.
2. The prompt states that only supplied local evidence may be used.
3. Retrieval must satisfy minimum similarity and source validity rules.
4. Rejected flowchart structures are excluded before generation.
5. Structured output must cite source IDs from the supplied evidence.
6. Local citation verification blocks unsupported citations.
7. Optional second OpenAI groundedness check can block unsupported answers.
8. Any parse error, timeout, missing citation, unsupported citation, or
   insufficient retrieval result becomes a refusal or explicit error.

NeMo Guardrails is not part of B mode because it is Python/server oriented in
the current architecture. A future A mode backend may reintroduce it.

## Flowchart Validation

OpenAI-extracted flowcharts are usable before validation, but answers must warn
the user when unreviewed or partially validated flowchart evidence affects the
answer.

Rules:

- `validated` flowchart with validated used nodes and edges: no warning.
- `partially_validated` flowchart: warning only when the answer uses unreviewed
  nodes or edges.
- `unreviewed` flowchart: always warning when used.
- `rejected` flowchart: excluded completely.
- `rejected` node or edge: excluded completely.

Validation UI:

- **Simple mode:** editable list of nodes and edges, node text edit, edge label
  edit, target node change, validate, reject, reprocess.
- **Graphical mode:** canvas with automatic layout, manual node movement,
  node/edge edit, add/delete node, add/delete edge, source page or crop preview,
  save validation.

Validation writes audit metadata: reviewer action, timestamp, previous value,
new value, and rejection reason when applicable.

## Error Handling

The app must make failures explicit:

- Missing API key: block import/chat and route to Settings.
- Invalid API key: show key-test failure and keep existing local data intact.
- No processed knowledge base: refuse chat answer and route to PDF import.
- No relevant source: return insufficient local evidence.
- OpenAI error: show provider error and allow retry.
- Network unavailable: mark job or message retryable.
- PDF processing failure: keep original local PDF and allow reprocess.
- OpenAI file deletion failure: warn and allow retry when possible.
- ObjectBox init failure: show local database error and do not attempt chat.
- Validation conflict: preserve latest saved local validation and require user
  review before overwriting.

No error path may silently switch modes.

## Privacy And Data Handling

The user must understand that B mode sends selected data to OpenAI:

- During document processing, the imported PDF or extracted document content may
  be sent to OpenAI.
- During embedding, text chunks and flowchart retrieval units are sent to
  OpenAI.
- During chat, the user question and retrieved local evidence are sent to
  OpenAI.

The app must not send unrelated local documents, unrelated chat history, or the
whole ObjectBox database to OpenAI.

The API key must never be logged, committed, shown in diagnostics, or stored in
plain ObjectBox records.

## Migration From Current Prototype

The current repository contains a Flutter app connected to a FastAPI backend
prototype with strict RAG ideas. For this redesign:

- Keep the messenger-style Flutter UI direction.
- Replace runtime dependency on `BackendChatClient` for B mode with a local
  chat orchestration service.
- Add ObjectBox-backed repositories for chats, documents, chunks, flowcharts,
  and settings.
- Preserve backend code as future A mode reference unless a later cleanup plan
  removes it.
- Update README and in-app wording so users do not think Termux is required for
  the APK.

## Testing Plan

Unit tests:

- retrieval excludes rejected documents, flowcharts, nodes, and edges;
- citation verification blocks unknown or non-retrieved source IDs;
- validation state rules produce the correct warning behavior;
- settings never expose the API key through ObjectBox models;
- insufficient evidence returns a local refusal before generation.

Widget tests:

- empty chat state is actionable;
- FAB creates a new chat;
- chat switching works;
- knowledge-base import status renders;
- missing API key routes to Settings;
- unvalidated flowchart warning renders above an answer.

Integration or smoke tests:

- ObjectBox store initializes;
- chat thread and messages persist;
- knowledge document and processing job persist;
- vector search can return a known local embedding fixture;
- OpenAI provider can be mocked for extraction, embeddings, answer generation,
  and groundedness checks.

Manual smoke test with a real API key:

1. Enter and test OpenAI API key.
2. Import a small PDF.
3. Process it into ObjectBox.
4. Ask a question with an answer present in the PDF.
5. Confirm citations render.
6. Ask an unsupported question and confirm refusal.
7. Validate one flowchart element and confirm the warning behavior changes.

## Implementation Order

The implementation plan should proceed in these milestones:

1. Settings and secure OpenAI key management.
2. ObjectBox entities, store initialization, and repository interfaces.
3. Chat persistence and local B mode orchestration skeleton.
4. Knowledge-base UI with PDF import and processing jobs.
5. OpenAI provider adapters for document extraction, embeddings, answers, and
   optional groundedness checks.
6. ObjectBox vector retrieval and citation verification.
7. Flowchart validation simple mode.
8. Graphical flowchart editor.
9. UI polish, README update, Android build verification, commit and push.
