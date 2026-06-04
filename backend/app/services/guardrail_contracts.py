from dataclasses import dataclass
from typing import Protocol

from app.schemas import SourceChunk


@dataclass(frozen=True)
class GuardrailResult:
    allowed: bool
    reason: str | None = None


class GuardrailService(Protocol):
    def ready(self) -> bool: ...
    def check_input(self, message: str) -> GuardrailResult: ...
    def check_retrieval(
        self,
        message: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult: ...
    def check_output(
        self,
        message: str,
        answer: str,
        chunks: list[SourceChunk],
    ) -> GuardrailResult: ...
