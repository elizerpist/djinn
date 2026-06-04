from typing import Any

from langchain_openai import ChatOpenAI

from app.infra.settings import BackendSettings
from app.schemas import AnswerDraft, GroundednessVerdict, SourceChunk


class OpenAIAnswerProvider:
    def __init__(
        self,
        *,
        draft_model: Any,
        verifier_model: Any,
        max_context_chars: int = 12000,
    ) -> None:
        self._draft_model = draft_model
        self._verifier_model = verifier_model
        self._max_context_chars = max_context_chars

    @classmethod
    def from_settings(cls, settings: BackendSettings) -> 'OpenAIAnswerProvider':
        if not settings.openai_api_key:
            raise ValueError('OPENAI_API_KEY is not configured')
        llm = ChatOpenAI(
            model=settings.openai_chat_model,
            api_key=settings.openai_api_key,
            use_responses_api=True,
        )
        return cls(
            draft_model=llm.with_structured_output(
                AnswerDraft,
                method='json_schema',
            ),
            verifier_model=llm.with_structured_output(
                GroundednessVerdict,
                method='json_schema',
            ),
            max_context_chars=settings.max_context_chars,
        )

    def generate(self, question: str, chunks: list[SourceChunk]) -> AnswerDraft:
        prompt = (
            'Kizarolag az alabbi, alkalmazasbol kapott forrasreszletek alapjan '
            'valaszolj. Ne hasznalj kulso tudast, internetet vagy eszkozt. '
            'Ha a forrasok nem elegendoek, allitsd az abstain mezot igazra. '
            'Csak a megadott chunk azonositokat idezd.\n\n'
            f'KERDES:\n{question}\n\nFORRASOK:\n{self._evidence(chunks)}'
        )
        return self._draft_model.invoke(prompt)

    def verify_groundedness(
        self,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GroundednessVerdict:
        prompt = (
            'Ellenorizd szigoruan, hogy a VALASZ minden allitasa kozvetlenul '
            'alatamaszthato-e a FORRASOK szovegevel. Bizonytalansag eseten a '
            'supported mezot allitsd hamisra.\n\n'
            f'VALASZ:\n{answer}\n\nFORRASOK:\n{self._evidence(chunks)}'
        )
        return self._verifier_model.invoke(prompt)

    def _evidence(self, chunks: list[SourceChunk]) -> str:
        blocks = [
            f'[{chunk.id}] {chunk.text}'
            for chunk in chunks
        ]
        return '\n\n'.join(blocks)[: self._max_context_chars]
