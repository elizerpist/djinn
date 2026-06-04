from dataclasses import dataclass, field

from app.schemas import AnswerDraft, Citation, SourceChunk
from app.services.provider_contracts import AnswerProvider


@dataclass(frozen=True)
class AnswerVerificationResult:
    allowed: bool
    reason: str | None = None
    citations: list[Citation] = field(default_factory=list)


class AnswerVerifier:
    def __init__(self, *, provider: AnswerProvider) -> None:
        self._provider = provider

    def verify(
        self,
        draft: AnswerDraft,
        chunks: list[SourceChunk],
    ) -> AnswerVerificationResult:
        if draft.abstain or not draft.answer.strip():
            return AnswerVerificationResult(allowed=False, reason='model_refused')
        if not draft.cited_chunk_ids:
            return AnswerVerificationResult(
                allowed=False,
                reason='citation_verification_failed',
            )
        if len(draft.cited_chunk_ids) != len(set(draft.cited_chunk_ids)):
            return AnswerVerificationResult(
                allowed=False,
                reason='citation_verification_failed',
            )

        chunks_by_id = {chunk.id: chunk for chunk in chunks}
        if len(chunks_by_id) != len(chunks):
            return AnswerVerificationResult(
                allowed=False,
                reason='citation_verification_failed',
            )
        if any(chunk_id not in chunks_by_id for chunk_id in draft.cited_chunk_ids):
            return AnswerVerificationResult(
                allowed=False,
                reason='citation_verification_failed',
            )

        try:
            verdict = self._provider.verify_groundedness(draft.answer, chunks)
        except Exception:
            return AnswerVerificationResult(
                allowed=False,
                reason='groundedness_verification_failed',
            )
        if not verdict.supported or verdict.unsupported_claims:
            return AnswerVerificationResult(
                allowed=False,
                reason='groundedness_verification_failed',
            )

        citations = [
            self._citation(chunks_by_id[chunk_id])
            for chunk_id in draft.cited_chunk_ids
        ]
        return AnswerVerificationResult(allowed=True, citations=citations)

    @staticmethod
    def _citation(chunk: SourceChunk) -> Citation:
        return Citation(
            document_id=chunk.document_id,
            title=chunk.title,
            page=chunk.page,
            section=chunk.metadata.get('section'),
            excerpt=chunk.text[:500],
        )
