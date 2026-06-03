from app.schemas import ChatResponse, GroundingStatus


REFUSAL_TEXT = (
    'A tudasbazisban nincs elegendo hitelesitett forras ehhez a valaszhoz. '
    'Csak az alkalmazas jovahagyott dokumentumaibol tudok valaszolni.'
)


def answer_without_corpus(conversation_id: str) -> ChatResponse:
    return ChatResponse(
        conversation_id=conversation_id,
        answer=REFUSAL_TEXT,
        status=GroundingStatus.insufficient_evidence,
        citations=[],
        refusal_reason='no_validated_corpus_evidence',
    )
