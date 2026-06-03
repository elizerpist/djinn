import fitz
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    response = client.get('/health')

    assert response.status_code == 200
    assert response.json()['status'] == 'ok'
    assert response.json()['service'] == 'djinn-backend'


def test_chat_without_corpus_refuses_with_contract_shape():
    response = client.post(
        '/chat',
        json={
            'message': 'Mi az ellatasi algoritmus?',
            'conversation_id': None,
        },
    )

    body = response.json()
    assert response.status_code == 200
    assert body['status'] == 'insufficient_evidence'
    assert body['citations'] == []
    assert body['refusal_reason'] is not None
    assert body['answer']
    assert body['conversation_id']


def test_chat_with_pending_documents_mentions_ingest_pending():
    client.post(
        '/knowledge/documents',
        files={'file': ('pending-chat.pdf', b'%PDF-1.4\n%%EOF', 'application/pdf')},
    )

    response = client.post(
        '/chat',
        json={
            'message': 'Hasznald a feltoltott PDF-et.',
            'conversation_id': None,
        },
    )

    body = response.json()
    assert response.status_code == 200
    assert body['status'] == 'insufficient_evidence'
    assert 'ingest' in body['answer'].lower()
    assert body['refusal_reason'] == 'knowledge_base_ingest_pending'


def test_chat_refuses_when_documents_processed_but_retrieval_is_not_available():
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', _pdf_bytes('Ellatasi algoritmus'), 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{upload['id']}/ingest")

    response = client.post('/chat', json={'message': 'Mi az ellatasi algoritmus?'})

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'insufficient_evidence'
    assert body['refusal_reason'] == 'retrieval_not_available'
    assert body['citations'] == []


def _pdf_bytes(text: str) -> bytes:
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), text)
    data = document.tobytes()
    document.close()
    return data
