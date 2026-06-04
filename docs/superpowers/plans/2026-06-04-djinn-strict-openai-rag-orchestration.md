# Djinn Strict OpenAI RAG Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace extractive lexical answers with a strict, backend-only OpenAI RAG workflow using LangGraph, LangChain OpenAI/Qdrant, NeMo Guardrails, PostgreSQL audit metadata, deterministic verification, and a phone-installable trial APK.

**Architecture:** FastAPI constructs a runtime container from environment settings. PDF ingest writes source chunks through a strict indexing service backed by LangChain OpenAI embeddings, Qdrant, and PostgreSQL metadata. Chat runs a fail-closed LangGraph workflow whose provider, retrieval, guardrail, and verifier boundaries are injectable for tests; Flutter remains a thin client and shows readiness/refusal states.

**Tech Stack:** Python 3.12/3.13, FastAPI, Pydantic, LangChain 1.3.x, LangGraph 1.2.x, langchain-openai 1.2.x, langchain-qdrant 1.1.x, NeMo Guardrails 0.22.x, Qdrant, PostgreSQL/psycopg, Flutter/Dart, GitHub Actions.

---

## File Structure

Backend contracts and runtime:

- Modify: `backend/requirements.txt` - add pinned-compatible LangChain, LangGraph, OpenAI, Qdrant, and NeMo packages.
- Modify: `backend/app/schemas.py` - add readiness, vector match, answer draft, and verification schemas.
- Modify: `backend/app/infra/settings.py` - strict provider/model/threshold settings.
- Create: `backend/app/runtime.py` - runtime container and environment-backed construction.
- Modify: `backend/app/main.py` - app factory, `/system/readiness`, runtime-backed routes.

Backend providers, indexing, and metadata:

- Create: `backend/app/services/provider_contracts.py` - injectable embedding/generation/groundedness protocols.
- Create: `backend/app/infra/openai_provider.py` - LangChain OpenAI structured generation and groundedness verification.
- Modify: `backend/app/infra/vector_index.py` - strict vector-index protocol, local fake, real LangChain Qdrant adapter.
- Modify: `backend/app/infra/metadata_store.py` - local fake plus real PostgreSQL audit store.
- Create: `backend/app/services/indexing_service.py` - atomic ingest orchestration.
- Modify: `backend/app/services/document_registry.py` - use indexing service and fail closed.

Backend guardrails and answer graph:

- Create: `backend/guardrails/config.yml` - NeMo rail configuration.
- Create: `backend/guardrails/rails/input.co` - strict input policy.
- Create: `backend/guardrails/rails/output.co` - strict output policy.
- Create: `backend/app/services/guardrail_contracts.py` - injectable guardrail protocol and result.
- Create: `backend/app/infra/nemo_guardrails.py` - NeMo Python API adapter.
- Create: `backend/app/services/answer_verifier.py` - citation and groundedness fail-closed checks.
- Create: `backend/app/services/answer_graph.py` - LangGraph workflow.
- Modify: `backend/app/services/answer_service.py` - delegate to compiled graph.

Flutter and trial build:

- Modify: `lib/src/knowledge/data/knowledge_api_client.dart` - parse `/system/readiness`.
- Modify: `lib/src/knowledge/data/knowledge_sync_service.dart` - carry AI readiness.
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart` - show strict AI readiness.
- Modify: `lib/src/chat/ui/chat_bubble.dart` - render friendly strict refusal labels.
- Modify: `android/app/src/main/AndroidManifest.xml` - release internet permission.
- Modify: `android/app/src/debug/AndroidManifest.xml` - debug-only localhost cleartext.
- Modify: `.github/workflows/android-native-build.yml` - backend tests plus release and trial APK artifacts.
- Modify: `.env.example`, `README.md`, `backend/README.md` - exact trial/runtime instructions.

Tests:

- Create: `backend/tests/test_settings_readiness.py`
- Create: `backend/tests/test_openai_provider.py`
- Create: `backend/tests/test_strict_vector_metadata.py`
- Create: `backend/tests/test_indexing_service.py`
- Create: `backend/tests/test_nemo_guardrails.py`
- Create: `backend/tests/test_answer_verifier.py`
- Create: `backend/tests/test_answer_graph.py`
- Modify: `backend/tests/conftest.py`, `backend/tests/test_api.py`, `backend/tests/test_knowledge_api.py`
- Modify: `test/knowledge_api_client_test.dart`, `test/knowledge_base_screen_test.dart`, `test/widget_test.dart`

---

## Task 1: Strict Settings And Readiness Contract

**Files:**
- Modify: `backend/requirements.txt`
- Modify: `backend/app/infra/settings.py`
- Modify: `backend/app/schemas.py`
- Create: `backend/tests/test_settings_readiness.py`

- [ ] **Step 1: Write failing settings and readiness tests**

Create `backend/tests/test_settings_readiness.py`:

```python
from app.infra.settings import BackendSettings
from app.schemas import ComponentReadiness, SystemReadinessResponse


def test_strict_settings_parse_provider_models_and_thresholds():
    settings = BackendSettings.from_env({
        'OPENAI_API_KEY': 'secret',
        'DJINN_OPENAI_CHAT_MODEL': 'gpt-5-mini',
        'DJINN_OPENAI_EMBEDDING_MODEL': 'text-embedding-3-large',
        'DJINN_RETRIEVAL_MIN_SCORE': '0.72',
        'DJINN_RETRIEVAL_LIMIT': '4',
    })

    assert settings.openai_configured is True
    assert settings.openai_chat_model == 'gpt-5-mini'
    assert settings.openai_embedding_model == 'text-embedding-3-large'
    assert settings.retrieval_min_score == 0.72
    assert settings.retrieval_limit == 4
    assert settings.strict_mode is True


def test_readiness_response_does_not_serialize_secrets():
    response = SystemReadinessResponse(
        ready=False,
        strict_mode=True,
        components={
            'openai': ComponentReadiness(ready=False, detail='not configured'),
        },
    )

    encoded = response.model_dump_json()
    assert 'secret' not in encoded
    assert 'api_key' not in encoded
```

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_settings_readiness.py
```

Expected: FAIL because strict settings and readiness schemas do not exist.

- [ ] **Step 3: Add dependencies and install**

Append to `backend/requirements.txt`:

```text
langchain>=1.3,<1.4
langgraph>=1.2,<1.3
langchain-openai>=1.2,<1.3
langchain-qdrant>=1.1,<1.2
nemoguardrails>=0.22,<0.23
```

Run:

```bash
pip install -r requirements.txt
python -c "import langchain, langgraph, langchain_openai, langchain_qdrant, nemoguardrails"
```

Expected: both commands exit 0.

- [ ] **Step 4: Implement strict settings**

Extend `BackendSettings` with:

```python
openai_api_key: str | None
openai_chat_model: str
openai_embedding_model: str
strict_mode: bool
retrieval_min_score: float
retrieval_limit: int
max_context_chars: int

@property
def openai_configured(self) -> bool:
    return bool(self.openai_api_key)
```

`from_env()` must default to strict mode, `gpt-5-mini`,
`text-embedding-3-large`, minimum score `0.70`, retrieval limit `3`, and maximum
context `12000`. Keep Qdrant/PostgreSQL defaults already used by the repo.

- [ ] **Step 5: Implement readiness schemas**

Add to `backend/app/schemas.py`:

```python
class ComponentReadiness(BaseModel):
    ready: bool
    detail: str


class SystemReadinessResponse(BaseModel):
    ready: bool
    strict_mode: bool
    components: dict[str, ComponentReadiness]
```

- [ ] **Step 6: Run tests green and commit**

Run:

```bash
PYTHONPATH=. pytest -q tests/test_settings_readiness.py tests/test_infra_adapters.py
```

Commit:

```bash
git add backend/requirements.txt backend/app/infra/settings.py backend/app/schemas.py backend/tests/test_settings_readiness.py
git commit -m "feat: add strict AI runtime settings"
```

---

## Task 2: Provider Contracts And Structured OpenAI Adapter

**Files:**
- Create: `backend/app/services/provider_contracts.py`
- Create: `backend/app/infra/openai_provider.py`
- Modify: `backend/app/schemas.py`
- Create: `backend/tests/test_openai_provider.py`

- [ ] **Step 1: Write failing provider tests**

Create `backend/tests/test_openai_provider.py` using an injected fake structured
LLM:

```python
from app.infra.openai_provider import OpenAIAnswerProvider
from app.schemas import AnswerDraft, GroundednessVerdict, SourceChunk


def test_openai_provider_passes_closed_context_and_parses_draft():
    model = FakeStructuredModel(AnswerDraft(
        answer='ABCDE vizsgalat szukseges.',
        cited_chunk_ids=['chunk-1'],
        abstain=False,
        refusal_reason=None,
    ))
    provider = OpenAIAnswerProvider(draft_model=model, verifier_model=model)

    draft = provider.generate('Mi a teendo?', [_chunk('chunk-1')])

    assert draft.cited_chunk_ids == ['chunk-1']
    assert 'chunk-1' in model.last_prompt
    assert 'Kizarolag' in model.last_prompt


def test_openai_provider_parses_groundedness_verdict():
    verifier = FakeStructuredModel(GroundednessVerdict(
        supported=True,
        unsupported_claims=[],
    ))
    provider = OpenAIAnswerProvider(draft_model=verifier, verifier_model=verifier)

    verdict = provider.verify_groundedness('ABCDE', [_chunk('chunk-1')])

    assert verdict.supported is True
```

The test file must define `FakeStructuredModel.invoke(prompt)` and `_chunk()` so
no network is used.

- [ ] **Step 2: Run tests red**

Run: `PYTHONPATH=. pytest -q tests/test_openai_provider.py`

Expected: FAIL because provider contracts, schemas, and adapter do not exist.

- [ ] **Step 3: Add structured schemas and protocols**

Add to `backend/app/schemas.py`:

```python
class AnswerDraft(BaseModel):
    answer: str
    cited_chunk_ids: list[str] = Field(default_factory=list)
    abstain: bool
    refusal_reason: str | None = None


class GroundednessVerdict(BaseModel):
    supported: bool
    unsupported_claims: list[str] = Field(default_factory=list)
```

Create protocols in `provider_contracts.py`:

```python
class AnswerProvider(Protocol):
    def generate(self, question: str, chunks: list[SourceChunk]) -> AnswerDraft: ...
    def verify_groundedness(self, answer: str, chunks: list[SourceChunk]) -> GroundednessVerdict: ...
```

- [ ] **Step 4: Implement OpenAI adapter**

`OpenAIAnswerProvider.from_settings(settings)` must construct one LangChain
`ChatOpenAI` with `use_responses_api=True`, then create separate structured
models:

```python
llm = ChatOpenAI(
    model=settings.openai_chat_model,
    api_key=settings.openai_api_key,
    use_responses_api=True,
)
draft_model = llm.with_structured_output(AnswerDraft, method='json_schema')
verifier_model = llm.with_structured_output(GroundednessVerdict, method='json_schema')
```

`generate()` formats numbered evidence blocks containing only chunk ids and
text, and explicitly prohibits outside knowledge, tools, and uncited claims.
`verify_groundedness()` performs a separate structured call with the draft and
same evidence.

- [ ] **Step 5: Run tests green and commit**

Run: `PYTHONPATH=. pytest -q tests/test_openai_provider.py`

Commit:

```bash
git add backend/app/schemas.py backend/app/services/provider_contracts.py backend/app/infra/openai_provider.py backend/tests/test_openai_provider.py
git commit -m "feat: add structured OpenAI answer provider"
```

---

## Task 3: Strict Qdrant And PostgreSQL Adapters

**Files:**
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/infra/vector_index.py`
- Modify: `backend/app/infra/metadata_store.py`
- Create: `backend/tests/test_strict_vector_metadata.py`

- [ ] **Step 1: Write failing adapter contract tests**

Create tests proving that local test doubles replace document chunks, preserve
scores, and store audit metadata:

```python
def test_local_vector_index_replaces_document_and_returns_scored_chunks():
    index = LocalVectorIndex()
    index.replace_document_chunks('doc-1', [_chunk('old', 'old text')])
    index.replace_document_chunks('doc-1', [_chunk('new', 'ABCDE vizsgalat')])

    matches = index.search('ABCDE', limit=3, minimum_score=0.1)

    assert [match.chunk.id for match in matches] == ['new']
    assert matches[0].score >= 0.1


def test_local_metadata_store_records_embedding_audit_fields():
    store = LocalMetadataStore()
    store.replace_document_chunks(
        'doc-1', [_chunk('chunk-1', 'ABCDE')],
        embedding_model='text-embedding-3-large',
    )

    assert store.list_document_chunks('doc-1')[0].id == 'chunk-1'
    assert store.document_audit('doc-1').embedding_model == 'text-embedding-3-large'
```

- [ ] **Step 2: Run tests red**

Run: `PYTHONPATH=. pytest -q tests/test_strict_vector_metadata.py`

Expected: FAIL because strict adapter methods and schemas do not exist.

- [ ] **Step 3: Define strict adapter contracts**

Add schemas:

```python
class VectorSearchMatch(BaseModel):
    chunk: SourceChunk
    score: float


class DocumentIndexAudit(BaseModel):
    document_id: str
    embedding_model: str
    indexed_at: str
    chunk_count: int
```

Update protocols:

```python
class VectorIndex(Protocol):
    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None: ...
    def search(self, query: str, *, limit: int, minimum_score: float) -> list[VectorSearchMatch]: ...
    def ping(self) -> bool: ...


class MetadataStore(Protocol):
    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk], *, embedding_model: str) -> None: ...
    def list_document_chunks(self, document_id: str) -> list[SourceChunk]: ...
    def document_audit(self, document_id: str) -> DocumentIndexAudit | None: ...
    def ping(self) -> bool: ...
```

- [ ] **Step 4: Implement LangChain Qdrant adapter**

`QdrantVectorIndex.from_settings(settings)` creates `OpenAIEmbeddings` and a
`QdrantVectorStore`. `replace_document_chunks()` deletes the existing document
filter and calls `add_documents()` with LangChain `Document` values whose
metadata contains all source fields. `search()` calls
`similarity_search_with_score()` and maps only valid payloads back to
`VectorSearchMatch`; malformed payloads are discarded.

- [ ] **Step 5: Implement PostgreSQL audit store**

`PostgresMetadataStore` must initialize idempotent `djinn_document_index` and
`djinn_source_chunk` tables, replace rows in one transaction, and reconstruct
`SourceChunk` values from JSON metadata. `ping()` runs `SELECT 1`.

- [ ] **Step 6: Run tests green and commit**

Run:

```bash
PYTHONPATH=. pytest -q tests/test_strict_vector_metadata.py tests/test_infra_adapters.py
```

Commit:

```bash
git add backend/app/schemas.py backend/app/infra/vector_index.py backend/app/infra/metadata_store.py backend/tests/test_strict_vector_metadata.py
git commit -m "feat: implement strict vector and metadata adapters"
```

---

## Task 4: Atomic Indexing Service And Strict Ingest

**Files:**
- Create: `backend/app/services/indexing_service.py`
- Modify: `backend/app/services/document_registry.py`
- Modify: `backend/tests/test_knowledge_api.py`
- Create: `backend/tests/test_indexing_service.py`

- [ ] **Step 1: Write failing atomic-index tests**

Create fakes that record calls and can fail. Required tests:

```python
def test_indexing_service_writes_vector_then_metadata():
    vector = RecordingVectorIndex()
    metadata = RecordingMetadataStore()
    service = IndexingService(vector_index=vector, metadata_store=metadata, embedding_model='embedding-model')

    service.replace_document_chunks('doc-1', [_chunk('chunk-1')])

    assert vector.document_ids == ['doc-1']
    assert metadata.document_ids == ['doc-1']


def test_document_registry_marks_failed_when_vector_index_fails(tmp_path):
    registry = DocumentRegistry(
        storage_dir=tmp_path,
        extractor=FakeExtractor([(1, 'ABCDE')]),
        indexing_service=FailingIndexingService(),
    )
    record = registry.register_bytes_for_test('protocol.pdf', b'%PDF')

    result = registry.start_ingest(record.id)

    assert result.status == KnowledgeDocumentStatus.failed
    assert result.error_message
```

Do not add a production-only test helper. For the registry test, create the
record through `UploadFile` or construct the existing record in the registry in
the test fixture.

- [ ] **Step 2: Run tests red**

Run: `PYTHONPATH=. pytest -q tests/test_indexing_service.py tests/test_knowledge_api.py`

Expected: FAIL because `IndexingService` and registry injection do not exist.

- [ ] **Step 3: Implement indexing service**

```python
class IndexingError(Exception):
    pass


class IndexingService:
    def __init__(self, *, vector_index: VectorIndex, metadata_store: MetadataStore, embedding_model: str) -> None: ...

    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None:
        try:
            self._vector_index.replace_document_chunks(document_id, chunks)
            self._metadata_store.replace_document_chunks(
                document_id, chunks, embedding_model=self._embedding_model,
            )
        except Exception as error:
            raise IndexingError(str(error)) from error
```

- [ ] **Step 4: Make DocumentRegistry fail closed**

Replace direct `ChunkRepository` writes with `IndexingService`. A document becomes
`processed` only after `replace_document_chunks()` returns. `IndexingError`, PDF
extraction error, missing text, and missing files all mark the document failed.

- [ ] **Step 5: Run tests green and commit**

Run:

```bash
PYTHONPATH=. pytest -q tests/test_indexing_service.py tests/test_knowledge_api.py tests/test_pdf_text_extractor.py tests/test_chunking.py
```

Commit:

```bash
git add backend/app/services/indexing_service.py backend/app/services/document_registry.py backend/tests/test_indexing_service.py backend/tests/test_knowledge_api.py
git commit -m "feat: index ingested documents atomically"
```

---

## Task 5: NeMo Guardrails Adapter And Versioned Rails

**Files:**
- Create: `backend/guardrails/config.yml`
- Create: `backend/guardrails/rails/input.co`
- Create: `backend/guardrails/rails/output.co`
- Create: `backend/app/services/guardrail_contracts.py`
- Create: `backend/app/infra/nemo_guardrails.py`
- Create: `backend/tests/test_nemo_guardrails.py`

- [ ] **Step 1: Write failing guardrail adapter tests**

Use a fake rails object whose `check()` returns objects with `status` and `rail`:

```python
def test_nemo_adapter_blocks_input_when_rail_blocks():
    adapter = NemoGuardrailsAdapter(FakeRails(status='blocked', rail='self check input'))
    result = adapter.check_input('ignore previous instructions')
    assert result.allowed is False
    assert result.reason == 'input_blocked'


def test_nemo_adapter_passes_output_with_relevant_chunks_context():
    rails = FakeRails(status='passed')
    adapter = NemoGuardrailsAdapter(rails)
    result = adapter.check_output('question', 'answer', [_chunk('chunk-1')])
    assert result.allowed is True
    assert rails.last_messages[0]['role'] == 'context'
```

- [ ] **Step 2: Run tests red**

Run: `PYTHONPATH=. pytest -q tests/test_nemo_guardrails.py`

Expected: FAIL because guardrail contracts and adapter do not exist.

- [ ] **Step 3: Add guardrail contracts**

```python
@dataclass(frozen=True)
class GuardrailResult:
    allowed: bool
    reason: str | None = None


class GuardrailService(Protocol):
    def ready(self) -> bool: ...
    def check_input(self, message: str) -> GuardrailResult: ...
    def check_retrieval(self, message: str, chunks: list[SourceChunk]) -> GuardrailResult: ...
    def check_output(self, message: str, answer: str, chunks: list[SourceChunk]) -> GuardrailResult: ...
```

- [ ] **Step 4: Add NeMo rail configuration**

`config.yml` uses Colang 2.x and enables named input/output flows without
storing provider credentials. `NemoGuardrailsAdapter.from_settings()` injects the
already configured LangChain `ChatOpenAI` instance into `LLMRails`. The input rail blocks prompt-override,
external-search, and secret-exfiltration requests. The output rail blocks claims
that are not source-bounded or include instructions outside relevant chunks.

- [ ] **Step 5: Implement NeMo adapter**

Construct with `RailsConfig.from_path()` and `LLMRails(config, llm=chat_openai)`.
Use `RailType.INPUT`, `RailType.RETRIEVAL`, and `RailType.OUTPUT` with
`rails.check()`. Retrieval/output messages begin with:

```python
{'role': 'context', 'content': {'relevant_chunks': [chunk.text for chunk in chunks]}}
```

Any NeMo exception, missing status, or non-passed result returns `allowed=False`.

- [ ] **Step 6: Run tests green and commit**

Run: `PYTHONPATH=. pytest -q tests/test_nemo_guardrails.py`

Commit:

```bash
git add backend/guardrails backend/app/services/guardrail_contracts.py backend/app/infra/nemo_guardrails.py backend/tests/test_nemo_guardrails.py
git commit -m "feat: add strict NeMo guardrails"
```

---

## Task 6: Deterministic Verifier And LangGraph Answer Workflow

**Files:**
- Create: `backend/app/services/answer_verifier.py`
- Create: `backend/app/services/answer_graph.py`
- Modify: `backend/app/services/answer_service.py`
- Create: `backend/tests/test_answer_verifier.py`
- Create: `backend/tests/test_answer_graph.py`

- [ ] **Step 1: Write failing citation-verifier tests**

```python
def test_verifier_resolves_only_retrieved_chunk_ids():
    verifier = AnswerVerifier(provider=FakeProvider(supported=True))
    result = verifier.verify(_draft(['chunk-1']), [_chunk('chunk-1')])
    assert result.citations[0].document_id == 'doc-1'


def test_verifier_blocks_unknown_citation_id():
    verifier = AnswerVerifier(provider=FakeProvider(supported=True))
    result = verifier.verify(_draft(['outside']), [_chunk('chunk-1')])
    assert result.allowed is False
    assert result.reason == 'citation_verification_failed'


def test_verifier_blocks_unsupported_groundedness():
    verifier = AnswerVerifier(provider=FakeProvider(supported=False))
    result = verifier.verify(_draft(['chunk-1']), [_chunk('chunk-1')])
    assert result.reason == 'groundedness_verification_failed'
```

- [ ] **Step 2: Write failing graph route tests**

`backend/tests/test_answer_graph.py` must cover:

- not-ready preflight -> `ai_backend_not_configured` and zero provider calls;
- input block -> `input_blocked` and zero retrieval calls;
- weak retrieval -> `insufficient_retrieval_evidence` and zero generation calls;
- retrieval/output guard block -> respective refusal;
- model abstention -> `model_refused`;
- citation/groundedness failure -> refusal;
- successful graph -> grounded answer with server-resolved citations.

- [ ] **Step 3: Run tests red**

Run:

```bash
PYTHONPATH=. pytest -q tests/test_answer_verifier.py tests/test_answer_graph.py
```

Expected: FAIL because verifier and graph do not exist.

- [ ] **Step 4: Implement deterministic verifier**

`AnswerVerifier.verify(draft, chunks)` rejects abstention, empty answers, empty
citations, duplicate/unknown cited ids, and unsupported groundedness verdicts.
It creates final `Citation` values only from server-owned retrieved chunks.

- [ ] **Step 5: Implement LangGraph workflow**

Create a `TypedDict` graph state and compile a `StateGraph` with these nodes:

```text
preflight -> input_guard -> retrieve -> retrieval_guard -> generate
-> verify -> output_guard -> finalize
```

Each node catches provider/infrastructure errors and sets exactly one refusal
reason. Conditional edges route any refusal directly to `finalize`. `finalize`
returns `ChatResponse` with no citations for refusals and `grounded` only after
all checks pass.

- [ ] **Step 6: Make AnswerService delegate to graph**

`AnswerService.answer()` invokes the compiled graph with conversation id,
message, and knowledge status. Remove the production extractive top-chunk answer
path.

- [ ] **Step 7: Run tests green and commit**

Run:

```bash
PYTHONPATH=. pytest -q tests/test_answer_verifier.py tests/test_answer_graph.py tests/test_retrieval.py
```

Commit:

```bash
git add backend/app/services/answer_verifier.py backend/app/services/answer_graph.py backend/app/services/answer_service.py backend/tests/test_answer_verifier.py backend/tests/test_answer_graph.py
git commit -m "feat: add fail-closed LangGraph answer workflow"
```

---

## Task 7: Runtime Container, Readiness Endpoint, And FastAPI Wiring

**Files:**
- Create: `backend/app/runtime.py`
- Modify: `backend/app/main.py`
- Modify: `backend/tests/conftest.py`
- Modify: `backend/tests/test_api.py`
- Modify: `backend/tests/test_knowledge_api.py`
- Create: `backend/tests/test_runtime.py`

- [ ] **Step 1: Write failing runtime and readiness API tests**

Required tests:

```python
def test_unconfigured_runtime_is_not_ready_and_hides_secrets():
    runtime = build_runtime(BackendSettings.from_env({}))
    readiness = runtime.readiness.status()
    assert readiness.ready is False
    assert 'secret' not in readiness.model_dump_json()


def test_system_readiness_endpoint_uses_injected_runtime(fake_runtime):
    client = TestClient(create_app(fake_runtime))
    body = client.get('/system/readiness').json()
    assert body['ready'] is True
    assert body['components']['openai']['ready'] is True
```

- [ ] **Step 2: Run tests red**

Run: `PYTHONPATH=. pytest -q tests/test_runtime.py tests/test_api.py tests/test_knowledge_api.py`

Expected: FAIL because runtime container, app factory, and readiness endpoint do
not exist.

- [ ] **Step 3: Implement runtime container and readiness service**

Create a `DjinnRuntime` dataclass containing conversation store, document
registry, answer service, and readiness service. `build_runtime(settings)`:

- returns disabled fail-closed provider/vector/metadata/guardrail adapters when
  required configuration is absent;
- constructs real OpenAI, LangChain Qdrant, PostgreSQL, NeMo, indexing, and graph
  services when configured;
- never raises during module import because a secret or service is missing.

Readiness checks provider configuration and adapter `ping()`/`ready()` methods,
catches errors, and returns component details without secrets.

- [ ] **Step 4: Refactor FastAPI to app factory**

```python
def create_app(runtime: DjinnRuntime | None = None) -> FastAPI:
    app = FastAPI(...)
    app.state.runtime = runtime or build_runtime(BackendSettings.from_env())
    # register routes that read app.state.runtime
    return app


app = create_app()
```

Add `GET /system/readiness`. `/chat` must return a strict refusal when runtime is
not ready. Ingest must fail rather than silently use lexical/local production
fallbacks.

- [ ] **Step 5: Migrate API tests to injected fake runtime**

`conftest.py` supplies `fake_runtime` and `client` fixtures. Fakes must use local
in-memory adapters but report ready, so default CI does not call OpenAI/Qdrant or
PostgreSQL.

- [ ] **Step 6: Run backend full suite and commit**

Run: `PYTHONPATH=. pytest -q`

Commit:

```bash
git add backend/app/runtime.py backend/app/main.py backend/tests/conftest.py backend/tests/test_runtime.py backend/tests/test_api.py backend/tests/test_knowledge_api.py
git commit -m "feat: wire strict AI runtime into FastAPI"
```

---

## Task 8: Flutter Readiness, Strict Refusals, And Android Connectivity

**Files:**
- Modify: `lib/src/knowledge/data/knowledge_api_client.dart`
- Modify: `lib/src/knowledge/data/knowledge_sync_service.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/debug/AndroidManifest.xml`
- Modify: `test/knowledge_api_client_test.dart`
- Modify: `test/knowledge_base_screen_test.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write failing Flutter readiness tests**

Extend `test/knowledge_api_client_test.dart` with a `/system/readiness` response:

```dart
final readiness = await client.getSystemReadiness();
expect(readiness.ready, isFalse);
expect(readiness.components['openai']?.detail, 'not configured');
```

Extend widget tests to expect `AI backend nincs beallitva` when backend is
reachable but readiness is false, and a friendly strict refusal label for
`groundedness_verification_failed`.

- [ ] **Step 2: Run Flutter tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter test test/knowledge_api_client_test.dart test/knowledge_base_screen_test.dart test/widget_test.dart
```

Expected: FAIL because readiness parsing and UI states do not exist.

- [ ] **Step 3: Implement Flutter readiness parsing and display**

Add immutable `BackendComponentReadiness` and `BackendSystemReadiness` models.
`KnowledgeApiClient.getSystemReadiness()` calls `/system/readiness`.
`KnowledgeSyncService.refresh()` returns system readiness alongside knowledge
state. `KnowledgeBaseScreen` shows:

- backend unavailable;
- AI backend not configured;
- AI backend ready;
- exact non-secret failing component details.

Map strict refusal reasons to short Hungarian labels under assistant bubbles;
keep the full backend answer text and citations unchanged.

- [ ] **Step 4: Add Android network manifests**

Main manifest receives:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Debug manifest adds an `<application android:usesCleartextTraffic="true"/>`
overlay. Do not allow cleartext in the main/release manifest.

- [ ] **Step 5: Run Flutter tests/analyze and commit**

Run:

```bash
flutter test
flutter analyze
```

Commit:

```bash
git add lib/src/knowledge lib/src/chat/ui/chat_bubble.dart android/app/src/main/AndroidManifest.xml android/app/src/debug/AndroidManifest.xml test/knowledge_api_client_test.dart test/knowledge_base_screen_test.dart test/widget_test.dart
git commit -m "feat: show strict AI readiness in Flutter"
```

---

## Task 9: Runtime Documentation And Dual APK CI

**Files:**
- Modify: `.env.example`
- Modify: `README.md`
- Modify: `backend/README.md`
- Modify: `.github/workflows/android-native-build.yml`

- [ ] **Step 1: Update environment example**

Add non-secret configuration names and safe defaults:

```text
OPENAI_API_KEY=
DJINN_OPENAI_CHAT_MODEL=gpt-5-mini
DJINN_OPENAI_EMBEDDING_MODEL=text-embedding-3-large
DJINN_RETRIEVAL_MIN_SCORE=0.70
DJINN_RETRIEVAL_LIMIT=3
DJINN_QDRANT_URL=http://127.0.0.1:6333
DJINN_QDRANT_COLLECTION=djinn_chunks
DJINN_POSTGRES_DSN=postgresql://djinn:djinn_dev_password@127.0.0.1:5432/djinn
```

- [ ] **Step 2: Update README trial instructions**

Document exact commands for backend dependencies, Qdrant/PostgreSQL, setting the
OpenAI key, starting FastAPI on `127.0.0.1:8000`, checking
`/system/readiness`, installing the trial APK, and the fact that default CI uses
fakes and never spends OpenAI credits.

- [ ] **Step 3: Add backend CI job**

In `.github/workflows/android-native-build.yml`, add a Python 3.12 backend test
job that installs `backend/requirements.txt` and runs:

```bash
cd backend
PYTHONPATH=. pytest -q
```

- [ ] **Step 4: Build and upload both APKs**

The Android job builds:

```bash
flutter build apk --release
flutter build apk --debug --dart-define=DJINN_BACKEND_URL=http://127.0.0.1:8000
```

Upload separate artifacts:

- `djinn-release-apk`
- `djinn-trial-apk`

- [ ] **Step 5: Validate workflow syntax and commit**

Run:

```bash
git diff --check
```

Commit:

```bash
git add .env.example README.md backend/README.md .github/workflows/android-native-build.yml
git commit -m "ci: build strict RAG trial APK"
```

---

## Task 10: Full Verification, Push, And GitHub Trial Build

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run backend full test suite**

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all tests pass without live OpenAI/Qdrant/PostgreSQL calls.

- [ ] **Step 2: Run Flutter analyzer and full tests**

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter analyze
flutter test
```

Expected: analyzer clean and all tests pass.

- [ ] **Step 3: Build local trial debug APK**

```bash
flutter build apk --debug --dart-define=DJINN_BACKEND_URL=http://127.0.0.1:8000
```

Expected: `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 4: Verify git state and push**

```bash
git status --short --branch
git push origin main
```

Expected: clean `main...origin/main` after push.

- [ ] **Step 5: Watch GitHub build**

```bash
RUN_ID=$(gh -R elizerpist/djinn run list --limit 1 --json databaseId --jq '.[0].databaseId')
gh -R elizerpist/djinn run watch "$RUN_ID" --exit-status
```

Expected: backend tests, Flutter analyze/tests, release APK, trial APK, and both
artifact uploads succeed.

- [ ] **Step 6: Report trial prerequisites honestly**

The completion report must include the GitHub Actions URL and state clearly that
AI answers require the backend to have a valid `OPENAI_API_KEY`, reachable
Qdrant/PostgreSQL, and successful `/system/readiness`; the APK never contains the
key.

---

## Self-Review

- Spec coverage: Tasks 1-7 cover strict runtime, OpenAI, Qdrant, PostgreSQL,
  NeMo Guardrails, LangGraph, verification, and fail-closed API behavior. Task 8
  covers mobile readiness and connectivity. Task 9 covers trial/release build
  artifacts and runtime documentation. Task 10 covers full local and GitHub
  verification.
- Type consistency: `AnswerDraft`, `GroundednessVerdict`, `VectorSearchMatch`,
  `DocumentIndexAudit`, `GuardrailResult`, `SystemReadinessResponse`, and
  `DjinnRuntime` are introduced before use.
- Safety boundary: no task adds tools, web search, client-side API keys, live
  provider calls in CI, or production lexical fallback.
- Scope boundary: OCR, flowchart interpretation, clinical validation, backend
  authentication, and production deployment remain separate milestones.
