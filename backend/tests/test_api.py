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
