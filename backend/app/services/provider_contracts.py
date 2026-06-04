from typing import Protocol

from app.schemas import AnswerDraft, GroundednessVerdict, SourceChunk


class AnswerProvider(Protocol):
    def generate(self, question: str, chunks: list[SourceChunk]) -> AnswerDraft: ...

    def verify_groundedness(
        self,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GroundednessVerdict: ...
