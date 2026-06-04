from fastapi.testclient import TestClient

from app.infra.metadata_store import LocalMetadataStore
from app.infra.settings import BackendSettings
from app.infra.vector_index import LocalVectorIndex
from app.main import create_app
from app.runtime import build_runtime
from app.schemas import AnswerDraft, GroundednessVerdict
from app.services.guardrail_contracts import GuardrailResult


def test_unconfigured_runtime_is_not_ready_and_hides_secrets(tmp_path):
    runtime = build_runtime(BackendSettings.from_env({}), storage_dir=tmp_path)

    readiness = runtime.readiness.status()

    assert readiness.ready is False
    assert readiness.strict_mode is True
    assert 'secret' not in readiness.model_dump_json()
    assert readiness.components['openai'].ready is False


def test_system_readiness_endpoint_uses_injected_runtime(tmp_path):
    runtime = build_runtime(
        BackendSettings.from_env(
            {
                'OPENAI_API_KEY': 'test-secret',
                'DJINN_USE_QDRANT': 'true',
                'DJINN_USE_POSTGRES': 'true',
            }
        ),
        provider=FakeProvider(),
        vector_index=LocalVectorIndex(),
        metadata_store=LocalMetadataStore(),
        guardrails=AllowGuardrails(),
        storage_dir=tmp_path,
    )
    client = TestClient(create_app(runtime))

    body = client.get('/system/readiness').json()

    assert body['ready'] is True
    assert body['components']['openai']['ready'] is True
    assert 'test-secret' not in str(body)


def test_unconfigured_runtime_refuses_chat_and_ingest(tmp_path):
    import fitz

    runtime = build_runtime(BackendSettings.from_env({}), storage_dir=tmp_path)
    client = TestClient(create_app(runtime))

    chat = client.post('/chat', json={'message': 'Mi a teendo?'}).json()
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), 'ABCDE')
    pdf_bytes = document.tobytes()
    document.close()
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', pdf_bytes, 'application/pdf')},
    ).json()
    ingest = client.post(f"/knowledge/documents/{upload['id']}/ingest").json()

    assert chat['refusal_reason'] == 'ai_backend_not_configured'
    assert chat['citations'] == []
    assert ingest['status'] == 'failed'
    assert ingest['error_message'] == 'not configured'


class FakeProvider:
    def generate(self, question, chunks):
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
