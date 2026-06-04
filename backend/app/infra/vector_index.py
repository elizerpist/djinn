from __future__ import annotations

from typing import Protocol

from app.infra.settings import BackendSettings
from app.schemas import SourceChunk, VectorSearchMatch


class VectorIndex(Protocol):
    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None: ...

    def search(
        self,
        query: str,
        *,
        limit: int = 3,
        minimum_score: float = 0.0,
    ) -> list[VectorSearchMatch]: ...

    def ping(self) -> bool: ...


class LocalVectorIndex:
    def __init__(self) -> None:
        self._chunks_by_document: dict[str, list[SourceChunk]] = {}

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None:
        self._chunks_by_document[document_id] = list(chunks)

    def search(
        self,
        query: str,
        *,
        limit: int = 3,
        minimum_score: float = 0.0,
    ) -> list[VectorSearchMatch]:
        terms = {term for term in query.casefold().split() if len(term) >= 3}
        if not terms:
            return []

        matches: list[VectorSearchMatch] = []
        for chunks in self._chunks_by_document.values():
            for chunk in chunks:
                text = chunk.text.casefold()
                score = sum(1 for term in terms if term in text) / len(terms)
                if score >= minimum_score and score > 0:
                    matches.append(VectorSearchMatch(chunk=chunk, score=score))
        matches.sort(key=lambda match: (-match.score, match.chunk.id))
        return matches[:limit]

    def ping(self) -> bool:
        return True


class QdrantVectorIndex:
    def __init__(self, *, client, vector_store, collection: str) -> None:
        self._client = client
        self._vector_store = vector_store
        self._collection = collection

    @classmethod
    def from_settings(cls, settings: BackendSettings) -> QdrantVectorIndex:
        if not settings.openai_api_key:
            raise ValueError('OPENAI_API_KEY is required for Qdrant embeddings')

        from langchain_openai import OpenAIEmbeddings
        from langchain_qdrant import QdrantVectorStore
        from qdrant_client import QdrantClient, models

        client = QdrantClient(url=settings.qdrant_url)
        if not client.collection_exists(settings.qdrant_collection):
            client.create_collection(
                collection_name=settings.qdrant_collection,
                vectors_config=models.VectorParams(
                    size=settings.openai_embedding_dimensions,
                    distance=models.Distance.COSINE,
                ),
            )
        embeddings = OpenAIEmbeddings(
            model=settings.openai_embedding_model,
            dimensions=settings.openai_embedding_dimensions,
            api_key=settings.openai_api_key,
        )
        vector_store = QdrantVectorStore(
            client=client,
            collection_name=settings.qdrant_collection,
            embedding=embeddings,
        )
        return cls(
            client=client,
            vector_store=vector_store,
            collection=settings.qdrant_collection,
        )

    def replace_document_chunks(
        self,
        document_id: str,
        chunks: list[SourceChunk],
    ) -> None:
        from langchain_core.documents import Document
        from qdrant_client import models

        self._client.delete(
            collection_name=self._collection,
            points_selector=models.Filter(
                must=[
                    models.FieldCondition(
                        key='metadata.document_id',
                        match=models.MatchValue(value=document_id),
                    )
                ]
            ),
            wait=True,
        )
        if not chunks:
            return

        documents = [
            Document(
                page_content=chunk.text,
                metadata={
                    'chunk_id': chunk.id,
                    'document_id': chunk.document_id,
                    'title': chunk.title,
                    'page': chunk.page,
                    'source_metadata': chunk.metadata,
                },
            )
            for chunk in chunks
        ]
        self._vector_store.add_documents(documents)

    def search(
        self,
        query: str,
        *,
        limit: int = 3,
        minimum_score: float = 0.0,
    ) -> list[VectorSearchMatch]:
        raw_matches = self._vector_store.similarity_search_with_score(
            query,
            k=limit,
            score_threshold=minimum_score,
        )
        matches: list[VectorSearchMatch] = []
        for document, score in raw_matches:
            metadata = document.metadata
            try:
                chunk = SourceChunk(
                    id=metadata['chunk_id'],
                    document_id=metadata['document_id'],
                    title=metadata['title'],
                    page=metadata.get('page'),
                    text=document.page_content,
                    metadata=metadata.get('source_metadata', {}),
                )
            except (KeyError, TypeError, ValueError):
                continue
            matches.append(VectorSearchMatch(chunk=chunk, score=float(score)))
        return matches

    def ping(self) -> bool:
        try:
            self._client.get_collection(self._collection)
        except Exception:
            return False
        return True
