import asyncio
from io import BytesIO

from fastapi import UploadFile

from app.schemas import KnowledgeDocumentStatus, SourceChunk
from app.services.document_registry import DocumentRegistry
from app.services.indexing_service import IndexingError, IndexingService


def test_indexing_service_writes_vector_then_metadata():
    events: list[str] = []
    vector = RecordingVectorIndex(events)
    metadata = RecordingMetadataStore(events)
    service = IndexingService(
        vector_index=vector,
        metadata_store=metadata,
        embedding_model='embedding-model',
    )

    service.replace_document_chunks('doc-1', [_chunk('chunk-1')])

    assert events == ['vector:doc-1', 'metadata:doc-1:embedding-model']


def test_indexing_service_fails_closed_and_clears_vector_on_metadata_error():
    events: list[str] = []
    vector = RecordingVectorIndex(events)
    service = IndexingService(
        vector_index=vector,
        metadata_store=FailingMetadataStore(events),
        embedding_model='embedding-model',
    )

    try:
        service.replace_document_chunks('doc-1', [_chunk('chunk-1')])
    except IndexingError as error:
        assert 'metadata unavailable' in str(error)
    else:
        raise AssertionError('IndexingError was not raised')

    assert events == [
        'vector:doc-1',
        'metadata:doc-1:embedding-model',
        'vector:doc-1',
    ]
    assert vector.last_chunks == []


def test_document_registry_marks_failed_when_vector_index_fails(tmp_path):
    registry = DocumentRegistry(
        storage_dir=tmp_path,
        extractor=FakeExtractor([(1, 'ABCDE')]),
        indexing_service=FailingIndexingService(),
    )
    upload = UploadFile(filename='protocol.pdf', file=BytesIO(b'%PDF'))
    record = asyncio.run(registry.register_upload(upload))

    result = registry.start_ingest(record.id)

    assert result.status == KnowledgeDocumentStatus.failed
    assert result.error_message == 'vector unavailable'


class RecordingVectorIndex:
    def __init__(self, events: list[str]) -> None:
        self._events = events
        self.last_chunks: list[SourceChunk] = []

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None:
        self._events.append(f'vector:{document_id}')
        self.last_chunks = list(chunks)

    def search(self, query: str, *, limit: int = 3, minimum_score: float = 0.0):
        return []

    def ping(self) -> bool:
        return True


class RecordingMetadataStore:
    def __init__(self, events: list[str]) -> None:
        self._events = events

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
        *,
        embedding_model: str,
    ) -> None:
        self._events.append(f'metadata:{document_id}:{embedding_model}')

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return []

    def document_audit(self, document_id: str):
        return None

    def ping(self) -> bool:
        return True


class FailingMetadataStore(RecordingMetadataStore):
    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
        *,
        embedding_model: str,
    ) -> None:
        super().replace_document_chunks(
            document_id,
            chunks,
            embedding_model=embedding_model,
        )
        raise RuntimeError('metadata unavailable')


class FailingIndexingService:
    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None:
        raise IndexingError('vector unavailable')


class FakeExtractor:
    def __init__(self, pages: list[tuple[int, str]]) -> None:
        self._pages = pages

    def extract_pages(self, pdf_path):
        return self._pages


def _chunk(chunk_id: str) -> SourceChunk:
    return SourceChunk(
        id=chunk_id,
        document_id='doc-1',
        title='protocol.pdf',
        page=1,
        text='ABCDE',
        metadata={'source_path': 'corpus/omsz/protocol.pdf'},
    )
