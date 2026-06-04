from __future__ import annotations

from pathlib import Path

from app.schemas import SourceChunk
from app.services.guardrail_contracts import GuardrailResult


class NemoGuardrailsAdapter:
    def __init__(self, rails) -> None:
        self._rails = rails

    @classmethod
    def from_settings(
        cls,
        settings,
        *,
        chat_openai,
        config_path: Path | None = None,
    ) -> NemoGuardrailsAdapter:
        from nemoguardrails import LLMRails, RailsConfig

        path = config_path or Path(__file__).parents[2] / 'guardrails'
        config = RailsConfig.from_path(str(path))
        return cls(LLMRails(config, llm=chat_openai))

    def ready(self) -> bool:
        return self._rails is not None

    def check_input(self, message: str) -> GuardrailResult:
        from nemoguardrails.rails.llm.options import RailType

        return self._check(
            [{'role': 'user', 'content': message}],
            rail_types=[RailType.INPUT],
            blocked_reason='input_blocked',
        )

    def check_retrieval(
        self,
        message: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult:
        from nemoguardrails.rails.llm.options import RailType

        return self._check(
            [
                self._context_message(chunks),
                {
                    'role': 'user',
                    'content': f'Retrieved evidence validation for: {message}',
                },
            ],
            rail_types=[RailType.INPUT],
            blocked_reason='retrieval_guard_blocked',
        )

    def check_output(
        self,
        message: str,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult:
        from nemoguardrails.rails.llm.options import RailType

        return self._check(
            [
                self._context_message(chunks, check_facts=True),
                {'role': 'user', 'content': message},
                {'role': 'assistant', 'content': answer},
            ],
            rail_types=[RailType.OUTPUT],
            blocked_reason='output_guard_blocked',
        )

    def _check(
        self,
        messages: list[dict],
        *,
        rail_types: list,
        blocked_reason: str,
    ) -> GuardrailResult:
        try:
            result = self._rails.check(messages, rail_types=rail_types)
            status = getattr(result, 'status', None)
            status_value = getattr(status, 'value', status)
            if status_value != 'passed':
                return GuardrailResult(allowed=False, reason=blocked_reason)
        except Exception:
            return GuardrailResult(allowed=False, reason=blocked_reason)
        return GuardrailResult(allowed=True)

    @staticmethod
    def _context_message(
        chunks: list[SourceChunk],
        *,
        check_facts: bool = False,
    ) -> dict:
        content: dict[str, object] = {
            'relevant_chunks': [chunk.text for chunk in chunks],
        }
        if check_facts:
            content['check_facts'] = True
        return {'role': 'context', 'content': content}
