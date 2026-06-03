from app.schemas import ChatResponse, GroundingStatus


REFUSAL_TEXT = (
    'A tudasbazisban nincs elegendo hitelesitett forras ehhez a valaszhoz. '
    'Csak az alkalmazas jovahagyott dokumentumaibol tudok valaszolni.'
)


def answer_without_corpus(
    conversation_id: str,
    ingest_pending: bool = False,
    retrieval_unavailable: bool = False,
) -> ChatResponse:
    if retrieval_unavailable:
        return ChatResponse(
            conversation_id=conversation_id,
            answer='A tudasbazis feldolgozott dokumentumot jelez, de a visszakereso RAG reteg meg nincs bekotve. Klinikai valaszt csak feldolgozott es visszakeresheto forras alapjan adhatok.',
            status=GroundingStatus.insufficient_evidence,
            citations=[],
            refusal_reason='retrieval_not_available',
        )
    if ingest_pending:
        return ChatResponse(
            conversation_id=conversation_id,
            answer='A PDF dokumentumok be vannak toltve, de az ingest es klinikai validacio meg fuggoben van. Addig nem hasznalom oket valaszadasra.',
            status=GroundingStatus.insufficient_evidence,
            citations=[],
            refusal_reason='knowledge_base_ingest_pending',
        )
    return ChatResponse(
        conversation_id=conversation_id,
        answer=REFUSAL_TEXT,
        status=GroundingStatus.insufficient_evidence,
        citations=[],
        refusal_reason='no_validated_corpus_evidence',
    )
