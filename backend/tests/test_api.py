import fitz
def test_health(client):
    response = client.get('/health')

    assert response.status_code == 200
    assert response.json()['status'] == 'ok'
    assert response.json()['service'] == 'djinn-backend'


def test_chat_without_corpus_refuses_with_contract_shape(client):
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


def test_chat_with_pending_documents_mentions_ingest_pending(client):
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
    assert 'feldolgozas' in body['answer'].lower()
    assert body['refusal_reason'] == 'knowledge_base_ingest_pending'


def test_chat_returns_grounded_answer_with_citation_after_ingest(client):
    pdf_bytes = _pdf_bytes('Mellkasi fajdalom eseten ABCDE vizsgalat szukseges.')
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', pdf_bytes, 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{upload['id']}/ingest")

    response = client.post(
        '/chat',
        json={'message': 'Mi a teendo mellkasi fajdalom eseten?'},
    )

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'grounded'
    assert 'ABCDE' in body['answer']
    assert body['citations'][0]['document_id'] == upload['id']
    assert body['citations'][0]['page'] == 1
    assert body['refusal_reason'] is None


def test_chat_refuses_when_processed_chunks_do_not_match_question(client):
    pdf_bytes = _pdf_bytes('Lazcsillapitas gyermekkorban.')
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('fever.pdf', pdf_bytes, 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{upload['id']}/ingest")

    response = client.post('/chat', json={'message': 'Trauma immobilizalas?'})

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'insufficient_evidence'
    assert body['citations'] == []
    assert body['refusal_reason'] == 'insufficient_retrieval_evidence'


def _pdf_bytes(text: str) -> bytes:
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), text)
    data = document.tobytes()
    document.close()
    return data
