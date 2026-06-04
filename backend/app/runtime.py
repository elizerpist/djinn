from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app.infra.metadata_store import MetadataStore, PostgresMetadataStore
from app.infra.openai_provider import OpenAIAnswerProvider
from app.infra.settings import BackendSettings
from app.infra.vector_index import QdrantVectorIndex, VectorIndex
from app.schemas import (
    AnswerDraft,
    ComponentReadiness,
    GroundednessVerdict,
    SourceChunk,
    SystemReadinessResponse,
    VectorSearchMatch,
)
from app.services.answer_graph import AnswerGraph
from app.services.answer_service import AnswerService
from app.services.answer_verifier import AnswerVerifier
from app.services.conversation_store import ConversationStore
from app.services.document_registry import DocumentRegistry
from app.services.guardrail_contracts import GuardrailResult, GuardrailService
from app.services.indexing_service import IndexingService
from app.services.pdf_text_extractor import PdfTextExtractor
from app.services.provider_contracts import AnswerProvider


@dataclass(frozen=True)
class DjinnRuntime:
    settings: BackendSettings
    conversations: ConversationStore
    documents: DocumentRegistry
    answers: AnswerService
    readiness: ReadinessService
    vector_index: VectorIndex
    metadata_store: MetadataStore


class ReadinessService:
    def __init__(
        self,
        *,
        settings: BackendSettings,
        provider_ready: bool,
        provider_detail: str,
        vector_index: VectorIndex,
        metadata_store: MetadataStore,
        guardrails: GuardrailService,
    ) -> None:
        self._settings = settings
        self._provider_ready = provider_ready
        self._provider_detail = provider_detail
        self._vector_index = vector_index
        self._metadata_store = metadata_store
        self._guardrails = guardrails

    def status(self) -> SystemReadinessResponse:
        components = {
            'openai': ComponentReadiness(
                ready=self._provider_ready,
                detail=self._provider_detail,
            ),
            'qdrant': self._component_status(self._vector_index, 'unavailable'),
            'postgres': self._component_status(self._metadata_store, 'unavailable'),
            'guardrails': self._component_status(self._guardrails, 'unavailable'),
        }
        return SystemReadinessResponse(
            ready=all(component.ready for component in components.values()),
            strict_mode=self._settings.strict_mode,
            components=components,
        )

    @staticmethod
    def _component_status(component: Any, fallback_detail: str) -> ComponentReadiness:
        try:
            check = getattr(component, 'ping', None) or getattr(component, 'ready')
            ready = bool(check())
        except Exception:
            ready = False
        detail = 'ready' if ready else getattr(component, 'detail', fallback_detail)
        return ComponentReadiness(ready=ready, detail=detail)


def build_runtime(
    settings: BackendSettings,
    *,
    provider: AnswerProvider | None = None,
    vector_index: VectorIndex | None = None,
    metadata_store: MetadataStore | None = None,
    guardrails: GuardrailService | None = None,
    storage_dir: Path | None = None,
) -> DjinnRuntime:
    provider, provider_ready, provider_detail = _provider(settings, provider)
    vector_index = vector_index or _vector_index(settings)
    metadata_store = metadata_store or _metadata_store(settings)
    guardrails = guardrails or _guardrails(settings)

    readiness = ReadinessService(
        settings=settings,
        provider_ready=provider_ready,
        provider_detail=provider_detail,
        vector_index=vector_index,
        metadata_store=metadata_store,
        guardrails=guardrails,
    )
    indexing = IndexingService(
        vector_index=vector_index,
        metadata_store=metadata_store,
        embedding_model=settings.openai_embedding_model,
    )
    documents = DocumentRegistry(
        indexing_service=indexing,
        storage_dir=storage_dir,
        extractor=PdfTextExtractor(),
    )
    verifier = AnswerVerifier(provider=provider)
    graph = AnswerGraph(
        provider=provider,
        vector_index=vector_index,
        guardrails=guardrails,
        verifier=verifier,
        retrieval_limit=settings.retrieval_limit,
        minimum_score=settings.retrieval_min_score,
        max_context_chars=settings.max_context_chars,
    )
    answers = AnswerService(graph=graph, readiness=readiness)
    return DjinnRuntime(
        settings=settings,
        conversations=ConversationStore(),
        documents=documents,
        answers=answers,
        readiness=readiness,
        vector_index=vector_index,
        metadata_store=metadata_store,
    )


def _provider(
    settings: BackendSettings,
    override: AnswerProvider | None,
) -> tuple[AnswerProvider, bool, str]:
    if override is not None:
        return override, True, 'configured'
    if not settings.openai_configured:
        return DisabledAnswerProvider('not configured'), False, 'not configured'
    try:
        return OpenAIAnswerProvider.from_settings(settings), True, 'configured'
    except Exception:
        return DisabledAnswerProvider('initialization failed'), False, 'initialization failed'


def _vector_index(settings: BackendSettings) -> VectorIndex:
    if not settings.use_qdrant:
        return DisabledVectorIndex('not configured')
    try:
        return QdrantVectorIndex.from_settings(settings)
    except Exception:
        return DisabledVectorIndex('unavailable')


def _metadata_store(settings: BackendSettings) -> MetadataStore:
    if not settings.use_postgres:
        return DisabledMetadataStore('not configured')
    try:
        return PostgresMetadataStore(dsn=settings.postgres_dsn)
    except Exception:
        return DisabledMetadataStore('unavailable')


def _guardrails(settings: BackendSettings) -> GuardrailService:
    if not settings.openai_configured:
        return DisabledGuardrails('not configured')
    try:
        from langchain_openai import ChatOpenAI

        from app.infra.nemo_guardrails import NemoGuardrailsAdapter

        llm = ChatOpenAI(
            model=settings.openai_chat_model,
            api_key=settings.openai_api_key,
            use_responses_api=True,
        )
        return NemoGuardrailsAdapter.from_settings(settings, chat_openai=llm)
    except Exception:
        return DisabledGuardrails('initialization failed')


class DisabledAnswerProvider:
    def __init__(self, detail: str) -> None:
        self.detail = detail

    def generate(self, question: str, chunks: list[SourceChunk]) -> AnswerDraft:
        raise RuntimeError(self.detail)

    def verify_groundedness(
        self,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GroundednessVerdict:
        raise RuntimeError(self.detail)


class DisabledVectorIndex:
    def __init__(self, detail: str) -> None:
        self.detail = detail

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None:
        raise RuntimeError(self.detail)

    def search(
        self,
        query: str,
        *,
        limit: int = 3,
        minimum_score: float = 0.0,
    ) -> list[VectorSearchMatch]:
        raise RuntimeError(self.detail)

    def ping(self) -> bool:
        return False


class DisabledMetadataStore:
    def __init__(self, detail: str) -> None:
        self.detail = detail

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
        *,
        embedding_model: str,
    ) -> None:
        raise RuntimeError(self.detail)

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return []

    def document_audit(self, document_id: str):
        return None

    def ping(self) -> bool:
        return False


class DisabledGuardrails:
    def __init__(self, detail: str) -> None:
        self.detail = detail

    def ready(self) -> bool:
        return False

    def check_input(self, message: str) -> GuardrailResult:
        return GuardrailResult(allowed=False, reason='guardrails_unavailable')

    def check_retrieval(
        self,
        message: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult:
        return GuardrailResult(allowed=False, reason='guardrails_unavailable')

    def check_output(
        self,
        message: str,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult:
        return GuardrailResult(allowed=False, reason='guardrails_unavailable')
