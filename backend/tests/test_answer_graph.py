from app.schemas import (
    AnswerDraft,
    GroundednessVerdict,
    KnowledgeStatusResponse,
    SourceChunk,
    VectorSearchMatch,
)
from app.services.answer_graph import AnswerGraph
from app.services.answer_verifier import AnswerVerifier
from app.services.guardrail_contracts import GuardrailResult


def test_not_ready_preflight_refuses_before_provider_call():
    graph, provider, vector, _ = _graph()

    response = graph.answer(
        conversation_id='conversation-1',
        message='Mi a teendo?',
        knowledge=_knowledge(),
        runtime_ready=False,
    )

    assert response.refusal_reason == 'ai_backend_not_configured'
    assert response.citations == []
    assert provider.generate_calls == 0
    assert vector.search_calls == 0


def test_input_block_refuses_before_retrieval():
    graph, provider, vector, _ = _graph(input_allowed=False)

    response = _answer(graph)

    assert response.refusal_reason == 'input_blocked'
    assert vector.search_calls == 0
    assert provider.generate_calls == 0


def test_weak_retrieval_refuses_before_generation():
    graph, provider, _, _ = _graph(matches=[])

    response = _answer(graph)

    assert response.refusal_reason == 'insufficient_retrieval_evidence'
    assert provider.generate_calls == 0


def test_retrieval_guard_block_refuses_before_generation():
    graph, provider, _, _ = _graph(retrieval_allowed=False)

    response = _answer(graph)

    assert response.refusal_reason == 'retrieval_guard_blocked'
    assert provider.generate_calls == 0


def test_model_abstention_refuses():
    graph, _, _, _ = _graph(
        draft=AnswerDraft(
            answer='',
            cited_chunk_ids=[],
            abstain=True,
            refusal_reason='not enough evidence',
        )
    )

    response = _answer(graph)

    assert response.refusal_reason == 'model_refused'
    assert response.citations == []


def test_unknown_model_citation_refuses():
    graph, _, _, _ = _graph(
        draft=AnswerDraft(
            answer='ABCDE',
            cited_chunk_ids=['outside'],
            abstain=False,
        )
    )

    response = _answer(graph)

    assert response.refusal_reason == 'citation_verification_failed'
    assert response.citations == []


def test_unsupported_groundedness_refuses_before_output_guard():
    graph, _, _, guardrails = _graph(supported=False)

    response = _answer(graph)

    assert response.refusal_reason == 'groundedness_verification_failed'
    assert guardrails.output_calls == 0


def test_output_guard_block_refuses_after_verification():
    graph, _, _, _ = _graph(output_allowed=False)

    response = _answer(graph)

    assert response.refusal_reason == 'output_guard_blocked'
    assert response.citations == []


def test_successful_graph_returns_grounded_server_resolved_citation():
    graph, provider, vector, guardrails = _graph()

    response = _answer(graph)

    assert response.status == 'grounded'
    assert response.answer == 'ABCDE vizsgalat szukseges.'
    assert response.citations[0].document_id == 'doc-1'
    assert response.citations[0].page == 1
    assert response.refusal_reason is None
    assert provider.generate_calls == 1
    assert provider.verify_calls == 1
    assert vector.search_calls == 1
    assert guardrails.output_calls == 1


def _answer(graph: AnswerGraph):
    return graph.answer(
        conversation_id='conversation-1',
        message='Mi a teendo?',
        knowledge=_knowledge(),
        runtime_ready=True,
    )


def _graph(
    *,
    matches: list[VectorSearchMatch] | None = None,
    draft: AnswerDraft | None = None,
    input_allowed: bool = True,
    retrieval_allowed: bool = True,
    output_allowed: bool = True,
    supported: bool = True,
):
    chunk = _chunk('chunk-1')
    provider = FakeProvider(
        supported=supported,
        draft=draft
        or AnswerDraft(
            answer='ABCDE vizsgalat szukseges.',
            cited_chunk_ids=['chunk-1'],
            abstain=False,
        )
    )
    vector = FakeVectorIndex(
        matches if matches is not None else [VectorSearchMatch(chunk=chunk, score=0.9)]
    )
    guardrails = FakeGuardrails(
        input_allowed=input_allowed,
        retrieval_allowed=retrieval_allowed,
        output_allowed=output_allowed,
    )
    verifier = AnswerVerifier(provider=provider)
    graph = AnswerGraph(
        provider=provider,
        vector_index=vector,
        guardrails=guardrails,
        verifier=verifier,
        retrieval_limit=3,
        minimum_score=0.7,
        max_context_chars=12000,
    )
    return graph, provider, vector, guardrails


class FakeProvider:
    def __init__(self, *, draft: AnswerDraft, supported: bool) -> None:
        self._draft = draft
        self._supported = supported
        self.generate_calls = 0
        self.verify_calls = 0

    def generate(self, question: str, chunks: list[SourceChunk]) -> AnswerDraft:
        self.generate_calls += 1
        return self._draft

    def verify_groundedness(self, answer: str, chunks: list[SourceChunk]):
        self.verify_calls += 1
        return GroundednessVerdict(
            supported=self._supported,
            unsupported_claims=[] if self._supported else ['unsupported'],
        )


class FakeVectorIndex:
    def __init__(self, matches: list[VectorSearchMatch]) -> None:
        self._matches = matches
        self.search_calls = 0

    def search(self, query: str, *, limit: int, minimum_score: float):
        self.search_calls += 1
        return self._matches


class FakeGuardrails:
    def __init__(
        self,
        *,
        input_allowed: bool,
        retrieval_allowed: bool,
        output_allowed: bool,
    ) -> None:
        self._input_allowed = input_allowed
        self._retrieval_allowed = retrieval_allowed
        self._output_allowed = output_allowed
        self.output_calls = 0

    def ready(self) -> bool:
        return True

    def check_input(self, message: str) -> GuardrailResult:
        return GuardrailResult(self._input_allowed, None if self._input_allowed else 'input_blocked')

    def check_retrieval(self, message: str, chunks: list[SourceChunk]) -> GuardrailResult:
        return GuardrailResult(
            self._retrieval_allowed,
            None if self._retrieval_allowed else 'retrieval_guard_blocked',
        )

    def check_output(
        self,
        message: str,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult:
        self.output_calls += 1
        return GuardrailResult(
            self._output_allowed,
            None if self._output_allowed else 'output_guard_blocked',
        )


def _knowledge() -> KnowledgeStatusResponse:
    return KnowledgeStatusResponse(
        ready=True,
        document_count=1,
        pending_count=0,
        processed_count=1,
        failed_count=0,
    )


def _chunk(chunk_id: str) -> SourceChunk:
    return SourceChunk(
        id=chunk_id,
        document_id='doc-1',
        title='protocol.pdf',
        page=1,
        text='ABCDE vizsgalat szukseges.',
        metadata={
            'source_path': 'corpus/omsz/protocol.pdf',
            'extraction_method': 'pymupdf',
        },
    )
