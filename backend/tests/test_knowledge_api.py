import fitz
def test_upload_rejects_non_pdf_file(client):
    response = client.post(
        '/knowledge/documents',
        files={'file': ('notes.txt', b'not a pdf', 'text/plain')},
    )

    assert response.status_code == 400
    assert 'PDF' in response.json()['detail']


def test_pdf_upload_registers_pending_document_and_lists_it(client):
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


def test_knowledge_status_is_not_ready_while_documents_are_pending(client):
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


def test_ingest_extracts_pdf_text_and_marks_processed(client, fake_runtime):
    pdf_bytes = _pdf_bytes('Mellkasi fajdalom ABCDE vizsgalat')
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', pdf_bytes, 'application/pdf')},
    ).json()

    response = client.post(f"/knowledge/documents/{upload['id']}/ingest")

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'processed'
    assert body['error_message'] is None
    assert len(fake_runtime.metadata_store.list_document_chunks(upload['id'])) == 1


def test_ingest_marks_unreadable_pdf_failed(client):
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('broken.pdf', b'%PDF-1.4 broken', 'application/pdf')},
    ).json()

    response = client.post(f"/knowledge/documents/{upload['id']}/ingest")

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'failed'
    assert body['error_message']


def test_knowledge_status_counts_processed_pending_and_failed(client):
    first = client.post(
        '/knowledge/documents',
        files={'file': ('pending.pdf', b'%PDF-1.4 pending', 'application/pdf')},
    ).json()
    second = client.post(
        '/knowledge/documents',
        files={'file': ('processed.pdf', _pdf_bytes('ABCDE'), 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{second['id']}/ingest")

    response = client.get('/knowledge/status')

    assert response.status_code == 200
    body = response.json()
    assert body['ready'] is True
    assert body['document_count'] == 2
    assert body['pending_count'] == 1
    assert body['processed_count'] == 1
    assert body['failed_count'] == 0
    assert first['status'] == 'pending_ingest'


def _pdf_bytes(text: str) -> bytes:
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), text)
    data = document.tobytes()
    document.close()
    return data
