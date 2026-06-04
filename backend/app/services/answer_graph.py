from __future__ import annotations

from typing import TypedDict

from langgraph.graph import END, START, StateGraph

from app.infra.vector_index import VectorIndex
from app.schemas import (
    AnswerDraft,
    ChatResponse,
    Citation,
    GroundingStatus,
    KnowledgeStatusResponse,
    SourceChunk,
    VectorSearchMatch,
)
from app.services.answer_verifier import AnswerVerifier
from app.services.guardrail_contracts import GuardrailService
from app.services.provider_contracts import AnswerProvider


class AnswerGraphState(TypedDict, total=False):
    conversation_id: str
    message: str
    knowledge: KnowledgeStatusResponse
    runtime_ready: bool
    refusal_reason: str
    matches: list[VectorSearchMatch]
    chunks: list[SourceChunk]
    draft: AnswerDraft
    citations: list[Citation]
    response: ChatResponse


class AnswerGraph:
    def __init__(
        self,
        *,
        provider: AnswerProvider,
        vector_index: VectorIndex,
        guardrails: GuardrailService,
        verifier: AnswerVerifier,
        retrieval_limit: int,
        minimum_score: float,
        max_context_chars: int,
    ) -> None:
        self._provider = provider
        self._vector_index = vector_index
        self._guardrails = guardrails
        self._verifier = verifier
        self._retrieval_limit = retrieval_limit
        self._minimum_score = minimum_score
        self._max_context_chars = max_context_chars
        self._compiled = self._build_graph()

    def answer(
        self,
        *,
        conversation_id: str,
        message: str,
        knowledge: KnowledgeStatusResponse,
        runtime_ready: bool,
    ) -> ChatResponse:
        state = self._compiled.invoke(
            {
                'conversation_id': conversation_id,
                'message': message,
                'knowledge': knowledge,
                'runtime_ready': runtime_ready,
            }
        )
        return state['response']

    def _build_graph(self):
        graph = StateGraph(AnswerGraphState)
        graph.add_node('preflight', self._preflight)
        graph.add_node('input_guard', self._input_guard)
        graph.add_node('retrieve', self._retrieve)
        graph.add_node('retrieval_guard', self._retrieval_guard)
        graph.add_node('generate', self._generate)
        graph.add_node('verify', self._verify)
        graph.add_node('output_guard', self._output_guard)
        graph.add_node('finalize', self._finalize)
        graph.add_edge(START, 'preflight')
        self._add_checked_edge(graph, 'preflight', 'input_guard')
        self._add_checked_edge(graph, 'input_guard', 'retrieve')
        self._add_checked_edge(graph, 'retrieve', 'retrieval_guard')
        self._add_checked_edge(graph, 'retrieval_guard', 'generate')
        self._add_checked_edge(graph, 'generate', 'verify')
        self._add_checked_edge(graph, 'verify', 'output_guard')
        self._add_checked_edge(graph, 'output_guard', 'finalize')
        graph.add_edge('finalize', END)
        return graph.compile()

    @staticmethod
    def _add_checked_edge(graph: StateGraph, source: str, destination: str) -> None:
        graph.add_conditional_edges(
            source,
            AnswerGraph._route,
            {'continue': destination, 'finalize': 'finalize'},
        )

    @staticmethod
    def _route(state: AnswerGraphState) -> str:
        return 'finalize' if state.get('refusal_reason') else 'continue'

    def _preflight(self, state: AnswerGraphState) -> dict:
        if not state['runtime_ready']:
            return {'refusal_reason': 'ai_backend_not_configured'}
        knowledge = state['knowledge']
        if knowledge.pending_count > 0 and knowledge.processed_count == 0:
            return {'refusal_reason': 'knowledge_base_ingest_pending'}
        if knowledge.processed_count == 0:
            return {'refusal_reason': 'insufficient_retrieval_evidence'}
        return {}

    def _input_guard(self, state: AnswerGraphState) -> dict:
        try:
            result = self._guardrails.check_input(state['message'])
        except Exception:
            return {'refusal_reason': 'input_blocked'}
        if not result.allowed:
            return {'refusal_reason': result.reason or 'input_blocked'}
        return {}

    def _retrieve(self, state: AnswerGraphState) -> dict:
        try:
            matches = self._vector_index.search(
                state['message'],
                limit=self._retrieval_limit,
                minimum_score=self._minimum_score,
            )
        except Exception:
            return {'refusal_reason': 'vector_store_unavailable'}

        chunks: list[SourceChunk] = []
        context_chars = 0
        for match in matches[: self._retrieval_limit]:
            if match.score < self._minimum_score or not self._trusted_chunk(match.chunk):
                continue
            next_size = context_chars + len(match.chunk.text)
            if next_size > self._max_context_chars:
                continue
            chunks.append(match.chunk)
            context_chars = next_size
        if not chunks:
            return {'refusal_reason': 'insufficient_retrieval_evidence'}
        return {'matches': matches, 'chunks': chunks}

    @staticmethod
    def _trusted_chunk(chunk: SourceChunk) -> bool:
        return bool(
            chunk.text.strip()
            and chunk.metadata.get('source_path')
            and chunk.metadata.get('extraction_method') == 'pymupdf'
        )

    def _retrieval_guard(self, state: AnswerGraphState) -> dict:
        try:
            result = self._guardrails.check_retrieval(
                state['message'],
                state['chunks'],
            )
        except Exception:
            return {'refusal_reason': 'retrieval_guard_blocked'}
        if not result.allowed:
            return {'refusal_reason': result.reason or 'retrieval_guard_blocked'}
        return {}

    def _generate(self, state: AnswerGraphState) -> dict:
        try:
            draft = self._provider.generate(state['message'], state['chunks'])
        except Exception:
            return {'refusal_reason': 'answer_pipeline_failed'}
        return {'draft': draft}

    def _verify(self, state: AnswerGraphState) -> dict:
        try:
            result = self._verifier.verify(state['draft'], state['chunks'])
        except Exception:
            return {'refusal_reason': 'answer_pipeline_failed'}
        if not result.allowed:
            return {'refusal_reason': result.reason or 'answer_pipeline_failed'}
        return {'citations': result.citations}

    def _output_guard(self, state: AnswerGraphState) -> dict:
        try:
            result = self._guardrails.check_output(
                state['message'],
                state['draft'].answer,
                state['chunks'],
            )
        except Exception:
            return {'refusal_reason': 'output_guard_blocked'}
        if not result.allowed:
            return {'refusal_reason': result.reason or 'output_guard_blocked'}
        return {}

    @staticmethod
    def _finalize(state: AnswerGraphState) -> dict:
        refusal_reason = state.get('refusal_reason')
        if refusal_reason:
            return {
                'response': ChatResponse(
                    conversation_id=state['conversation_id'],
                    answer=_refusal_answer(refusal_reason),
                    status=(
                        GroundingStatus.unsafe_request
                        if refusal_reason == 'input_blocked'
                        else GroundingStatus.insufficient_evidence
                    ),
                    citations=[],
                    refusal_reason=refusal_reason,
                )
            }
        return {
            'response': ChatResponse(
                conversation_id=state['conversation_id'],
                answer=state['draft'].answer,
                status=GroundingStatus.grounded,
                citations=state['citations'],
                refusal_reason=None,
            )
        }


def _refusal_answer(reason: str) -> str:
    answers = {
        'ai_backend_not_configured': 'Az AI backend nincs beallitva vagy nem erheto el.',
        'knowledge_base_ingest_pending': 'A tudasbazis feldolgozasa meg folyamatban van.',
        'input_blocked': 'A kerest a biztonsagi szabalyok blokkoltak.',
        'vector_store_unavailable': 'A tudasbazis keresoje nem erheto el.',
        'insufficient_retrieval_evidence': 'A tudasbazisban nincs elegendo forras a valaszhoz.',
        'retrieval_guard_blocked': 'A visszakeresett forrasokat a biztonsagi ellenorzes blokkolta.',
        'model_refused': 'A modell nem tudott forrashoz kotott valaszt adni.',
        'citation_verification_failed': 'A valasz hivatkozasai nem voltak ellenorizhetok.',
        'groundedness_verification_failed': 'A valasz allitasai nem voltak teljesen alatamaszthatok.',
        'output_guard_blocked': 'A valaszt a biztonsagi ellenorzes blokkolta.',
        'answer_pipeline_failed': 'A valaszfolyamat hibaval leallt.',
    }
    return answers.get(reason, 'A rendszer nem tudott megbizhato valaszt adni.')
