from typing import Protocol

from app.schemas import SourceChunk


class VectorIndex(Protocol):
    def upsert_chunks(self, chunks: list[SourceChunk]) -> None: ...
    def search(self, query: str, *, limit: int = 3) -> list[str]: ...


class LocalVectorIndex:
    def __init__(self) -> None:
        self._chunks: list[SourceChunk] = []

    def upsert_chunks(self, chunks: list[SourceChunk]) -> None:
        self._chunks.extend(chunks)

    def search(self, query: str, *, limit: int = 3) -> list[str]:
        terms = {term for term in query.lower().split() if len(term) >= 3}
        scored = []
        for chunk in self._chunks:
            score = sum(1 for term in terms if term in chunk.text.lower())
            if score:
                scored.append((score, chunk.id))
        scored.sort(reverse=True)
        return [chunk_id for _, chunk_id in scored[:limit]]


class QdrantVectorIndex:
    def __init__(self, *, url: str, collection: str) -> None:
        from qdrant_client import QdrantClient

        self._client = QdrantClient(url=url)
        self._collection = collection

    def upsert_chunks(self, chunks: list[SourceChunk]) -> None:
        # Real embedding vectors are introduced after model-provider selection.
        return None

    def search(self, query: str, *, limit: int = 3) -> list[str]:
        return []
