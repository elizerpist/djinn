from app.infra.metadata_store import LocalMetadataStore
from app.infra.vector_index import LocalVectorIndex
from app.schemas import SourceChunk


def test_local_vector_index_replaces_document_and_returns_scored_chunks():
    index = LocalVectorIndex()
    index.replace_document_chunks('doc-1', [_chunk('old', 'old text')])
    index.replace_document_chunks('doc-1', [_chunk('new', 'ABCDE vizsgalat')])

    matches = index.search('ABCDE', limit=3, minimum_score=0.1)

    assert [match.chunk.id for match in matches] == ['new']
    assert matches[0].score >= 0.1


def test_local_metadata_store_records_embedding_audit_fields():
    store = LocalMetadataStore()
    store.replace_document_chunks(
        'doc-1',
        [_chunk('chunk-1', 'ABCDE')],
        embedding_model='text-embedding-3-large',
    )

    assert store.list_document_chunks('doc-1')[0].id == 'chunk-1'
    audit = store.document_audit('doc-1')
    assert audit is not None
    assert audit.embedding_model == 'text-embedding-3-large'
    assert audit.chunk_count == 1


def test_local_adapters_report_ready():
    assert LocalVectorIndex().ping() is True
    assert LocalMetadataStore().ping() is True


def _chunk(chunk_id: str, text: str) -> SourceChunk:
    return SourceChunk(
        id=chunk_id,
        document_id='doc-1',
        title='omsz.pdf',
        page=1,
        text=text,
        metadata={'source_path': 'corpus/omsz/omsz.pdf'},
    )
