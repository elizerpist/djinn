from typing import Protocol

from app.schemas import ChatResponse, KnowledgeStatusResponse, SystemReadinessResponse
from app.services.answer_graph import AnswerGraph


class ReadinessProvider(Protocol):
    def status(self) -> SystemReadinessResponse: ...


class AnswerService:
    def __init__(
        self,
        *,
        graph: AnswerGraph,
        readiness: ReadinessProvider,
    ) -> None:
        self._graph = graph
        self._readiness = readiness

    def answer(
        self,
        *,
        conversation_id: str,
        message: str,
        knowledge: KnowledgeStatusResponse,
    ) -> ChatResponse:
        return self._graph.answer(
            conversation_id=conversation_id,
            message=message,
            knowledge=knowledge,
            runtime_ready=self._readiness.status().ready,
        )
