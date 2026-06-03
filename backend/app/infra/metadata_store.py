from typing import Protocol

from app.schemas import SourceChunk


class MetadataStore(Protocol):
    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None: ...
    def list_document_chunks(self, document_id: str) -> list[SourceChunk]: ...


class LocalMetadataStore:
    def __init__(self) -> None:
        self._chunks_by_document: dict[str, list[SourceChunk]] = {}

    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None:
        self._chunks_by_document[document_id] = list(chunks)

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return list(self._chunks_by_document.get(document_id, []))


class PostgresMetadataStore:
    def __init__(self, *, dsn: str) -> None:
        import psycopg

        self._dsn = dsn
        self._psycopg = psycopg

    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None:
        return None

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return []
