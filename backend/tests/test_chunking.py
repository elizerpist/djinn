from app.services.chunking import chunk_pages


def test_chunk_pages_preserves_document_page_and_excerpt():
    chunks = chunk_pages(
        document_id='backend-doc-1',
        filename='omsz.pdf',
        source_path='corpus/omsz/backend-doc-1-omsz.pdf',
        pages=[(1, 'Mellkasi fajdalom es ellatasi algoritmus. ABCDE vizsgalat.')],
    )

    assert len(chunks) == 1
    assert chunks[0].id == 'backend-doc-1-1-0'
    assert chunks[0].document_id == 'backend-doc-1'
    assert chunks[0].title == 'omsz.pdf'
    assert chunks[0].page == 1
    assert 'ABCDE' in chunks[0].text
    assert chunks[0].metadata['extraction_method'] == 'pymupdf'
