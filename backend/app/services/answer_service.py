from app.schemas import ChatResponse, GroundingStatus, KnowledgeStatusResponse
from app.services.retrieval import RetrievalService
from app.services.safety import answer_without_corpus


class AnswerService:
    def __init__(self, *, retrieval: RetrievalService) -> None:
        self._retrieval = retrieval

    def answer(
        self,
        *,
        conversation_id: str,
        message: str,
        knowledge: KnowledgeStatusResponse,
    ) -> ChatResponse:
        if knowledge.pending_count > 0 and knowledge.processed_count == 0:
            return answer_without_corpus(conversation_id, ingest_pending=True)
        if knowledge.processed_count == 0:
            return answer_without_corpus(conversation_id)
        result = self._retrieval.retrieve(message)
        if not result.chunks:
            return ChatResponse(
                conversation_id=conversation_id,
                answer='A feldolgozott tudasbazisban nincs elegendo idezett forras ehhez a valaszhoz.',
                status=GroundingStatus.insufficient_evidence,
                citations=[],
                refusal_reason='insufficient_retrieval_evidence',
            )
        top_chunk = result.chunks[0]
        return ChatResponse(
            conversation_id=conversation_id,
            answer=top_chunk.text,
            status=GroundingStatus.grounded,
            citations=result.citations,
            refusal_reason=None,
        )
