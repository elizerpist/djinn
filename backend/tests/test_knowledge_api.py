from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_upload_rejects_non_pdf_file():
    response = client.post(
        '/knowledge/documents',
        files={'file': ('notes.txt', b'not a pdf', 'text/plain')},
    )

    assert response.status_code == 400
    assert 'PDF' in response.json()['detail']


def test_pdf_upload_registers_pending_document_and_lists_it():
    response = client.post(
        '/knowledge/documents',
        files={'file': ('omsz-protocol.pdf', b'%PDF-1.4\n%%EOF', 'application/pdf')},
    )

    assert response.status_code == 200
    body = response.json()
    assert body['filename'] == 'omsz-protocol.pdf'
    assert body['status'] == 'pending_ingest'
    assert body['size_bytes'] > 0

    list_response = client.get('/knowledge/documents')
    assert list_response.status_code == 200
    assert any(item['id'] == body['id'] for item in list_response.json())


def test_knowledge_status_is_not_ready_while_documents_are_pending():
    client.post(
        '/knowledge/documents',
        files={'file': ('pending.pdf', b'%PDF-1.4\n%%EOF', 'application/pdf')},
    )

    response = client.get('/knowledge/status')

    assert response.status_code == 200
    body = response.json()
    assert body['ready'] is False
    assert body['document_count'] >= 1
    assert body['pending_count'] >= 1
    assert body['processed_count'] == 0


def test_ingest_endpoint_keeps_manual_validation_pending():
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('manual-validation.pdf', b'%PDF-1.4\n%%EOF', 'application/pdf')},
    )
    document_id = upload.json()['id']

    response = client.post(f'/knowledge/documents/{document_id}/ingest')

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'pending_ingest'
    assert 'manual' in (body['error_message'] or '').lower()
