from app.schemas import SourceChunk
from app.services.chunk_repository import ChunkRepository
from app.services.retrieval import RetrievalService


def test_retrieval_returns_matching_chunk_as_citation():
    repository = ChunkRepository()
    repository.replace_document_chunks(
        'backend-doc-1',
        [
            SourceChunk(
                id='chunk-1',
                document_id='backend-doc-1',
                title='omsz.pdf',
                page=3,
                text='Mellkasi fajdalom eseten ABCDE vizsgalat szukseges.',
                metadata={'source_path': 'corpus/omsz/omsz.pdf'},
            )
        ],
    )
    service = RetrievalService(repository=repository, minimum_score=1)

    result = service.retrieve('Mi a teendo mellkasi fajdalom eseten?')

    assert len(result.chunks) == 1
    assert result.citations[0].document_id == 'backend-doc-1'
    assert result.citations[0].page == 3
    assert 'ABCDE' in result.citations[0].excerpt


def test_retrieval_returns_empty_when_score_below_threshold():
    repository = ChunkRepository()
    repository.replace_document_chunks(
        'backend-doc-1',
        [
            SourceChunk(
                id='chunk-1',
                document_id='backend-doc-1',
                title='omsz.pdf',
                page=1,
                text='Lazcsillapitas gyermekeknel.',
                metadata={},
            )
        ],
    )
    service = RetrievalService(repository=repository, minimum_score=2)

    result = service.retrieve('trauma immobilizalas')

    assert result.chunks == []
    assert result.citations == []
