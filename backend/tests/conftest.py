import pytest
from fastapi.testclient import TestClient

from app.infra.metadata_store import LocalMetadataStore
from app.infra.settings import BackendSettings
from app.infra.vector_index import LocalVectorIndex
from app.main import create_app
from app.runtime import build_runtime
from app.schemas import AnswerDraft, GroundednessVerdict
from app.services.guardrail_contracts import GuardrailResult


@pytest.fixture
def fake_runtime(tmp_path):
    settings = BackendSettings.from_env(
        {
            'OPENAI_API_KEY': 'test-key',
            'DJINN_USE_QDRANT': 'true',
            'DJINN_USE_POSTGRES': 'true',
            'DJINN_RETRIEVAL_MIN_SCORE': '0.1',
        }
    )
    return build_runtime(
        settings,
        provider=FakeProvider(),
        vector_index=LocalVectorIndex(),
        metadata_store=LocalMetadataStore(),
        guardrails=AllowGuardrails(),
        storage_dir=tmp_path / 'corpus',
    )


@pytest.fixture
def client(fake_runtime):
    return TestClient(create_app(fake_runtime))


class FakeProvider:
    def generate(self, question, chunks):
        if not chunks:
            return AnswerDraft(
                answer='',
                cited_chunk_ids=[],
                abstain=True,
                refusal_reason='no evidence',
            )
        return AnswerDraft(
            answer=chunks[0].text,
            cited_chunk_ids=[chunks[0].id],
            abstain=False,
        )

    def verify_groundedness(self, answer, chunks):
        return GroundednessVerdict(supported=True, unsupported_claims=[])


class AllowGuardrails:
    def ready(self) -> bool:
        return True

    def check_input(self, message):
        return GuardrailResult(allowed=True)

    def check_retrieval(self, message, chunks):
        return GuardrailResult(allowed=True)

    def check_output(self, message, answer, chunks):
        return GuardrailResult(allowed=True)
