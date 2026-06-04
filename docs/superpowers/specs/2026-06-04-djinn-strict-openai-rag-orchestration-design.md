# Djinn Strict OpenAI RAG Orchestration Design

Date: 2026-06-04

## Goal

Replace the current extractive lexical-answer MVP with a runnable, backend-only
OpenAI RAG architecture that uses LangGraph for orchestration, LangChain
integrations for OpenAI and Qdrant, NeMo Guardrails for programmable safety
checks, and deterministic server-side citation verification.

The Flutter application remains a thin mobile client. It never receives or
stores the OpenAI API key and never connects directly to OpenAI, Qdrant, or
PostgreSQL.

The system operates in strict blocking mode: any missing configuration,
retrieval weakness, guardrail failure, unsupported citation, verifier failure,
or infrastructure error returns a structured refusal instead of a generated
clinical answer.

## User-Visible Success Criteria

With a reachable backend configured with an OpenAI API key and running Qdrant:

1. The user imports a text-bearing PDF from the phone.
2. The app uploads and starts ingest for the PDF.
3. The backend extracts and chunks the text, creates OpenAI embeddings, and
   indexes the chunks in Qdrant.
4. The user asks a question in chat.
5. The backend retrieves relevant chunks, generates a source-bounded answer,
   verifies it, and returns citations.
6. The Flutter chat renders the answer and source metadata.

If any required stage cannot produce trustworthy evidence, the user receives a
clear refusal or backend readiness message. The app remains usable for local
chat history and document management even when the AI backend is unavailable.

## Selected Architecture

Use a deterministic LangGraph state machine around provider and guardrail
adapters:

1. Readiness and corpus preflight.
2. NeMo input guard.
3. OpenAI query embedding.
4. Qdrant vector retrieval.
5. Deterministic retrieval evidence checks and NeMo retrieval guard.
6. OpenAI structured answer generation through LangChain.
7. Deterministic citation validation.
8. Groundedness verification against the retrieved evidence.
9. NeMo output guard and fact-check rail.
10. Final cited answer or strict refusal.

LangGraph is used as an explicit workflow orchestrator, not as an autonomous
agent. The model receives no tools, cannot browse the internet, and cannot query
the database directly.

## Runtime Topology

```text
Flutter mobile app
  -> HTTPS/HTTP Djinn FastAPI backend
      -> LangGraph answer workflow
          -> NeMo Guardrails
          -> LangChain OpenAI chat and embeddings
          -> Qdrant vector store
          -> deterministic citation and groundedness verifiers
      -> PostgreSQL metadata store
```

The OpenAI API key exists only in the backend environment. During ingest,
document chunk text is sent to OpenAI to create embeddings. During chat, the
user question and the small set of retrieved source chunks are sent to OpenAI.
The complete database and unrelated documents are never exposed to the model.

## Configuration And Readiness

The backend reads:

- `OPENAI_API_KEY`
- `DJINN_OPENAI_CHAT_MODEL`, default `gpt-5-mini`
- `DJINN_OPENAI_EMBEDDING_MODEL`, default `text-embedding-3-large`
- `DJINN_QDRANT_URL`
- `DJINN_QDRANT_COLLECTION`
- `DJINN_POSTGRES_DSN`
- `DJINN_RETRIEVAL_MIN_SCORE`, `DJINN_RETRIEVAL_LIMIT`, and context limits

`GET /system/readiness` reports whether OpenAI, Qdrant, PostgreSQL metadata, and
NeMo Guardrails are configured and reachable. It must not expose API keys or
secrets.

Strict runtime readiness requires OpenAI, Qdrant, and guardrails. PostgreSQL
metadata errors are reported and block ingest operations that require durable
audit metadata. Tests use injected fakes and do not call live providers.

## Ingest And Indexing

The existing PDF upload and PyMuPDF text extraction remain. Ingest changes to:

1. Extract page text.
2. Create source-aware chunks with stable ids.
3. Generate embeddings in bounded batches through LangChain
   `OpenAIEmbeddings`.
4. Upsert vectors and trusted payload metadata into Qdrant.
5. Persist document/chunk audit metadata through the metadata-store boundary.
6. Mark the document processed only after all required writes succeed.

Required Qdrant payload fields include chunk id, document id, title, page,
source path, extraction method, and chunk text. Qdrant results are converted
back into server-owned `SourceChunk` values before entering the answer graph.

An OpenAI, Qdrant, or metadata failure marks ingest failed. No partially indexed
document becomes answerable.

This milestone indexes extracted PDF text only. OCR and flowchart-derived
content remain untrusted and excluded until their own validation pipeline is
implemented.

## LangGraph Answer Workflow

The graph state contains:

- conversation id and user message;
- readiness and refusal state;
- retrieved chunks and scores;
- model draft;
- verified citations;
- guardrail and verifier outcomes;
- final response.

Conditional edges end immediately in a refusal whenever a stage blocks or
fails.

```text
START
  -> preflight
  -> input_guard
  -> retrieve
  -> retrieval_guard
  -> generate_structured_draft
  -> verify_citations
  -> verify_groundedness
  -> output_guard
  -> finalize
  -> END
```

No node may silently continue after an exception. Graph errors map to a
structured `insufficient_evidence` response with a specific refusal reason.

## Retrieval

Production retrieval uses OpenAI query embeddings and Qdrant vector search.
Each result must pass:

- configured minimum similarity score;
- required payload and source metadata validation;
- processed text-only source requirement;
- maximum chunk count and context-size limits;
- retrieval guardrail checks.

The current lexical retrieval remains available only as a deterministic test
double and optional diagnostic comparison. It is not used to generate a
production grounded answer when strict provider mode is enabled.

## OpenAI Generation

LangChain `ChatOpenAI` calls the OpenAI Responses API without web search, file
search, remote MCP, code execution, or other tools.

Generation uses a Pydantic structured-output model containing:

- `answer`;
- `cited_chunk_ids`;
- `abstain`;
- `refusal_reason`.

The model is instructed to use only supplied evidence and to abstain when the
evidence is incomplete. The model cannot construct final citation objects.
Server code resolves cited chunk ids into citations from the retrieved,
validated chunk set.

## Strict Hallucination Protection

Protection is defense in depth, not a single library toggle:

1. **Input guard:** NeMo blocks prompt injection, attempts to override source
   restrictions, internet-search requests, and data-exfiltration requests.
2. **Retrieval guard:** invalid, malformed, or unsafe retrieved chunks are
   rejected before generation.
3. **Source-only prompt:** OpenAI receives an explicit closed-context system
   instruction and no external tools.
4. **Structured output:** generation must match a server-owned Pydantic schema.
5. **Citation verifier:** every cited id must be a retrieved chunk id; an answer
   with no valid citations is blocked.
6. **Groundedness verifier:** a separate structured OpenAI verification call
   checks the draft against the exact retrieved evidence and returns a supported
   verdict plus unsupported claims. Any unsupported or uncertain verdict blocks
   the answer.
7. **NeMo output/fact-check rails:** output safety and evidence entailment are
   checked before returning the answer.
8. **Fail closed:** a timeout, parse error, guardrail error, or uncertain verdict
   becomes a refusal.

No guardrail can guarantee medical correctness. This architecture reduces
unsupported model output and makes failures explicit, but the application
remains a non-clinically-validated prototype.

## Refusal Contract

The existing `ChatResponse` shape remains stable. New refusal reasons include:

- `ai_backend_not_configured`
- `vector_store_unavailable`
- `guardrails_unavailable`
- `input_blocked`
- `insufficient_retrieval_evidence`
- `retrieval_guard_blocked`
- `model_refused`
- `citation_verification_failed`
- `groundedness_verification_failed`
- `output_guard_blocked`
- `answer_pipeline_failed`

Every refusal returns no citations. A response is `grounded` only after all
graph stages pass.

## NeMo Guardrails Integration

NeMo Guardrails runs inside the FastAPI backend through its Python API and
reuses the configured OpenAI-backed LangChain model. No NVIDIA-hosted model or
on-device model is required.

The repository contains versioned guardrail configuration and prompts for:

- input self-check and prompt-injection policy;
- retrieval checks;
- output safety checks;
- source-grounded fact checking using relevant chunks.

The NeMo adapter exposes small `check_input`, `check_retrieval`, and
`check_output` methods so graph tests can use fakes. If NeMo cannot initialize
or returns an uncertain/error result, strict mode blocks the response.

## PostgreSQL Metadata Boundary

PostgreSQL stores durable audit metadata for indexed documents and chunks,
including indexing status, model identifiers, timestamps, and failure details.
The adapter initializes the minimal required schema idempotently.

Conversation history remains locally persisted in Flutter for this milestone.
Moving backend conversation state to PostgreSQL is a separate concern and is
not required for source-grounded answer generation.

## Flutter Changes

Flutter keeps the current messenger-style UI and local conversations.

Changes are limited to:

- parse backend readiness details;
- show whether the AI backend is configured and ready;
- render strict refusal states clearly;
- retain citations under grounded answers;
- ensure the release Android app has internet permission;
- document/build the backend URL through `DJINN_BACKEND_URL`.

The OpenAI key is never accepted in Flutter UI or compiled into the APK.

The generated APK can be installed and opened without a backend. To exercise AI
answers, the configured backend URL must be reachable from the phone and the
backend must have OpenAI/Qdrant/PostgreSQL/guardrail configuration. Release builds
receive Android internet permission and require an HTTPS backend. GitHub Actions
also produces a clearly named trial debug APK configured for
`http://127.0.0.1:8000`, allowing the app to reach a backend running in Termux on
the same phone; cleartext HTTP is allowed only in that debug manifest.

## Testing And Verification

Backend tests use fakes for OpenAI, Qdrant, NeMo, and PostgreSQL adapters.
Local fallback adapters are test-only and cannot make strict runtime ready:

- graph routes every failure state to a refusal;
- no model call occurs when retrieval is insufficient;
- cited ids outside the retrieved set are blocked;
- unsupported groundedness verdicts are blocked;
- successful graph output returns server-resolved citations;
- ingest only becomes processed after embedding and index writes succeed;
- readiness never exposes secrets.

Optional live integration tests run only when explicitly enabled with provider
credentials. Default CI never spends OpenAI credits.

Flutter tests cover readiness parsing, strict refusal rendering, grounded
citations, and backend-unavailable behavior.

GitHub Actions runs backend tests, Flutter analyze/tests, and builds/uploads both
the HTTPS-oriented release APK and a localhost-configured trial debug APK. No
OpenAI secret is required for either build.

## Deployment And Trial Flow

For a functional trial:

1. Set backend environment variables, including `OPENAI_API_KEY`.
2. Start Qdrant and PostgreSQL with Docker Compose.
3. Install backend dependencies and start FastAPI on a phone-reachable address.
4. For a same-phone Termux trial, run FastAPI on `127.0.0.1:8000` and install
   the GitHub `djinn-trial-apk` artifact. For a remote HTTPS backend, build the
   release APK with its reachable `DJINN_BACKEND_URL`.
5. Install the selected APK, import a PDF, sync it, and ask a source-covered
   question.

Production deployment requires HTTPS, secret management, authentication,
authorization, audit review, clinical validation, and operational monitoring.
Those controls are not implied by a successful trial build.

## Non-Goals

- No API key stored on the phone.
- No on-device or self-hosted language model.
- No internet or web-search tool for the model.
- No autonomous agent or tool-calling loop.
- No OCR or trusted flowchart interpretation.
- No claim of clinical validation or deployment readiness.
- No broad UI redesign.

## References

- LangGraph orchestration:
  https://docs.langchain.com/oss/python/langgraph/overview
- LangChain OpenAI integration:
  https://docs.langchain.com/oss/python/integrations/providers/openai/
- Qdrant LangChain integration:
  https://qdrant.tech/documentation/frameworks/langchain/
- OpenAI structured outputs:
  https://platform.openai.com/docs/guides/structured-outputs
- OpenAI embeddings:
  https://platform.openai.com/docs/guides/embeddings
- NeMo Guardrails Python API:
  https://docs.nvidia.com/nemo/guardrails/latest/run-rails/using-python-apis/index.html
- NeMo fact checking:
  https://docs.nvidia.com/nemo/guardrails/latest/configure-rails/guardrail-catalog/fact-checking.html
