import re

from app.schemas import Citation, RetrievalResult, SourceChunk
from app.services.chunk_repository import ChunkRepository


class RetrievalService:
    def __init__(self, *, repository: ChunkRepository, minimum_score: int = 1) -> None:
        self._repository = repository
        self._minimum_score = minimum_score

    def retrieve(self, query: str, *, limit: int = 3) -> RetrievalResult:
        query_terms = _terms(query)
        scored: list[tuple[int, SourceChunk]] = []
        for chunk in self._repository.list_chunks():
            score = len(query_terms.intersection(_terms(chunk.text)))
            if score >= self._minimum_score:
                scored.append((score, chunk))
        scored.sort(key=lambda item: item[0], reverse=True)
        chunks = [chunk for _, chunk in scored[:limit]]
        citations = [
            Citation(
                document_id=chunk.document_id,
                title=chunk.title,
                page=chunk.page,
                section=None,
                excerpt=chunk.text[:500],
            )
            for chunk in chunks
        ]
        return RetrievalResult(chunks=chunks, citations=citations)


def _terms(value: str) -> set[str]:
    return {
        term
        for term in re.findall(r'[0-9A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]+', value.lower())
        if len(term) >= 3
    }
