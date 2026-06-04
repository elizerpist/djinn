from __future__ import annotations

from datetime import UTC, datetime
from typing import Protocol

from app.schemas import DocumentIndexAudit, SourceChunk


class MetadataStore(Protocol):
    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
        *,
        embedding_model: str,
    ) -> None: ...

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]: ...
    def document_audit(self, document_id: str) -> DocumentIndexAudit | None: ...
    def ping(self) -> bool: ...


class LocalMetadataStore:
    def __init__(self) -> None:
        self._chunks_by_document: dict[str, list[SourceChunk]] = {}
        self._audits_by_document: dict[str, DocumentIndexAudit] = {}

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
        *,
        embedding_model: str,
    ) -> None:
        self._chunks_by_document[document_id] = list(chunks)
        self._audits_by_document[document_id] = DocumentIndexAudit(
            document_id=document_id,
            embedding_model=embedding_model,
            indexed_at=datetime.now(UTC),
            chunk_count=len(chunks),
        )

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return list(self._chunks_by_document.get(document_id, []))

    def document_audit(self, document_id: str) -> DocumentIndexAudit | None:
        return self._audits_by_document.get(document_id)

    def ping(self) -> bool:
        return True


class PostgresMetadataStore:
    def __init__(self, *, dsn: str) -> None:
        import psycopg

        self._dsn = dsn
        self._psycopg = psycopg
        self._ensure_schema()

    def _ensure_schema(self) -> None:
        with self._psycopg.connect(self._dsn) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    '''CREATE TABLE IF NOT EXISTS djinn_chunks (
                        id TEXT PRIMARY KEY,
                        document_id TEXT NOT NULL,
                        title TEXT NOT NULL,
                        page INTEGER,
                        text TEXT NOT NULL,
                        metadata JSONB NOT NULL
                    )'''
                )
                cursor.execute(
                    '''CREATE INDEX IF NOT EXISTS djinn_chunks_document_id_idx
                       ON djinn_chunks (document_id)'''
                )
                cursor.execute(
                    '''CREATE TABLE IF NOT EXISTS djinn_document_index_audit (
                        document_id TEXT PRIMARY KEY,
                        embedding_model TEXT NOT NULL,
                        indexed_at TIMESTAMPTZ NOT NULL,
                        chunk_count INTEGER NOT NULL
                    )'''
                )

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
        *,
        embedding_model: str,
    ) -> None:
        from psycopg.types.json import Jsonb

        indexed_at = datetime.now(UTC)
        with self._psycopg.connect(self._dsn) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    'DELETE FROM djinn_chunks WHERE document_id = %s',
                    (document_id,),
                )
                if chunks:
                    cursor.executemany(
                        '''INSERT INTO djinn_chunks
                           (id, document_id, title, page, text, metadata)
                           VALUES (%s, %s, %s, %s, %s, %s)''',
                        [
                            (
                                chunk.id,
                                chunk.document_id,
                                chunk.title,
                                chunk.page,
                                chunk.text,
                                Jsonb(chunk.metadata),
                            )
                            for chunk in chunks
                        ],
                    )
                cursor.execute(
                    '''INSERT INTO djinn_document_index_audit
                       (document_id, embedding_model, indexed_at, chunk_count)
                       VALUES (%s, %s, %s, %s)
                       ON CONFLICT (document_id) DO UPDATE SET
                           embedding_model = EXCLUDED.embedding_model,
                           indexed_at = EXCLUDED.indexed_at,
                           chunk_count = EXCLUDED.chunk_count''',
                    (document_id, embedding_model, indexed_at, len(chunks)),
                )

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        with self._psycopg.connect(self._dsn) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    '''SELECT id, document_id, title, page, text, metadata
                       FROM djinn_chunks
                       WHERE document_id = %s
                       ORDER BY id''',
                    (document_id,),
                )
                return [
                    SourceChunk(
                        id=row[0],
                        document_id=row[1],
                        title=row[2],
                        page=row[3],
                        text=row[4],
                        metadata=row[5],
                    )
                    for row in cursor.fetchall()
                ]

    def document_audit(self, document_id: str) -> DocumentIndexAudit | None:
        with self._psycopg.connect(self._dsn) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    '''SELECT document_id, embedding_model, indexed_at, chunk_count
                       FROM djinn_document_index_audit
                       WHERE document_id = %s''',
                    (document_id,),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return DocumentIndexAudit(
            document_id=row[0],
            embedding_model=row[1],
            indexed_at=row[2],
            chunk_count=row[3],
        )

    def ping(self) -> bool:
        try:
            with self._psycopg.connect(self._dsn) as connection:
                with connection.cursor() as cursor:
                    cursor.execute('SELECT 1')
                    return cursor.fetchone() == (1,)
        except Exception:
            return False
