from app.infra.metadata_store import LocalMetadataStore
from app.infra.settings import BackendSettings
from app.infra.vector_index import LocalVectorIndex
from app.schemas import SourceChunk


def test_settings_default_to_local_retrieval():
    settings = BackendSettings.from_env({})

    assert settings.use_qdrant is False
    assert settings.use_postgres is False
    assert settings.qdrant_url == 'http://localhost:6333'
    assert settings.postgres_dsn == 'postgresql://djinn:djinn_dev_password@localhost:5432/djinn'


def test_local_vector_index_returns_upserted_chunk_ids():
    index = LocalVectorIndex()
    chunk = SourceChunk(
        id='chunk-1',
        document_id='backend-doc-1',
        title='omsz.pdf',
        page=1,
        text='Mellkasi fajdalom ABCDE',
        metadata={},
    )

    index.upsert_chunks([chunk])
    results = index.search('mellkasi fajdalom')

    assert results == ['chunk-1']


def test_local_metadata_store_records_chunks_by_document():
    store = LocalMetadataStore()
    chunk = SourceChunk(
        id='chunk-1',
        document_id='backend-doc-1',
        title='omsz.pdf',
        page=1,
        text='ABCDE',
        metadata={},
    )

    store.replace_document_chunks('backend-doc-1', [chunk])

    assert store.list_document_chunks('backend-doc-1') == [chunk]
